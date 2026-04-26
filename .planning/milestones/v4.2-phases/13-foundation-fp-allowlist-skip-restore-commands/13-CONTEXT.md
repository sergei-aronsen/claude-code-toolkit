# Phase 13: Foundation — FP Allowlist + Skip/Restore Commands - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Repo-local false-positive allowlist file (`.claude/rules/audit-exceptions.md`)
plus two slash commands (`/audit-skip`, `/audit-restore`) that maintain it,
wired through three installers (`init-claude.sh`, `init-local.sh`,
`update-claude.sh`).

This phase ships the **storage layer** and the **maintenance commands** only.
Pipeline integration (Phase 14 reads the file in `/audit`), council mutation
(Phase 15 sets `council_status=disputed`), template propagation (Phase 16),
and manifest/CHANGELOG wiring (Phase 17) are downstream phases — Phase 13
must produce artifacts those phases can consume without changes.

</domain>

<decisions>
## Implementation Decisions

### Entry Schema / File Format

- **D-01:** Each allowlist entry is an ATX-heading block. Heading anchor:
  `### <path>:<line> — <rule-id>` (em-dash separator, U+2014). Body is three
  required key:value bullets in fixed order:

  ```markdown
  ### scripts/setup-security.sh:142 — SEC-RAW-EXEC

  - **Date:** 2026-04-25
  - **Council:** unreviewed
  - **Reason:** `bash -c` invocation runs hardcoded install commands,
    no user input flows into it. Sandbox-safe by construction.
  ```

  Multi-line `Reason` is allowed via continuation indent (4 spaces under
  the bullet). LLM-skimmable for auto-load context AND grep-parseable via
  the heading anchor pattern `^### .+:\d+ — .+$`.

- **D-02:** Seed file (created on first install) ships in this exact order:
  YAML frontmatter (`globs: ["**/*"]`, `description:`) → intro paragraph
  explaining the file's role + how `/audit-skip` writes here → `## Entries`
  H2 → one commented-out HTML example block (so users see the schema
  without it counting as a real entry). Schema-aligned with existing
  `templates/base/rules/project-context.md` and `templates/base/rules/README.md`.

- **D-03:** Append-only chronological order. New entries land at file EOF
  under the single `## Entries` H2. No alphabetical sort, no rule-id
  grouping. Rationale: simplest `/audit-skip` implementation (single-shot
  append, no rewrite), cleanest git diff (one addition at file tail),
  easiest duplicate detection.

### `/audit-skip` Command Design

- **D-04:** Argument signature = positional `<file:line> <rule>` followed
  by trailing-concat reason: every token after the rule-id is joined with
  single spaces and stored as `Reason`. Example invocation:

  ```text
  /audit-skip src/foo.ts:42 SEC-XSS user input is escaped upstream by escapeHtml
  ```

  No quoting required. Matches `git commit -m`-style ergonomics that
  slash-command users expect; no false-error rate from forgotten quotes.

- **D-05:** Pre-write validation (hard refusal — no `--force` escape):
  1. `git ls-files --error-unmatch <path>` → must succeed (file is tracked
     in HEAD or staged).
  2. Line count check: `awk 'END {print NR}' <path>` ≥ `<line>`.
  3. Duplicate check (D-06).

  Untracked-file refusal message must suggest `git add <path>` and re-run.
  Rationale: an exception against a file not in HEAD is a moving target;
  Phase 14/15 council reasoning depends on a stable code excerpt.

