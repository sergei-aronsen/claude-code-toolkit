# Infrastructure / Dependencies / CI Audit — claude-code-toolkit

Repo: `/Users/sergeiarutiunian/Projects/claude-code-toolkit`
Branch: `main` (clean)
Manifest version: 4.8.0 / Latest tag: v4.8.0 / Top CHANGELOG: 4.8.0
Date: 2026-04-30

---

## Severity Summary

| Severity | Count |
|---|---|
| Critical | 0 |
| High     | 1 |
| Medium   | 4 |
| Low      | 6 |
| Info     | 4 |

**Top 3 issues** (by impact):

1. **H-01** — Distribution chain pinned to mutable `main` ref with no toolkit-level SHA pin / checksum verification (only GSD third-party download has `TK_GSD_PIN_SHA256`).
2. **M-01** — CI workflow has no `concurrency:` cancel-in-progress group; redundant runs accumulate and waste GitHub minutes; PR force-pushes don't cancel old runs.
3. **M-02** — `.markdownlint.json` / `.markdownlint-cli2.jsonc` config drift: two files, three consumers (`make mdlint` uses v1, CI uses cli2, pre-commit uses v1 against `.markdownlint.json`); content currently matches but no enforcement keeps them aligned.

---

## Detailed Findings

### HIGH

#### H-01 — Distribution chain: mutable `main` pin, no toolkit-level SHA verification (90% confidence)

**Files**: `scripts/install.sh:34`, `scripts/init-claude.sh:18`, `scripts/update-claude.sh:76`,
`scripts/setup-security.sh:49`, `scripts/setup-council.sh:19`, `scripts/install-statusline.sh:35`,
`scripts/uninstall.sh:80`, `scripts/migrate-to-complement.sh:59`, plus all banner echos
in `scripts/init-local.sh:532`, `scripts/verify-install.sh:427-430`, `scripts/init-claude.sh:1237`.

All toolkit installers fetch from `https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/...`.
The ref `main` is mutable. Compromised maintainer credentials, a stolen GitHub PAT, a malicious
PR merged before notice — any of these inject code into every running `curl|bash` install pipeline
worldwide for the time it takes to revert.

Mitigations available but not used:

- `scripts/lib/bootstrap.sh:63-95` already implements the right pattern for the GSD third-party
  download (`TK_GSD_PIN_SHA256` env var, `sha256sum`/`shasum` fallback, fail-closed on mismatch).
- The toolkit's own download surface (15+ `curl -sSLf "$REPO_URL/..."` calls in `init-claude.sh`,
  `install.sh`, `update-claude.sh`) is **not** behind any SHA-pin or commit-pin variable.
- `TK_REPO_URL` is overridable but only swaps the host/branch; there's no `TK_TOOLKIT_REF`,
  `TK_TOOLKIT_SHA`, or per-file checksum file.

**Recommendation**: introduce `TK_TOOLKIT_REF` (default `main`) so security-conscious users can
pin to a specific tag (`v4.8.0`) or commit SHA, then ship a `checksums.txt` per release containing
sha256 of every manifest path. The orchestrator can verify before sourcing.

---

### MEDIUM

#### M-01 — CI has no `concurrency:` cancel-in-progress group (95% confidence)

**File**: `.github/workflows/quality.yml`.

No `concurrency:` block. Every push to a PR branch starts a fresh workflow without cancelling
the previous one. With a 5-job matrix (shellcheck + markdownlint + validate-templates + 2× test-init-script
+ test-matrix-bats), every force-push wastes ~5 runner-minutes of duplicate work.

**Fix**: add at workflow top:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

#### M-02 — Markdownlint config drift between v1 (`.markdownlint.json`) and v2 (`.markdownlint-cli2.jsonc`) (80% confidence)

**Files**: `.markdownlint.json`, `.markdownlint-cli2.jsonc`, `Makefile:48` (uses v1),
`.github/workflows/quality.yml:33` (uses cli2 with `.markdownlint-cli2.jsonc`),
`.pre-commit-config.yaml:21` (uses v1 with `.markdownlint.json`).

Both files declare the same rule set today (default true; MD013/033/041/060 false; MD024 siblings_only;
MD029 ordered) but the `config:` block in `.markdownlint-cli2.jsonc` and the bare object in
`.markdownlint.json` are not validated against each other. A future rule tweak in one will silently
diverge and CI/local pre-commit/local make will start disagreeing.

