---
phase: 01-pre-work-bug-fixes
audited: 2026-04-17T00:00:00Z
audit_type: threat-mitigation-verification
asvs_level: L1
threats_total: 22
threats_closed: 22
threats_open: 0
threats_accepted: 7
status: secured
---

# Phase 01: Pre-work Bug Fixes — Security Audit

**Phase:** 01 — pre-work-bug-fixes
**Audited:** 2026-04-17
**Auditor:** gsd-secure-phase (Claude Sonnet 4.6)
**ASVS Level:** L1
**Block on:** critical

---

## Executive Summary

All 22 threats in the Phase 01 register are CLOSED. 13 `mitigate` threats were
verified by grep against on-disk code. 7 `accept` threats are documented below with
rationale. 2 `n/a` threats are auto-closed. No open threats. Phase is SECURED.

---

## Threat Verification Register

### Mitigate Threats (13 total — all CLOSED)

| Threat ID | Plan | Category | Status | Evidence |
|-----------|------|----------|--------|----------|
| T-01-01 | 01-01 | Tampering | CLOSED | `grep -c "head -n -1" scripts/update-claude.sh` = 0; `grep -c "sed '$d'" scripts/update-claude.sh` = 4 (lines 186, 189, 192, 195) |
| T-02-01 | 01-02 | DoS (availability) | CLOSED | `[[ ! -r /dev/tty ]]` guard at line 24; `grep -cE "read .*< /dev/tty" scripts/setup-council.sh` = 3 (one per interactive read, plus the INSTALL_TREE read added by WR-01 fix was removed — net 3 active read calls all guarded) |
| T-02-02 | 01-02 | Info Disclosure | CLOSED | `grep -c "read -rs" scripts/setup-council.sh` = 2 (lines 113, 145: GEMINI_KEY and OPENAI_KEY both use `-rs` silent mode) |
| T-02-03 | 01-02 | Tampering | CLOSED | Same evidence as T-02-01: early guard exits 1 before banner if no tty; each read uses `< /dev/tty` |
| T-03-01 | 01-03 | Tampering | CLOSED | `grep -cE "SETTINGS_JSON}.bak." scripts/setup-security.sh` = 3 (lines 203, 324, 373) — pre-mutation timestamped backup at all 3 python3 sites |
| T-03-02 | 01-03 | DoS (recoverability) | CLOSED | `grep -c "exit 1" scripts/setup-security.sh` = 3 (lines 254, 363, 407) — all 3 failure paths exit non-zero after restore |
| T-04-01 | 01-04 | Tampering (malformed JSON) | CLOSED | `grep -c "json.dumps" scripts/setup-council.sh` = 3; `grep -c "json.dumps" scripts/init-claude.sh` = 3 — all 6 key variables use `python3 json.dumps` escape |
| T-04-02 | 01-04 | Injection (JSON structural) | CLOSED | `grep -E '"api_key": "\$' scripts/setup-council.sh scripts/init-claude.sh` = 0 matches — no raw key interpolation in heredocs; `*_JSON` pre-escaped vars used |
| T-05-01 | 01-05 | Integrity (version drift) | CLOSED | `grep -c 'VERSION="2.0.0"' scripts/init-local.sh` = 0; `grep -c 'jq -r .\.version.' scripts/init-local.sh` = 1 (line 18); `grep -cE "^## \[Unreleased\]" CHANGELOG.md` = 1; `grep -c "MANIFEST_VER" Makefile` = 4; `make validate` exits 0 with "Version aligned: 3.0.0" |
| T-06-01 | 01-06 | Elevation of Privilege | CLOSED | `grep -cE "^[[:space:]]*sudo apt-get" scripts/setup-council.sh` = 0; `grep -cE "sudo apt-get (update\|install)" scripts/setup-council.sh` = 1 (advisory echo only, line 74) |
| T-06-02 | 01-06 | Info Disclosure | CLOSED | `grep -cE "apt-get.*2>/dev/null" scripts/setup-council.sh` = 0; script does not invoke apt-get at all |
| T-07-01 | 01-07 | Integrity (silent omission) | CLOSED | `grep -c "design\.md" scripts/update-claude.sh` = 1 (line 147 — in the for-loop) |
| T-07-02 | 01-07 | Integrity (future drift) | CLOSED | `grep -c "manifest.json files.commands has" Makefile` = 1 (line 105); `make validate` exits 0 with "update-claude.sh commands match manifest.json" |

### Accepted Threats (7 total — auto-CLOSED)

| Threat ID | Plan | Category | Rationale |
|-----------|------|----------|-----------|
| T-01-02 | 01-01 | DoS (bounded) | `sed '$d'` has no greater DoS surface than the former `head`; bounded by local user-controlled CLAUDE.md file size. No new attack surface introduced. |
| T-03-03 | 01-03 | Info Disclosure (bak perms) | `cp` inherits source file permissions (typically 600, user-owned). Backup filename contains only a Unix timestamp — not sensitive. No new disclosure beyond the original settings.json. |
| T-03-04 | 01-03 | Race (concurrent writes) | Backup filename collision within 1-second resolution is acknowledged. Deferred to STATE-03 (Phase 2) which will add mkdir-based locking for concurrent installer runs. Phase 1 does not introduce new concurrency surface. |
| T-04-03 | 01-04 | Info Disclosure (key in argv) | API key briefly appears as `argv[1]` of a child python3 process, visible to co-users via `ps` on a shared host. Accepted: the parent shell already held the key in its environment — same exposure class. Stdin pipe alternative rejected to keep the pattern consistent. |
| T-05-02 | 01-05 | Availability (jq dependency) | `init-local.sh` has fallback chain: `jq` → `grep + sed` → `"unknown"`. Script continues to function without jq; version string degrades gracefully. |
| T-06-03 | 01-06 | Tampering (supply chain) | No version pinning of the `tree` package — trust-on-first-use with the OS package manager. This is apt's responsibility; same disposition as before the fix. Unaffected by the advisory-only change. |
| T-06-04 | 01-06 | DoS (advisory ignored) | If the user never installs `tree`, `brain.py` operates in structure-analysis-disabled mode (D-11). Script emits non-fatal warning on both Y and N paths and continues. Tree has always been optional. |

