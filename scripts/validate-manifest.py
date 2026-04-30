#!/usr/bin/env python3
"""validate-manifest.py — Validate manifest.json v2 schema.

Exit 0 on pass. Exit 1 with stderr messages on any failure.

Checks performed (per D-24):
  1. manifest_version == 2
  2. Every entry under files.* is an object with a required "path" key
  3. Every "conflicts_with" value is in the allowed vocabulary
  4. No duplicate paths across all files.* sections
  5. Every path referenced in files.* and templates.* exists on disk
  6. Disk-to-manifest drift: files present on disk in tracked buckets
     (commands/, templates/base/skills/*/SKILL.md) must be listed in manifest

Manifest paths are install-destination paths (relative to the .claude/ target
directory). The source files live in the toolkit repo at different locations:

  agents/*    → templates/base/agents/*
  prompts/*   → templates/base/prompts/*
  skills/*    → templates/base/skills/*
  rules/*     → templates/base/rules/*
  commands/*  → commands/*   (repo root)
"""

import json
import os
import sys

ALLOWED_CONFLICTS = {"superpowers", "get-shit-done"}

# Commands that ship globally to ~/.claude/commands/ (installed by
# setup-council.sh / setup-security.sh, NOT per-project via manifest).
# These files live in commands/ on disk so installers can curl them, but
# are intentionally absent from files.commands[]. Drift check skips them.
GLOBAL_ONLY_COMMANDS = {"council.md", "council-stats.md", "council-clear-cache.md"}

# Resolve repo root relative to this script (scripts/ is one level below root)
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
MANIFEST_PATH = os.path.join(REPO_ROOT, "manifest.json")

# Mapping from install-destination prefix → source directory in the repo.
# Key: destination path prefix (no trailing slash)
# Value: source directory relative to REPO_ROOT
SOURCE_MAP = {
    "agents/": "templates/base/agents/",
    "prompts/": "templates/base/prompts/",
    "skills/": "templates/base/skills/",
    "rules/": "templates/base/rules/",
    "commands/": "commands/",
}


def resolve_source_path(manifest_path):
    """Translate a manifest install-destination path to its on-disk source path."""
    for prefix, source_dir in SOURCE_MAP.items():
        if manifest_path.startswith(prefix):
            relative = manifest_path[len(prefix):]
            return os.path.join(REPO_ROOT, source_dir, relative)
    # Fallback: treat path as repo-relative (e.g. skill-rules.json edge case)
    return os.path.join(REPO_ROOT, manifest_path)


def fail(message):
    print("ERROR: " + message, file=sys.stderr)