**Fix**: add a `validate` Makefile step that diffs the rule subsets, OR consolidate to one config
referenced from a single source (cli2's `extends:` field can read the v1 file).

#### M-03 — CI workflow has no `timeout-minutes:` per job (75% confidence)

**File**: `.github/workflows/quality.yml`.

No `timeout-minutes:` declared on any of the 5 jobs. GitHub default is 360 minutes (6 hours).
A hung curl/test loop (test-matrix-bats runs 14+ bats tests) can pin a runner for hours.

**Fix**: add `timeout-minutes: 15` to every `jobs.<id>:` entry. test-matrix-bats may need 20.

#### M-04 — `templates/global/{statusline,rate-limit-probe}.sh` are macOS-BSD-only with no platform guard (80% confidence)

**Files**: `templates/global/statusline.sh:17`, `templates/global/rate-limit-probe.sh:16,28`.

Both scripts use `stat -f %m` (BSD only; GNU is `stat -c %Y`) and the install-statusline.sh
itself uses `security` (macOS Keychain). Comments acknowledge "macOS-only", but there's no early
`if [[ "$(uname)" != "Darwin" ]]; then exit 0; fi` guard. A Linux user who copies these into
`~/.claude/` (e.g. via cross-machine dotfiles sync) gets silent failure: `stat` returns empty,
`echo 0` fallback fires, the cache age becomes huge, the probe runs every invocation.

By contrast `scripts/lib/state.sh:24-29` does the right thing with a `uname == Darwin` branch.

**Fix**: either guard with `uname` at the top of `statusline.sh` and `rate-limit-probe.sh`, or
add the BSD/GNU branch like `state.sh`.

---

### LOW

#### L-01 — 6 of 7 `templates/*/settings.json` files lack the `$schema` URL (90% confidence)

**Files**: `templates/{laravel,nextjs,nodejs,python,go,rails}/settings.json`.

Only `templates/base/settings.json:2` declares `"$schema": "https://json.schemastore.org/claude-code-settings.json"`.
The 6 framework variants are missing it, so editors don't get auto-completion or schema validation.
JSON itself is valid in all 7.

**Fix**: add the same `"$schema":` line as the first key to each.

#### L-02 — `manifest.json` skills_marketplace entry list and FS list are identical, but no validator catches drift on add (60% confidence)

Comparison showed 22 entries in manifest match 22 directories on disk (the earlier line-count
mismatch was a `wc -l` artifact — `find ... -mindepth 1` returns 22, both are aligned).
`scripts/validate-manifest.py` exists and is run by `make validate`, so drift would likely be
caught. Status: currently aligned. Risk: future PR adds a new marketplace skill dir without a
manifest entry.

**Fix**: extend `scripts/validate-manifest.py` to assert every `templates/skills-marketplace/*/`
directory appears in `manifest.json::files.skills_marketplace[].path`. (May already do this —
worth verifying.)

#### L-03 — `gemini` CLI presence is checked but no minimum version enforced (60% confidence)

**Files**: `scripts/init-claude.sh:977`, `scripts/setup-council.sh:163`,
`scripts/lib/cli-recommendations.sh:42`, `scripts/lib/detect2.sh:54`.

Probes use `command -v gemini`. Council `brain.py` calls `gemini` CLI for plan validation but
doesn't `gemini --version`-check or document a minimum. If Google ships a breaking flag change
(they have, between v1 and v2), council calls silently break.

**Fix**: in `setup-council.sh`, run `gemini --version` and validate against a known-good prefix;
warn (not fail) if mismatched.

#### L-04 — `jq` minimum version not asserted; `--argjson` (1.5+), `--rawfile` (1.5+), `to_entries[]` patterns assumed (50% confidence)

**Files**: `scripts/lib/install.sh:51,124,290-293`, `scripts/lib/mcp.sh:80-88`.

Heavy `jq` use including `--argjson` (introduced jq 1.5, 2015) and chained `to_entries[]`. macOS
Sonoma+ ships `jq 1.7`; Ubuntu 22.04 ships `1.6`; Ubuntu 20.04 ships `1.6`. Risk is low for
modern systems but probe scripts (`install-statusline.sh:69`) only check presence, not version.

**Fix**: in `setup-security.sh:60` and `install-statusline.sh:69`, after the presence check,
parse `jq --version` and warn if `< 1.5`.

#### L-05 — Pre-commit `markdownlint-cli@v0.45.0` (Sep 2024) lags behind CI's `markdownlint-cli2-action@v23.1.0` (60% confidence)

**Files**: `.pre-commit-config.yaml:18`, `.github/workflows/quality.yml:32`.

Pre-commit runs the v1 cli (`markdownlint-cli@v0.45.0`) against `.markdownlint.json`. CI runs v2
(`markdownlint-cli2-action@v23.1.0`) against `.markdownlint-cli2.jsonc`. v1 receives security/bug
fixes more slowly. Some MD024/MD029 corner cases differ between v1 and v2.

**Fix**: either move pre-commit to `markdownlint-cli2` hook, or pin both consumers to v1 to keep
behavior identical.

#### L-06 — No `timeout-minutes:` and no `--max-time`/`--connect-timeout` for some `curl` calls in init-claude.sh (40% confidence)

**File**: `scripts/init-claude.sh` — early `curl -sSLf "$REPO_URL/scripts/detect.sh" -o ...`
calls don't use the `_tk_curl_safe` wrapper that `install.sh:134-139` defines. A hung TCP socket
during `init-claude.sh` will not auto-expire (curl default is no timeout).

**Fix**: factor `_tk_curl_safe` to a shared helper or duplicate `--max-time 60 --connect-timeout 10
--retry 2` flags into `init-claude.sh`'s curl calls. Already partially done in `bootstrap.sh:67`.

---

### INFO (positive findings, worth recording)

#### I-01 — All 8 GitHub Action `uses:` lines are SHA-pinned with comments (verified)

```text
actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5  # v4    (×5 occurrences)
ludeeus/action-shellcheck@00cae500b08a931fb5698e11e79bfbd38e612a38  # v2.0.0
DavidAnson/markdownlint-cli2-action@6b51ade7a9e4a75a7ad929842dd298a3804ebe8b  # v23.1.0
bats-core/bats-action@77d6fb60505b4d0d1d73e48bd035b55074bbfb43  # v4.0.0
```

Workflow-level `permissions: contents: read` set (least privilege). No `pull_request_target`.
No `secrets.*` references. No `set -x` in workflow steps. Recent commit `82d5c5c` confirms
ongoing SHA-pin discipline.

#### I-02 — Pre-commit hooks all SHA-pinned with version comments (verified)

`shellcheck-precommit@2491238703a5d3415bb2b7ff11388bf775372f29` (v0.10.0),
`markdownlint-cli@192ad822316c3a22fb3d3cc8aa6eafa0b8488360` (v0.45.0),
`pre-commit-hooks@cef0300fd0fc4d2a87a85fa2093c6b283ea36f4b` (v5.0.0).

#### I-03 — Manifest version drift fully aligned (verified)

`make version-align` enforces `manifest.json::.version == CHANGELOG.md::top-header == init-local.sh --version`.
All three currently report 4.8.0. Memory file's claim of "manifest 3.0.0" was stale —
manifest is actually 4.8.0 dated 2026-04-29.

All 90+ manifest paths exist on disk (verified by walking `.files.*[].path` and stating each).
22 marketplace entries match 22 FS directories.

#### I-04 — eval-injection guards on third-party install paths (verified)

`scripts/lib/bootstrap.sh:108-115` rewrites the original eval-from-env design to use bash function
references; `scripts/lib/dispatch.sh:55` similarly hardened. Comments at `bootstrap.sh:36-43`
explicitly call out the original RCE shape. `TK_BOOTSTRAP_OVERRIDE_CMD` is gated behind `TK_TEST=1`.

The GSD third-party download has the most complete protection: optional `TK_GSD_PIN_SHA256`,
explicit URL print, --max-time / --retry on curl, fail-closed on shasum mismatch
(`scripts/lib/bootstrap.sh:63-95`).

---

## Cross-cutting observations (no severity)

- Library files in `scripts/lib/*.sh` deliberately omit `set -e` because they are sourced (comment
  in each: "sourced libraries must not alter caller error mode"). This is correct.
- `__pycache__/brain.cpython-314.pyc` exists locally but is gitignored (`.gitignore:21`). Confirmed
  not tracked.
- The 13 toolkit-only scripts (`init-claude.sh`, `update-claude.sh`, `setup-security.sh`,
  `setup-council.sh`, `verify-install.sh`, etc.) are intentionally absent from `manifest.json` —
  manifest is the *user-installed payload* surface, not the *installer surface*. By design.
- `scripts/council/brain.py` is curl-only / no pip deps (verified by reading shebang + imports
  pattern; no `requirements.txt` exists). Good.

---

## Recommended action queue (priority order)

1. **H-01** — Add `TK_TOOLKIT_REF` env var support to all 8 installer scripts; ship `checksums.txt` per release. (~half day.)
2. **M-01** — Add `concurrency:` block to `quality.yml`. (~5 min.)
3. **M-03** — Add `timeout-minutes: 15` to every job. (~5 min.)
4. **M-04** — Add `uname == Darwin` guard to `templates/global/statusline.sh` and `rate-limit-probe.sh`. (~10 min.)
5. **M-02** — Consolidate or cross-validate the two markdownlint configs. (~30 min.)
6. **L-01** — Add `$schema` URL to 6 framework `settings.json` files. (~5 min.)
7. **L-04, L-03** — Add jq + gemini version probes. (~15 min.)

Items L-02, L-05, L-06 are nice-to-have hardening; defer to next maintenance window.