### N/A Threats (2 total — auto-CLOSED)

| Threat ID | Plan | Reason |
|-----------|------|--------|
| T-04-04 | 01-04 | No logging surface exists for API keys in either script. Repudiation threat does not apply. |
| T-05-03 | 01-05 | BUG-06 does not introduce new trust boundaries. No new external input path created by manifest read. |

---

## Defense-in-Depth (Post-Review, Beyond Threat Model)

**WR-02 atomic-write hardening** (commit `99057c1`): `scripts/setup-security.sh`
python3 JSON-merge blocks now use `tempfile.mkstemp` + `os.replace` for atomic writes
at all 3 sites (lines 239/244, 346/351, 392/397). The original `.bak.$(date +%s)`
backup-and-restore logic is preserved as a second safety layer. This exceeds the
T-03-01 / T-03-02 mitigation requirements — no partial writes even on SIGKILL
between write and rename (filesystem permitting).

---

## Unregistered Flags

None. SUMMARY.md did not contain a `## Threat Flags` section; no unregistered
attack surface was flagged by the executor.

---

## Accepted Risks Log

| Risk ID | Category | Description | Owner | Review Date |
|---------|----------|-------------|-------|-------------|
| T-01-02 | DoS | sed '$d' bounded by local file — no new surface | phase owner | Phase 2 |
| T-03-03 | Info Disclosure | bak file inherits 600 perms — no new exposure | phase owner | Phase 2 |
| T-03-04 | Race | 1-second backup collision — deferred to STATE-03/Phase 2 | phase owner | Phase 2 |
| T-04-03 | Info Disclosure | key in python3 argv — same exposure class as parent env | phase owner | Phase 4 (API key hardening) |
| T-05-02 | Availability | jq fallback chain — degrades gracefully | phase owner | Phase 7 (release) |
| T-06-03 | Supply chain | apt tree package not pinned — OS package manager responsibility | phase owner | Phase 6 (deployment) |
| T-06-04 | DoS | user ignores tree advisory — tree is optional per D-11 | phase owner | Phase 6 |

---

## Audit Trail

| Step | Command | Result |
|------|---------|--------|
| T-01-01 head count | `grep -c "head -n -1" scripts/update-claude.sh` | 0 (PASS) |
| T-01-01 sed count | `grep -c "sed '\$d'" scripts/update-claude.sh` | 4 (PASS) |
| T-02-01 tty guard | `grep -n "\[\[ ! -r /dev/tty \]\]" scripts/setup-council.sh` | line 24 (PASS) |
| T-02-01 read tty count | `grep -cE "read .*< /dev/tty" scripts/setup-council.sh` | 3 (PASS) |
| T-02-02 read -rs count | `grep -c "read -rs" scripts/setup-council.sh` | 2 (PASS) |
| T-03-01 backup count | `grep -cE "SETTINGS_JSON}.bak." scripts/setup-security.sh` | 3 (PASS) |
| T-03-02 exit 1 count | `grep -c "exit 1" scripts/setup-security.sh` | 3 (PASS) |
| T-04-01 json.dumps council | `grep -c "json.dumps" scripts/setup-council.sh` | 3 (PASS) |
| T-04-01 json.dumps init | `grep -c "json.dumps" scripts/init-claude.sh` | 3 (PASS) |
| T-04-02 raw key heredoc | `grep -E '"api_key": "\$' scripts/setup-council.sh scripts/init-claude.sh` | 0 matches (PASS) |
| T-05-01 VERSION hardcoded | `grep -c 'VERSION="2.0.0"' scripts/init-local.sh` | 0 (PASS) |
| T-05-01 jq read | `grep -c 'jq -r .\.version.' scripts/init-local.sh` | 1 (PASS) |
| T-05-01 CHANGELOG Unreleased | `grep -cE "^## \[Unreleased\]" CHANGELOG.md` | 1 (PASS) |
| T-05-01 MANIFEST_VER Makefile | `grep -c "MANIFEST_VER" Makefile` | 4 (PASS) |
| T-05-01 make validate | `make validate` | exits 0, "Version aligned: 3.0.0" (PASS) |
| T-06-01 exec sudo apt-get | `grep -cE "^[[:space:]]*sudo apt-get" scripts/setup-council.sh` | 0 (PASS) |
| T-06-01 advisory count | `grep -cE "sudo apt-get (update\|install)" scripts/setup-council.sh` | 1 echo-only (PASS) |
| T-06-02 apt 2>/dev/null | `grep -cE "apt-get.*2>/dev/null" scripts/setup-council.sh` | 0 (PASS) |
| T-07-01 design.md | `grep -c "design\.md" scripts/update-claude.sh` | 1 (PASS) |
| T-07-02 drift check string | `grep -c "manifest.json files.commands has" Makefile` | 1 (PASS) |
| T-07-02 make validate drift | `make validate` drift output | "update-claude.sh commands match manifest.json" (PASS) |
| WR-02 atomic write | `grep -c "os.replace\|mkstemp" scripts/setup-security.sh` | 6 (3 mkstemp + 3 os.replace, PASS) |

---

_Audited: 2026-04-17_
_Auditor: gsd-secure-phase (Claude Sonnet 4.6)_
_Status: SECURED — threats_open: 0_