- **D-06:** Duplicate match key = **exact triple** `<path>:<line>:<rule>`,
  byte-for-byte case-sensitive. Same path+rule on a different line = NEW
  entry, not a duplicate. On match, `/audit-skip` refuses and prints the
  existing entry block (so user sees what's blocking). After a refactor
  shifts a finding from line 42 → 68, the user adds the new entry; the
  stale one is removed via `/audit-restore` if needed.

### `/audit-restore` Command Design

- **D-07:** Argument signature = positional `<file:line> <rule>` (no
  reason). Match key = same exact triple as D-06.

- **D-08:** Confirmation flow (mandatory per REQ-EXC-02):
  1. Find entry by triple match.
  2. Display the full ATX-heading block being deleted.
  3. Prompt `[y/N]` (default N).
  4. On confirm, remove the heading block and its bullets, leaving the
     surrounding `## Entries` structure intact.

  No-match case: print "no entry found for <triple>" and exit non-zero.

### `council_status` Field Semantics

- **D-09:** Allowed values: `unreviewed | council_confirmed_fp | disputed`.
  Phase 13 writes only `unreviewed` by default. `/audit-skip` accepts an
  optional `--council=council_confirmed_fp` flag (used by Phase 15 when a
  user persists an exception from a council `FALSE_POSITIVE` verdict per
  REQ-COUNCIL-05). The `disputed` value is reserved for Phase 15 council
  mutation when Gemini ↔ ChatGPT disagree on REAL/FP for an existing
  allowlist entry.

- **D-10:** Phase 13 ships the field plumbing; Phase 14 only READS it
  (filter findings); Phase 15 MAY mutate it (`unreviewed → disputed`,
  `unreviewed → council_confirmed_fp` when Phase 15 reconfirms). No
  `/audit-skip` invocation downgrades a `council_confirmed_fp` back to
  `unreviewed`.

### Claude's Discretion (research / plan resolves)

- **CD-01:** Installer seed pattern. Default expectation: follow the
  `lessons-learned.md` precedent — inline heredoc seed in `init-claude.sh`
  (around lines 510–540) and `init-local.sh` (around lines 304–320),
  NOT registered in `manifest.json`'s `files.rules[]` array. Rationale:
  the file is project-local mutable state, not a versioned shipped artifact.
  `update-claude.sh` therefore needs explicit seed-only-when-missing logic
  per REQ-EXC-05; if research uncovers a stronger reason to register in
  manifest (e.g. update-claude.sh smart-merge already handles `[ ! -f ]`
  via manifest), planner may switch.

- **CD-02:** `/audit-skip` post-write behavior. Default: write the file
  only — no `git add`, no `git commit`. User controls staging. Slash
  commands in this repo are declarative markdown Claude executes via
  Bash/Edit; not shell scripts.

- **CD-03:** Where the validation/parser logic lives. Slash commands here
  are markdown specs Claude interprets — there is no `scripts/audit-skip.sh`
  runner. Validation is described in `commands/audit-skip.md` as steps
  Claude performs with Bash + Edit. If the parser shape grows complex
  enough to deduplicate across `/audit-skip`, `/audit-restore`, and Phase
  14 `/audit`, planner may extract a shared `scripts/lib/audit-exceptions.sh`
  (precedent: `scripts/lib/backup.sh`, `scripts/lib/dry-run-output.sh`).

- **CD-04:** Markdown formatting of the seed file must pass `markdownlint`
  (`make lint`). Notably MD040 (fenced code blocks need a language),
  MD031/032 (blank lines around code/lists), MD026 (no trailing punct on
  headings).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### v4.2 Milestone Specs

- `.planning/REQUIREMENTS.md` §"Persistent FP Allowlist" — EXC-01..EXC-05 verbatim
- `.planning/ROADMAP.md` §"Phase 13" — success criteria 1–5
- `.planning/PROJECT.md` §"Constraints" + §"Key Decisions" — POSIX shell,
  macOS BSD compat, never-push-main, atomic writes, backup-before-mutate

### Existing Patterns to Follow

- `templates/base/rules/README.md` — rules dir conventions, `globs:` schema
- `templates/base/rules/project-context.md` — frontmatter precedent
  (`description:` + `globs: ["**/*"]`)
- `commands/learn.md` — rule-writing slash command pattern (closest analog)
- `commands/audit.md` — existing `/audit` command (Phase 14 will extend; D-05
  `/audit-skip` validation language should mirror its style)
- `commands/council.md` — slash command structure precedent

### Installer Wiring Points

- `scripts/init-claude.sh:352` — `$CLAUDE_DIR/rules` directory creation
- `scripts/init-claude.sh:510-540` — `lessons-learned.md` inline-seed precedent
  (the closest analog for `audit-exceptions.md` seeding)
- `scripts/init-local.sh:241` — parallel `rules/` mkdir
- `scripts/init-local.sh:304-320` — `lessons-learned.md` parallel seed
- `scripts/update-claude.sh` — smart-merge behavior; needs `[ ! -f ]` check
  for the seed file (REQ-EXC-05)
- `manifest.json` §`files.rules[]` and §`files.commands[]` — D-01 of CD-01
  affects whether `audit-exceptions.md` lands in `files.rules[]`

### Shared Library Precedents

- `scripts/lib/backup.sh` (Phase 9) — shared lib pattern
- `scripts/lib/dry-run-output.sh` (Phase 11) — shared lib pattern
- Both are sourced by curl in installer scripts; same approach available if
  CD-03 extraction is needed

### Codebase Conventions

- `.planning/codebase/CONVENTIONS.md` — naming, shell style, color helpers,
  POSIX requirements
- `.planning/codebase/STACK.md` — runtime constraints (no node/python in install
  scripts; markdownlint + shellcheck quality gates)
- `.planning/codebase/STRUCTURE.md` — repo layout, where commands/rules live

### CI / Quality Gates

- `Makefile` §`check`, §`lint`, §`shellcheck`, §`mdlint`, §`validate` —
  must pass on every PR
- `.github/workflows/quality.yml` — CI mirror of `make check`
- `.markdownlint.json` — disabled rules (MD013/033/041/060) and adjusted
  rules (MD024 siblings_only, MD029 ordered)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`lessons-learned.md` seed pattern** (`init-claude.sh:510-540`,
  `init-local.sh:304-320`): inline heredoc behind `[ ! -f "$file" ]`
  guard. Direct precedent for `audit-exceptions.md` seed.
- **YAML frontmatter convention** (`templates/base/rules/project-context.md`):
  `description:` + `globs:` keys, schema-aligned across all rule files.
- **3-installer parallel structure**: `init-claude.sh` (curl-from-remote),
  `init-local.sh` (cp-from-clone), `update-claude.sh` (refresh + smart
  merge). All share `[ ! -f ]` idempotency guard for project-local files.
- **Bash color helpers** (`RED/GREEN/YELLOW/BLUE/CYAN/NC`): consistent
  user-facing output across all scripts. Slash command output style
  should mirror.
- **`scripts/lib/*.sh` shared-library precedent** (backup.sh in Phase 9,
  dry-run-output.sh in Phase 11): if `/audit-skip`/`/audit-restore` parser
  logic grows complex, extract here.

### Established Patterns

- **POSIX shell + macOS BSD compat**: no GNU-only flags, no `head -n -1`,
  no `sed -i ''` without explicit handling. Validates via `make shellcheck`.
- **Atomic writes**: write to temp + `mv` for any rule-file mutation
  (`/audit-skip` append, `/audit-restore` deletion).
- **`< /dev/tty` for stdin** in `curl | bash`-style flows. `/audit-skip`
  is invoked from inside a Claude session, so doesn't need this directly,
  but `/audit-restore` `[y/N]` prompt logic should.
- **`set -euo pipefail`** at the top of every shell script if Claude
  generates one inside the slash command.
- **Idempotency**: every install/seed action behind `[ ! -f ]` or content
  hash check. EXC-05 requires this for the seed.

### Integration Points

- **Phase 14 `/audit` (REQ-AUDIT-01)** reads `audit-exceptions.md` in Phase 0
  of the audit pipeline; matches findings against entries by exact triple
  (D-06); drops matched findings into a "Skipped (allowlist)" table.
- **Phase 15 `/council audit-review` (REQ-COUNCIL-05)** prompts the user
  to invoke `/audit-skip` after a `FALSE_POSITIVE` verdict; user sets
  `--council=council_confirmed_fp` (D-09) to mark provenance.
- **Phase 17 manifest registration** depends on CD-01: if rule file goes
  in `files.rules[]`, `update-claude.sh` already handles it via existing
  smart-merge; if inline-seeded (precedent), explicit `[ ! -f ]` block needed.
- **`/learn` command** writes scoped rule files; `/audit-skip` is its
  cousin — same mental model, narrower data shape.

### Constraints That Cannot Be Bent

- **Markdown lint must pass**: MD040 (language fences), MD031/032 (blank
  lines), MD026 (no trailing punct on headings). Seed file authored to
  pass, AND output of `/audit-skip` (the appended block) must continue
  to pass.
- **No new runtime deps**: no `yq`, no `jq` for the rule file (jq is OK
  inside scripts that already require it for Keychain/manifest, but the
  rule file format must not require it).
- **Slash commands are markdown, not scripts**: `commands/audit-skip.md`
  and `commands/audit-restore.md` describe steps Claude executes via
  Bash/Edit. There is no `scripts/audit-skip.sh` runner.

</code_context>

<specifics>
## Specific Ideas

- Heading separator: U+2014 em-dash (`—`), not hyphen (`-`) or en-dash (`–`).
  Matches the visual weight of file headers in the rest of `.planning/`.
- Field labels in the entry block: bold-cased `**Date:**`, `**Council:**`,
  `**Reason:**` — not lowercase, not unbolded. Markdown parsers see them
  as definition-list-equivalent prose.
- Council values use lowercase snake_case (`council_confirmed_fp` not
  `CouncilConfirmedFP`) — matches existing PROJECT.md state values
  (`complement-sp`, `complement-full`, `synthesized_from_filesystem`).
- Date format: `YYYY-MM-DD` (no time). Matches `manifest.json:updated:`
  and CHANGELOG date convention.

</specifics>

<deferred>
## Deferred Ideas

- **Batch import from a Phase 14 audit report**: a hypothetical
  `/audit-skip --from-report <path>` that reads council `FALSE_POSITIVE`
  verdicts and creates entries en masse. Explicitly forbidden by
  REQ-COUNCIL-05 ("audit never auto-writes exceptions on user's behalf").
  Stay out of scope.
- **Cross-repo exception sync**: deferred to a later milestone per the
  v4.2 REQUIREMENTS.md "Out of Scope" section.
- **Sentry/Linear ticket creation per REAL council finding**: deferred to
  post-v4.2 per REQUIREMENTS.md.
- **A `--no-council` flag on `/audit`**: forbidden in v4.2; revisit in v4.3
  if pain points emerge.

</deferred>

---

*Phase: 13-foundation-fp-allowlist-skip-restore-commands*
*Context gathered: 2026-04-25*
