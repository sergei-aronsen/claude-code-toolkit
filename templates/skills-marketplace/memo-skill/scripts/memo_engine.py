#!/usr/bin/env python3
"""
memo_engine.py — Semantic search engine for the engineering-brain vault.

Provides: indexing, semantic search, keyword search, dedup detection, stats.

Storage:
  - SQLite with FTS5 for fast keyword search
  - numpy embeddings array for semantic similarity
  - sentence-transformers (intfloat/multilingual-e5-large) for local embeddings

Model: multilingual-e5-large (~1.1GB, 1024 dims, 50+ languages incl. Russian)
  - Requires "query: " prefix for search queries
  - Requires "passage: " prefix for document indexing
  - Significantly better than MiniLM for Russian + English mixed vaults

Usage:
  python memo_engine.py index-file <file> --vault <path>
  python memo_engine.py search <query> --vault <path> [--limit N] [--threshold F]
  python memo_engine.py query <question> --vault <path>     # LLM-synthesized answer
  python memo_engine.py dedup --vault <path> [--threshold F]
  python memo_engine.py lint --vault <path>                 # 7 health checks
  python memo_engine.py list --vault <path> [--limit N]
  python memo_engine.py stats --vault <path>
  python memo_engine.py reindex --vault <path>
  python memo_engine.py obsidian-info --vault <path>   # Obsidian CLI status + graph data
  python memo_engine.py warm-up
"""

import argparse
import fcntl
import json
import os
import re
import sqlite3
import subprocess
import sys
import hashlib
from datetime import datetime
from pathlib import Path
from typing import Optional

import numpy as np

# ─── Model config ───

MODEL_NAME = "intfloat/multilingual-e5-large"
# Cache path so model doesn't re-download. Set via env var or default.
MODEL_CACHE = os.environ.get(
    "MEMO_MODEL_CACHE",
    os.path.join(os.path.expanduser("~"), ".cache", "memo-models")
)

_model = None

def get_model():
    """Lazy-load the embedding model. Downloads on first use (~1.1GB)."""
    global _model
    if _model is None:
        from sentence_transformers import SentenceTransformer
        _model = SentenceTransformer(MODEL_NAME, cache_folder=MODEL_CACHE)
    return _model


def encode_passage(text: str) -> np.ndarray:
    """Encode a document/passage for indexing. Uses 'passage: ' prefix for e5."""
    model = get_model()
    return model.encode(f"passage: {text}")


def encode_query(text: str) -> np.ndarray:
    """Encode a search query. Uses 'query: ' prefix for e5."""
    model = get_model()
    return model.encode(f"query: {text}")


def get_db_path(vault_path: str) -> str:
    return os.path.join(vault_path, ".memo", "index.db")


def get_embeddings_path(vault_path: str) -> str:
    return os.path.join(vault_path, ".memo", "embeddings.npy")


def get_id_map_path(vault_path: str) -> str:
    return os.path.join(vault_path, ".memo", "id_map.json")


def ensure_memo_dir(vault_path: str):
    memo_dir = os.path.join(vault_path, ".memo")
    os.makedirs(memo_dir, exist_ok=True)


def get_lock_path(vault_path: str) -> str:
    return os.path.join(vault_path, ".memo", "write.lock")