def main():
    errors = 0

    # Load manifest
    try:
        with open(MANIFEST_PATH, "r", encoding="utf-8") as fh:
            manifest = json.load(fh)
    except FileNotFoundError:
        fail("manifest.json not found at: " + MANIFEST_PATH)
        sys.exit(1)
    except json.JSONDecodeError as exc:
        fail("manifest.json is not valid JSON: " + str(exc))
        sys.exit(1)

    # Check 1: manifest_version == 2
    version = manifest.get("manifest_version")
    if version != 2:
        fail(
            "manifest_version must be 2, got: "
            + repr(version)
            + " — run migration to upgrade"
        )
        errors += 1

    # Collect all file entries from files.*
    files_section = manifest.get("files", {})
    all_paths = []

    for section_name, entries in files_section.items():
        if not isinstance(entries, list):
            fail("files." + section_name + " must be an array")
            errors += 1
            continue

        for idx, entry in enumerate(entries):
            location = "files." + section_name + "[" + str(idx) + "]"

            # Check 2: every entry must be an object with "path"
            if not isinstance(entry, dict):
                fail(location + ": entry must be an object, got " + type(entry).__name__)
                errors += 1
                continue

            if "path" not in entry:
                fail(location + ': missing required "path" key')
                errors += 1
                continue

            path_value = entry["path"]

            # Check 4: collect for duplicate detection
            all_paths.append((location, path_value))

            # Check 3: conflicts_with vocabulary
            conflicts = entry.get("conflicts_with")
            if conflicts is not None:
                if not isinstance(conflicts, list):
                    fail(location + ': "conflicts_with" must be an array')
                    errors += 1
                else:
                    for value in conflicts:
                        if value not in ALLOWED_CONFLICTS:
                            fail(
                                location
                                + ': "conflicts_with" value '
                                + repr(value)
                                + " is not in allowed set "
                                + str(sorted(ALLOWED_CONFLICTS))
                            )
                            errors += 1

            # Check 5: path exists on disk (resolve install-dest path to source)
            full_path = resolve_source_path(path_value)
            if not os.path.exists(full_path):
                fail(location + ": path does not exist on disk: " + path_value)
                errors += 1

    # Check 4: duplicate paths
    seen_paths = {}
    for location, path_value in all_paths:
        if path_value in seen_paths:
            fail(
                "duplicate path "
                + repr(path_value)
                + " in "
                + location
                + " (first seen at "
                + seen_paths[path_value]
                + ")"
            )
            errors += 1
        else:
            seen_paths[path_value] = location

    # Check templates.* — each value must be an object with "path" that exists
    templates_section = manifest.get("templates", {})
    for tmpl_name, tmpl_value in templates_section.items():
        location = "templates." + tmpl_name

        if not isinstance(tmpl_value, dict):
            fail(location + ": entry must be an object, got " + type(tmpl_value).__name__)
            errors += 1
            continue

        if "path" not in tmpl_value:
            fail(location + ': missing required "path" key')
            errors += 1
            continue

        path_value = tmpl_value["path"]
        full_path = os.path.join(REPO_ROOT, path_value)
        if not os.path.exists(full_path):
            fail(location + ": path does not exist on disk: " + path_value)
            errors += 1

    # Check 7: inventory.components[] — repo-root asset registry (NOT installed into .claude/)
    inventory_section = manifest.get("inventory", {})
    inventory_components = inventory_section.get("components", [])
    for idx, entry in enumerate(inventory_components):
        location = "inventory.components[" + str(idx) + "]"
        if not isinstance(entry, dict):
            fail(location + ": entry must be an object, got " + type(entry).__name__)
            errors += 1
            continue
        for required_field in ("path", "description"):
            if required_field not in entry:
                fail(location + ': missing required "' + required_field + '" key')
                errors += 1
        path_value = entry.get("path")
        if path_value:
            # Inventory paths are repo-root-relative (no SOURCE_MAP translation)
            full_path = os.path.join(REPO_ROOT, path_value)
            if not os.path.exists(full_path):
                fail(location + ": path does not exist on disk: " + path_value)
                errors += 1

    # Check 6: disk-to-manifest drift (files on disk not in manifest)
    manifest_paths = set(p for _, p in all_paths)

    commands_dir = os.path.join(REPO_ROOT, "commands")
    if os.path.isdir(commands_dir):
        for name in sorted(os.listdir(commands_dir)):
            if (
                name.endswith(".md")
                and name != "README.md"
                and name not in GLOBAL_ONLY_COMMANDS
            ):
                expected = "commands/" + name
                if expected not in manifest_paths:
                    fail("drift: " + expected + " exists on disk but is not in manifest files.commands")
                    errors += 1

    skills_dir = os.path.join(REPO_ROOT, "templates", "base", "skills")
    if os.path.isdir(skills_dir):
        for skill_name in sorted(os.listdir(skills_dir)):
            skill_file = os.path.join(skills_dir, skill_name, "SKILL.md")
            if os.path.isfile(skill_file):
                expected = "skills/" + skill_name + "/SKILL.md"
                if expected not in manifest_paths:
                    fail("drift: " + expected + " exists on disk but is not in manifest files.skills")
                    errors += 1

    # Audit M1: scripts/lib/ drift detection. update-claude.sh is
    # manifest-driven; a new lib file added without a manifest entry would
    # silently never propagate to existing users via update.
    libs_dir = os.path.join(REPO_ROOT, "scripts", "lib")
    if os.path.isdir(libs_dir):
        for name in sorted(os.listdir(libs_dir)):
            full = os.path.join(libs_dir, name)
            if not os.path.isfile(full):
                continue
            if name.startswith(".") or name.endswith((".bak", ".swp", ".orig")):
                continue
            if not (name.endswith(".sh") or name.endswith(".json")):
                continue
            expected = "scripts/lib/" + name
            if expected not in manifest_paths:
                fail("drift: " + expected + " exists on disk but is not in manifest files.libs")
                errors += 1

    if errors > 0:
        print(
            "manifest.json validation FAILED (" + str(errors) + " error(s))",
            file=sys.stderr,
        )
        sys.exit(1)

    print("manifest.json validation PASSED")
    sys.exit(0)


if __name__ == "__main__":
    main()