class VaultLock:
    """File-based lock to prevent concurrent writes to vault index."""
    def __init__(self, vault_path: str):
        ensure_memo_dir(vault_path)
        self.lock_path = get_lock_path(vault_path)
        self.lock_file = None

    def __enter__(self):
        self.lock_file = open(self.lock_path, "w")
        try:
            fcntl.flock(self.lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            # Another process has the lock — wait for it
            fcntl.flock(self.lock_file, fcntl.LOCK_EX)
        return self

    def __exit__(self, *args):
        if self.lock_file:
            fcntl.flock(self.lock_file, fcntl.LOCK_UN)
            self.lock_file.close()


# ─── Frontmatter parser ───

# Use shared parser (PyYAML when available, safe fallback)
from memo_utils import parse_frontmatter, call_haiku, parse_json_response


def extract_title(body: str) -> str:
    """Extract the first H1 heading from markdown body."""
    for line in body.split("\n"):
        if line.startswith("# "):
            return line[2:].strip()
    return "(untitled)"


def extract_wikilinks(body: str) -> list[str]:
    """Extract all [[wikilinks]] from the body."""
    return re.findall(r"\[\[([^\]]+)\]\]", body)


def compute_file_hash(filepath: str) -> str:
    """SHA256 hash for change detection."""
    with open(filepath, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


# ─── Database ───

def init_db(vault_path: str) -> sqlite3.Connection:
    """Initialize SQLite database with FTS5 virtual table."""
    ensure_memo_dir(vault_path)
    db_path = get_db_path(vault_path)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row

    conn.executescript("""
        CREATE TABLE IF NOT EXISTS notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            filepath TEXT UNIQUE NOT NULL,
            filename TEXT NOT NULL,
            title TEXT NOT NULL,
            type TEXT,
            project TEXT,
            created TEXT,
            updated TEXT,
            tags TEXT,          -- JSON array
            aliases TEXT,       -- JSON array
            wikilinks TEXT,     -- JSON array
            content_hash TEXT,
            indexed_at TEXT,
            body TEXT           -- full markdown body for search
        );

        CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
            title, body, tags, aliases,
            content='notes',
            content_rowid='id'
        );

        -- Triggers to keep FTS in sync
        CREATE TRIGGER IF NOT EXISTS notes_ai AFTER INSERT ON notes BEGIN
            INSERT INTO notes_fts(rowid, title, body, tags, aliases)
            VALUES (new.id, new.title, new.body, new.tags, new.aliases);
        END;

        CREATE TRIGGER IF NOT EXISTS notes_ad AFTER DELETE ON notes BEGIN
            INSERT INTO notes_fts(notes_fts, rowid, title, body, tags, aliases)
            VALUES ('delete', old.id, old.title, old.body, old.tags, old.aliases);
        END;

        CREATE TRIGGER IF NOT EXISTS notes_au AFTER UPDATE ON notes BEGIN
            INSERT INTO notes_fts(notes_fts, rowid, title, body, tags, aliases)
            VALUES ('delete', old.id, old.title, old.body, old.tags, old.aliases);
            INSERT INTO notes_fts(rowid, title, body, tags, aliases)
            VALUES (new.id, new.title, new.body, new.tags, new.aliases);
        END;
    """)
    return conn


# ─── Embeddings store ───

class EmbeddingsStore:
    """Simple numpy-based embeddings storage with ID mapping."""

    def __init__(self, vault_path: str):
        self.vault_path = vault_path
        self.emb_path = get_embeddings_path(vault_path)
        self.map_path = get_id_map_path(vault_path)
        self.embeddings = None  # (N, D) numpy array
        self.id_map = []         # list of note IDs, index-aligned with embeddings
        self._load()

    def _load(self):
        if os.path.exists(self.emb_path) and os.path.exists(self.map_path):
            self.embeddings = np.load(self.emb_path)
            with open(self.map_path) as f:
                self.id_map = json.load(f)
        else:
            self.embeddings = None
            self.id_map = []

    def _save(self):
        ensure_memo_dir(self.vault_path)
        if self.embeddings is not None:
            np.save(self.emb_path, self.embeddings)
        with open(self.map_path, "w") as f:
            json.dump(self.id_map, f)

    def add(self, note_id: int, embedding: np.ndarray, defer_save: bool = False):
        """Add or update embedding for a note.

        Args:
            defer_save: If True, skip disk write (for batch operations).
                        Call flush() when done.
        """
        embedding = embedding.reshape(1, -1)

        if note_id in self.id_map:
            idx = self.id_map.index(note_id)
            self.embeddings[idx] = embedding
        else:
            if self.embeddings is None:
                self.embeddings = embedding
            else:
                self.embeddings = np.vstack([self.embeddings, embedding])
            self.id_map.append(note_id)

        if not defer_save:
            self._save()

    def flush(self):
        """Write current state to disk. Call after batch add operations."""
        self._save()

    def remove(self, note_id: int):
        """Remove embedding for a note."""
        if note_id in self.id_map:
            idx = self.id_map.index(note_id)
            self.id_map.pop(idx)
            if self.embeddings is not None:
                self.embeddings = np.delete(self.embeddings, idx, axis=0)
                if len(self.embeddings) == 0:
                    self.embeddings = None
            self._save()

    def search(self, query_embedding: np.ndarray, top_k: int = 10) -> list[tuple[int, float]]:
        """Return (note_id, similarity) pairs sorted by similarity desc."""
        if self.embeddings is None or len(self.id_map) == 0:
            return []

        query_embedding = query_embedding.reshape(1, -1)
        # Cosine similarity
        norms_db = np.linalg.norm(self.embeddings, axis=1, keepdims=True)
        norms_db = np.where(norms_db == 0, 1, norms_db)
        norm_q = np.linalg.norm(query_embedding)
        if norm_q == 0:
            return []

        similarities = (self.embeddings @ query_embedding.T).flatten() / (norms_db.flatten() * norm_q)
        top_indices = np.argsort(similarities)[::-1][:top_k]

        results = []
        for idx in top_indices:
            results.append((self.id_map[idx], float(similarities[idx])))
        return results

    def clear(self):
        self.embeddings = None
        self.id_map = []
        self._save()


# ─── Core operations ───

def index_file(filepath: str, vault_path: str, conn: sqlite3.Connection, store: EmbeddingsStore, **kwargs):
    """Index a single markdown file into SQLite + embeddings.

    Kwargs:
        defer_save: Skip disk write for embeddings (for batch operations).
    """
    filepath = os.path.abspath(filepath)
    rel_path = os.path.relpath(filepath, vault_path)

    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    file_hash = compute_file_hash(filepath)

    # Check if already indexed and unchanged
    existing = conn.execute(
        "SELECT id, content_hash FROM notes WHERE filepath = ?", (rel_path,)
    ).fetchone()

    if existing and existing["content_hash"] == file_hash:
        return existing["id"]  # No changes

    meta, body = parse_frontmatter(content)
    title = extract_title(body)
    wikilinks = extract_wikilinks(body)

    tags_json = json.dumps(meta.get("tags", []))
    aliases_json = json.dumps(meta.get("aliases", []))
    wikilinks_json = json.dumps(wikilinks)
    now = datetime.now().isoformat()

    if existing:
        conn.execute("""
            UPDATE notes SET
                filename=?, title=?, type=?, project=?, created=?, updated=?,
                tags=?, aliases=?, wikilinks=?, content_hash=?, indexed_at=?, body=?
            WHERE id=?
        """, (
            os.path.basename(filepath), title,
            meta.get("type"), meta.get("project"),
            meta.get("created"), meta.get("updated"),
            tags_json, aliases_json, wikilinks_json,
            file_hash, now, body,
            existing["id"]
        ))
        note_id = existing["id"]
    else:
        cur = conn.execute("""
            INSERT INTO notes (filepath, filename, title, type, project, created,
                             updated, tags, aliases, wikilinks, content_hash,
                             indexed_at, body)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            rel_path, os.path.basename(filepath), title,
            meta.get("type"), meta.get("project"),
            meta.get("created"), meta.get("updated"),
            tags_json, aliases_json, wikilinks_json,
            file_hash, now, body
        ))
        note_id = cur.lastrowid

    conn.commit()

    # Generate and store embedding (e5 models need "passage: " prefix)
    aliases = meta.get("aliases", [])
    tags = meta.get("tags", [])
    embed_text = f"{title}. {' '.join(aliases)}. {' '.join(tags)}. {body[:500]}"

    embedding = encode_passage(embed_text)
    store.add(note_id, embedding, defer_save=kwargs.get("defer_save", False))

    return note_id


def search_vault(query: str, vault_path: str, limit: int = 10, threshold: float = 0.0):
    """Combined semantic + keyword search."""
    conn = init_db(vault_path)
    store = EmbeddingsStore(vault_path)

    results = {}

    # 1. Semantic search (e5 models need "query: " prefix)
    query_emb = encode_query(query)
    sem_results = store.search(query_emb, top_k=limit * 2)

    for note_id, score in sem_results:
        if score >= threshold:
            results[note_id] = {"semantic_score": score, "keyword_score": 0.0}

    # 2. Keyword search via FTS5
    try:
        # Escape special FTS5 characters
        safe_query = re.sub(r'[^\w\s]', ' ', query)
        terms = safe_query.split()
        fts_query = " OR ".join(terms)

        rows = conn.execute("""
            SELECT rowid, rank FROM notes_fts WHERE notes_fts MATCH ?
            ORDER BY rank LIMIT ?
        """, (fts_query, limit * 2)).fetchall()

        for row in rows:
            note_id = row["rowid"]
            # Normalize FTS rank to 0-1 range (rank is negative, lower = better)
            keyword_score = min(1.0, 1.0 / (1.0 + abs(row["rank"])))
            if note_id in results:
                results[note_id]["keyword_score"] = keyword_score
            else:
                results[note_id] = {"semantic_score": 0.0, "keyword_score": keyword_score}
    except Exception:
        pass  # FTS might fail on empty db or bad query

    # 3. Combine scores (weighted: 60% semantic, 40% keyword)
    scored = []
    for note_id, scores in results.items():
        combined = 0.6 * scores["semantic_score"] + 0.4 * scores["keyword_score"]
        scored.append((note_id, combined, scores["semantic_score"], scores["keyword_score"]))

    scored.sort(key=lambda x: x[1], reverse=True)
    scored = scored[:limit]

    # 4. Fetch note metadata
    output = []
    for note_id, combined, sem, kw in scored:
        row = conn.execute(
            "SELECT filepath, title, type, project, tags, created FROM notes WHERE id = ?",
            (note_id,)
        ).fetchone()
        if row:
            output.append({
                "id": note_id,
                "filepath": row["filepath"],
                "title": row["title"],
                "type": row["type"],
                "project": row["project"],
                "tags": row["tags"],
                "created": row["created"],
                "score": round(combined, 3),
                "semantic": round(sem, 3),
                "keyword": round(kw, 3),
            })

    conn.close()
    return output


def find_duplicates(vault_path: str, threshold: float = 0.7):
    """Find semantically similar note pairs."""
    conn = init_db(vault_path)
    store = EmbeddingsStore(vault_path)

    if store.embeddings is None or len(store.id_map) < 2:
        print("Not enough notes to check for duplicates.")
        conn.close()
        return []

    # Compute pairwise similarities
    emb = store.embeddings
    norms = np.linalg.norm(emb, axis=1, keepdims=True)
    norms = np.where(norms == 0, 1, norms)
    normalized = emb / norms
    sim_matrix = normalized @ normalized.T

    pairs = []
    n = len(store.id_map)
    for i in range(n):
        for j in range(i + 1, n):
            if sim_matrix[i, j] >= threshold:
                id_a = store.id_map[i]
                id_b = store.id_map[j]
                row_a = conn.execute("SELECT filepath, title FROM notes WHERE id=?", (id_a,)).fetchone()
                row_b = conn.execute("SELECT filepath, title FROM notes WHERE id=?", (id_b,)).fetchone()
                if row_a and row_b:
                    pairs.append({
                        "note_a": {"id": id_a, "title": row_a["title"], "path": row_a["filepath"]},
                        "note_b": {"id": id_b, "title": row_b["title"], "path": row_b["filepath"]},
                        "similarity": round(float(sim_matrix[i, j]), 3)
                    })

    pairs.sort(key=lambda x: x["similarity"], reverse=True)
    conn.close()
    return pairs


def list_notes(vault_path: str, limit: int = 10):
    """List recent notes."""
    conn = init_db(vault_path)
    rows = conn.execute("""
        SELECT filepath, title, type, project, tags, created
        FROM notes ORDER BY created DESC LIMIT ?
    """, (limit,)).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def vault_stats(vault_path: str):
    """Aggregate vault statistics."""
    conn = init_db(vault_path)

    total = conn.execute("SELECT COUNT(*) as c FROM notes").fetchone()["c"]
    by_type = conn.execute(
        "SELECT type, COUNT(*) as c FROM notes GROUP BY type ORDER BY c DESC"
    ).fetchall()
    by_project = conn.execute(
        "SELECT project, COUNT(*) as c FROM notes WHERE project IS NOT NULL GROUP BY project ORDER BY c DESC"
    ).fetchall()

    # Most connected notes (by wikilink count)
    rows = conn.execute("SELECT title, wikilinks FROM notes").fetchall()
    link_counts = []
    for r in rows:
        links = json.loads(r["wikilinks"]) if r["wikilinks"] else []
        link_counts.append((r["title"], len(links)))
    link_counts.sort(key=lambda x: x[1], reverse=True)

    # Orphans (no incoming or outgoing links)
    all_links = set()
    for r in rows:
        links = json.loads(r["wikilinks"]) if r["wikilinks"] else []
        all_links.update(links)

    all_titles = {r["title"] for r in rows}

    # Tag frequency
    tag_freq = {}
    for r in conn.execute("SELECT tags FROM notes").fetchall():
        tags = json.loads(r["tags"]) if r["tags"] else []
        for tag in tags:
            tag_freq[tag] = tag_freq.get(tag, 0) + 1

    conn.close()

    return {
        "total_notes": total,
        "by_type": [(dict(r)["type"] or "untyped", dict(r)["c"]) for r in by_type],
        "by_project": [(dict(r)["project"], dict(r)["c"]) for r in by_project],
        "most_connected": link_counts[:10],
        "top_tags": sorted(tag_freq.items(), key=lambda x: x[1], reverse=True)[:15],
    }


def reindex_vault(vault_path: str, full: bool = True):
    """Reindex vault. Full mode drops everything; incremental uses content_hash.

    Incremental mode (full=False):
      - Walks all .md files, compares content_hash with DB
      - Only re-indexes files that changed or are new
      - Removes DB entries for deleted files
      - Much faster for large vaults on cron

    Full mode (full=True):
      - Drops and rebuilds entire index
      - Use after manual bulk edits or index corruption
    """
    if full:
        db_path = get_db_path(vault_path)
        emb_path = get_embeddings_path(vault_path)
        map_path = get_id_map_path(vault_path)
        for p in [db_path, emb_path, map_path]:
            if os.path.exists(p):
                os.remove(p)

    conn = init_db(vault_path)
    store = EmbeddingsStore(vault_path)

    # Collect all current markdown files
    current_files = {}  # rel_path → abs_path
    for root, dirs, files in os.walk(vault_path):
        dirs[:] = [d for d in dirs if d not in (".obsidian", ".memo", ".git", "daily-logs")]
        for f in files:
            if f.endswith(".md") and f != "INDEX.md":
                abs_path = os.path.join(root, f)
                rel_path = os.path.relpath(abs_path, vault_path)
                current_files[rel_path] = abs_path

    # For incremental: check what's already indexed
    indexed = 0
    skipped = 0
    removed = 0

    if not full:
        # Get existing hashes from DB
        existing = {}
        for row in conn.execute("SELECT filepath, content_hash, id FROM notes").fetchall():
            existing[row["filepath"]] = (row["content_hash"], row["id"])

        # Remove entries for deleted files
        for rel_path, (_, note_id) in existing.items():
            if rel_path not in current_files:
                conn.execute("DELETE FROM notes WHERE id = ?", (note_id,))
                store.remove(note_id)
                removed += 1
        if removed:
            conn.commit()

        # Index only changed/new files
        for rel_path, abs_path in current_files.items():
            file_hash = hashlib.sha256(open(abs_path, "rb").read()).hexdigest()[:16]
            if rel_path in existing and existing[rel_path][0] == file_hash:
                skipped += 1
                continue
            index_file(abs_path, vault_path, conn, store, defer_save=True)
            indexed += 1
            if indexed % 50 == 0:
                print(f"  Indexed {indexed} notes...")
    else:
        # Full reindex — all files, batch mode
        for rel_path, abs_path in current_files.items():
            index_file(abs_path, vault_path, conn, store, defer_save=True)
            indexed += 1
            if indexed % 50 == 0:
                print(f"  Indexed {indexed} notes...")

    # Single flush at the end (batch mode — no 500x file rewrites)
    store.flush()
    conn.close()

    mode = "Full" if full else "Incremental"
    print(f"{mode} reindex complete: {indexed} indexed, {skipped} unchanged, {removed} removed.")


# ─── Obsidian CLI integration (optional) ───

class ObsidianCLI:
    """Optional integration with Obsidian's CLI tool.

    Obsidian CLI (enabled in Settings → General → Command Line Interface)
    provides terminal access to vault graph data: backlinks, orphans,
    dead-ends, tags. More accurate than our regex parsing because
    Obsidian resolves aliases, partial matches, and case-insensitive links.

    All methods return None if CLI is not available — callers must handle
    the fallback gracefully. No method raises exceptions.
    """

    def __init__(self, vault_path: str):
        self.vault_path = vault_path
        self._available = None  # Lazy check

    def is_available(self) -> bool:
        """Check if Obsidian CLI is installed and responsive."""
        if self._available is not None:
            return self._available
        try:
            result = subprocess.run(
                ["obsidian", "help"],
                capture_output=True, text=True, timeout=5
            )
            self._available = result.returncode == 0
        except (FileNotFoundError, subprocess.TimeoutExpired):
            self._available = False
        return self._available

    def _run(self, *args) -> str | None:
        """Run an Obsidian CLI command, return stdout or None on failure."""
        if not self.is_available():
            return None
        try:
            result = subprocess.run(
                ["obsidian", *args],
                capture_output=True, text=True, timeout=15,
                cwd=self.vault_path
            )
            if result.returncode == 0:
                return result.stdout.strip()
            return None
        except (subprocess.TimeoutExpired, Exception):
            return None

    def get_orphans(self) -> list[str] | None:
        """Get notes with no incoming links (Obsidian's definition)."""
        output = self._run("orphans")
        if output is None:
            return None
        return [line.strip() for line in output.splitlines() if line.strip()]

    def get_dead_ends(self) -> list[str] | None:
        """Get broken/unresolved links in the vault."""
        output = self._run("dead-ends")
        if output is None:
            return None
        return [line.strip() for line in output.splitlines() if line.strip()]

    def get_backlinks(self, note_path: str) -> list[str] | None:
        """Get all notes linking TO a specific note."""
        output = self._run("backlink-path", note_path)
        if output is None:
            return None
        return [line.strip() for line in output.splitlines() if line.strip()]

    def get_links(self, note_path: str) -> list[str] | None:
        """Get all notes a specific note links TO."""
        output = self._run("link-path", note_path)
        if output is None:
            return None
        return [line.strip() for line in output.splitlines() if line.strip()]

    def get_tag_counts(self) -> dict[str, int] | None:
        """Get tag usage statistics from the vault."""
        output = self._run("tag-counts")
        if output is None:
            return None
        tags = {}
        for line in output.splitlines():
            line = line.strip()
            if not line:
                continue
            # Expected format: "tag_name: count" or "tag_name (count)"
            parts = line.rsplit(":", 1)
            if len(parts) == 2:
                tag = parts[0].strip().lstrip("#")
                try:
                    tags[tag] = int(parts[1].strip())
                except ValueError:
                    pass
        return tags if tags else None

    def get_vault_info(self) -> dict | None:
        """Aggregate info from all available CLI commands."""
        if not self.is_available():
            return None

        info = {"cli_available": True}

        orphans = self.get_orphans()
        if orphans is not None:
            info["orphans"] = orphans
            info["orphan_count"] = len(orphans)

        dead_ends = self.get_dead_ends()
        if dead_ends is not None:
            info["dead_ends"] = dead_ends
            info["dead_end_count"] = len(dead_ends)

        tags = self.get_tag_counts()
        if tags is not None:
            info["tag_counts"] = tags

        return info


def lint_vault(vault_path: str) -> dict:
    """Run 7 health checks on the vault. Returns issues found.

    When Obsidian CLI is available, uses it for more accurate
    orphan/backlink detection (Obsidian resolves aliases and
    partial matches that our regex parser might miss).
    """
    conn = init_db(vault_path)
    issues = {
        "broken_links": [],
        "orphan_notes": [],
        "missing_backlinks": [],
        "empty_notes": [],
        "uncompiled_logs": [],
        "notes_without_tags": [],
        "notes_without_aliases": [],
    }

    # Try Obsidian CLI for more accurate graph data
    obs_cli = ObsidianCLI(vault_path)
    obs_available = obs_cli.is_available()

    if obs_available:
        # Use Obsidian's own orphan detection (more accurate)
        cli_orphans = obs_cli.get_orphans()
        if cli_orphans is not None:
            issues["orphan_notes"] = [{"filepath": f, "title": f, "source": "obsidian-cli"} for f in cli_orphans]

        cli_dead_ends = obs_cli.get_dead_ends()
        if cli_dead_ends is not None:
            issues["broken_links"] = [{"source": "vault", "broken_link": f, "source_info": "obsidian-cli"} for f in cli_dead_ends]

    # Load all notes
    all_notes = conn.execute("SELECT id, filepath, title, tags, aliases, wikilinks, body FROM notes").fetchall()
    all_filepaths = {row["filepath"] for row in all_notes}
    all_titles = {row["title"] for row in all_notes}

    # Build maps
    filepath_to_title = {row["filepath"]: row["title"] for row in all_notes}
    title_to_filepath = {}
    for row in all_notes:
        title_to_filepath[row["title"]] = row["filepath"]

    # Collect all outgoing wikilinks per note
    outgoing = {}  # filepath -> list of link targets
    all_link_targets = set()
    for row in all_notes:
        links = json.loads(row["wikilinks"]) if row["wikilinks"] else []
        outgoing[row["filepath"]] = links
        all_link_targets.update(links)

    # Collect all incoming links per note
    incoming = {}  # filepath -> set of source filepaths
    for filepath, links in outgoing.items():
        for link in links:
            # Link could be "decisions/2026-04-11-some-slug" or just "some-slug"
            # Check if any note filepath matches
            matched = False
            for fp in all_filepaths:
                fp_no_ext = os.path.splitext(fp)[0]
                if link == fp_no_ext or link in fp_no_ext:
                    incoming.setdefault(fp, set()).add(filepath)
                    matched = True
                    break
            if not matched:
                # Check if link matches a title
                if link not in all_titles:
                    if not obs_available:  # Only use regex parser if CLI unavailable
                        issues["broken_links"].append({
                            "source": filepath,
                            "broken_link": link,
                        })

    # 2. Orphan notes: no incoming links at all
    if not obs_available:  # CLI gives more accurate orphan data
        for row in all_notes:
            fp = row["filepath"]
            if fp not in incoming and not fp.startswith("projects/"):
                # Project notes are entry points, don't flag as orphans
                issues["orphan_notes"].append({
                    "filepath": fp,
                    "title": row["title"],
                })

    # 3. Missing backlinks: A links to B, but B doesn't link to A
    for source_fp, links in outgoing.items():
        for link in links:
            for target_fp in all_filepaths:
                target_no_ext = os.path.splitext(target_fp)[0]
                if link == target_no_ext or link in target_no_ext:
                    # Check if target links back to source
                    target_links = outgoing.get(target_fp, [])
                    source_no_ext = os.path.splitext(source_fp)[0]
                    has_backlink = any(
                        source_no_ext == tl or source_no_ext in tl
                        for tl in target_links
                    )
                    if not has_backlink:
                        issues["missing_backlinks"].append({
                            "source": source_fp,
                            "target": target_fp,
                        })

    # 4. Empty notes: body < 200 characters
    for row in all_notes:
        body = row["body"] or ""
        if len(body.strip()) < 200:
            issues["empty_notes"].append({
                "filepath": row["filepath"],
                "title": row["title"],
                "chars": len(body.strip()),
            })

    # 5. Uncompiled daily logs
    logs_dir = os.path.join(vault_path, "daily-logs")
    if os.path.exists(logs_dir):
        for f in os.listdir(logs_dir):
            if f.endswith(".md"):
                fp = os.path.join(logs_dir, f)
                try:
                    with open(fp, "r") as fh:
                        content = fh.read()
                    if "<!-- compiled -->" not in content and len(content) > 200:
                        issues["uncompiled_logs"].append(f)
                except Exception:
                    pass

    # 6. Notes without tags
    for row in all_notes:
        tags = json.loads(row["tags"]) if row["tags"] else []
        if not tags:
            issues["notes_without_tags"].append({
                "filepath": row["filepath"],
                "title": row["title"],
            })

    # 7. Notes without aliases
    for row in all_notes:
        aliases = json.loads(row["aliases"]) if row["aliases"] else []
        if not aliases:
            issues["notes_without_aliases"].append({
                "filepath": row["filepath"],
                "title": row["title"],
            })

    conn.close()

    # Summary
    total_issues = sum(len(v) for v in issues.values())
    issues["_summary"] = {
        "total_issues": total_issues,
        "total_notes": len(all_notes),
        "checks_run": 7,
        "obsidian_cli": obs_available,
    }

    return issues


def query_vault(query: str, vault_path: str) -> str:
    """Search vault and synthesize an answer using Claude Haiku."""
    # First, find relevant notes
    results = search_vault(query, vault_path, limit=5, threshold=0.3)

    if not results:
        return "No relevant notes found in the vault."

    # Read the actual content of top results
    context_parts = []
    for r in results[:3]:  # Top 3
        filepath = os.path.join(vault_path, r["filepath"])
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                content = f.read()
            # Truncate long notes
            if len(content) > 3000:
                content = content[:3000] + "\n...[truncated]"
            context_parts.append(f"### {r['title']} (score: {r['score']})\n\n{content}")
        except Exception:
            continue

    if not context_parts:
        return "Found references but could not read note contents."

    context = "\n\n---\n\n".join(context_parts)

    prompt = f"""Based on the following notes from my engineering knowledge vault, answer this question concisely and practically.

If the notes contain the answer, give it directly with specific details.
If the notes are only partially relevant, say what you found and what's missing.
Respond in the same language as the question.

QUESTION: {query}

VAULT NOTES:
{context}"""

    # Use secure API client (no API key in ps, no curl dependency)
    answer = call_haiku(prompt, max_tokens=2000)
    if answer:
        sources = "\n".join(f"  - {r['title']} ({r['filepath']})" for r in results[:3])
        return f"{answer}\n\n---\nSources:\n{sources}"

    # Fallback: return raw search results
    return "API call failed. Raw results:\n" + json.dumps(results, indent=2, ensure_ascii=False)


# ─── CLI ───

def main():
    parser = argparse.ArgumentParser(description="Memo vault engine")
    parser.add_argument("command", choices=[
        "index-file", "search", "query", "dedup", "lint", "list", "stats",
        "reindex", "warm-up", "obsidian-info"
    ])
    parser.add_argument("query_text", nargs="?", default="", metavar="query")
    parser.add_argument("--vault", default="", help="Path to vault root")
    parser.add_argument("--limit", type=int, default=10)
    parser.add_argument("--threshold", type=float, default=0.0)
    parser.add_argument("--incremental", action="store_true",
                        help="Incremental reindex: only changed files (default for cron)")

    args = parser.parse_args()
    vault = os.path.expanduser(args.vault) if args.vault else ""

    if args.command == "warm-up":
        print("Loading embedding model...")
        get_model()
        print(f"Model {MODEL_NAME} ready.")
        sys.exit(0)

    if not vault:
        print("Error: --vault required for this command", file=sys.stderr)
        sys.exit(1)

    if args.command == "index-file":
        if not args.query_text:
            print("Error: file path required", file=sys.stderr)
            sys.exit(1)
        with VaultLock(vault):
            conn = init_db(vault)
            store = EmbeddingsStore(vault)
            note_id = index_file(args.query_text, vault, conn, store)
            conn.close()
        print(json.dumps({"indexed": True, "note_id": note_id}))

    elif args.command == "search":
        if not args.query_text:
            print("Error: search query required", file=sys.stderr)
            sys.exit(1)
        results = search_vault(args.query_text, vault, args.limit, args.threshold)
        print(json.dumps(results, indent=2, ensure_ascii=False))

    elif args.command == "query":
        if not args.query_text:
            print("Error: query required", file=sys.stderr)
            sys.exit(1)
        answer = query_vault(args.query_text, vault)
        print(answer)

    elif args.command == "dedup":
        th = args.threshold if args.threshold > 0 else 0.7
        pairs = find_duplicates(vault, th)
        print(json.dumps(pairs, indent=2, ensure_ascii=False))

    elif args.command == "lint":
        issues = lint_vault(vault)
        summary = issues.pop("_summary", {})
        cli_status = "yes" if summary.get("obsidian_cli") else "no (using regex fallback)"
        print(f"Vault lint: {summary.get('total_issues', 0)} issues in {summary.get('total_notes', 0)} notes")
        print(f"  Obsidian CLI: {cli_status}\n")
        for check, items in issues.items():
            if items:
                print(f"  {check}: {len(items)} issue(s)")
                for item in items[:5]:  # Show first 5
                    if isinstance(item, dict):
                        print(f"    - {item.get('title', item.get('filepath', item.get('source', str(item))))}")
                    else:
                        print(f"    - {item}")
                if len(items) > 5:
                    print(f"    ... and {len(items) - 5} more")

    elif args.command == "list":
        notes = list_notes(vault, args.limit)
        print(json.dumps(notes, indent=2, ensure_ascii=False))

    elif args.command == "stats":
        s = vault_stats(vault)
        print(json.dumps(s, indent=2, ensure_ascii=False))

    elif args.command == "reindex":
        with VaultLock(vault):
            reindex_vault(vault, full=not args.incremental)

    elif args.command == "obsidian-info":
        obs = ObsidianCLI(vault)
        if not obs.is_available():
            print("Obsidian CLI not available.")
            print("To enable: Obsidian → Settings → General → Command Line Interface → ON")
            print("Memo works fine without it (uses built-in search + regex parsing).")
            print("CLI adds more accurate orphan detection and backlink resolution.")
            sys.exit(0)
        info = obs.get_vault_info()
        if info:
            print(json.dumps(info, indent=2, ensure_ascii=False))
        else:
            print("Obsidian CLI available but returned no data.")


if __name__ == "__main__":
    main()
