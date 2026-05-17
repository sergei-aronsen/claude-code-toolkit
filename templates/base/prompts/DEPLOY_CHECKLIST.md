# Deploy Checklist — Base Template

> **This is a deployment runbook, not an audit prompt.** Run it before
> every production deploy. The checklist produces a go/no-go decision
> and a rollback plan, not a structured findings report. The audit
> machinery (SELF-CHECK FP recheck, OUTPUT FORMAT report schema, Council
> handoff) is intentionally absent — those belong in `CODE_REVIEW.md`,
> `SECURITY_AUDIT.md`, and the per-stack performance audits, not here.

## Goal

Comprehensive pre-deploy verification. Act as a Senior DevOps Engineer.
For each section, mark every checkbox `[x]` with evidence (command run,
log link, screenshot reference, or a one-line note) before proceeding.
A `[ ]` left unchecked at the end of any phase blocks the deploy.

## Global n/a-justification rule (Wave-3 F-011)

A checkbox marked `n/a` MUST carry a one-line justification on the
same line or in the line below. The justification names **why** the
gate does not apply to this deploy (e.g., `n/a — frontend-only deploy,
no DB migration` for Phase 3, or `n/a — no auth/crypto code touched,
verified via grep in Phase 5.4 trigger block`). An unjustified `n/a`
is treated as `[ ]` (unchecked) and blocks the deploy at the next
phase-entry gate. Sections that allow `n/a` explicitly call out the
expected justification format; the global rule is the floor.

---

## 0.1 PROJECT SPECIFICS — [Project Name]

**Deployment target:**

- **Server**: [IP/hostname]
- **Path**: [/path/to/app]
- **URL**: [https://...]
- **Process manager**: [PM2/Supervisor/systemd]

**Database:**

- **Host**: [host]
- **Name**: [db_name]

**Important files:**

- `.env` — environment variables
- [Other important files]

**Strategy in use** (pick one and document):

- [ ] Single-machine sequential — full downtime window, simplest.
- [ ] Rolling restart — workers cycle one at a time, no downtime.
- [ ] Blue/green — full duplicate environment, instant cut-over.
- [ ] Canary — N% of traffic to new version first, then ramp.

The phases below assume single-machine sequential by default; for
rolling/blue-green/canary, the same gates apply per slice.

---

## 0.2 DEPLOY TYPES

| Type | When | Required phases | Note |
| ----- | ------- | --------- | ---- |
| Hotfix | Critical bug | Phases 0, 3 (if migration), 5 (if auth/crypto), 6, 7, 8 | Phase 5 cannot be skipped if patch touches auth/session/token/crypto code paths. |
| Minor | Small changes | Phases 0-3, 6-8 | Phase 4 only if env config changed. |
| Feature | New functionality | Phases 0-8 (full) | Phase 7.3 (load test) recommended if traffic-shape changes. |
| Major | Architectural changes | Phases 0-8 (full) + post-deploy comparison vs Phase 0a baseline | Always blue/green or canary; never single-machine sequential. |

---

## 0a. PRE-DEPLOY BASELINE

Capture **before** the deploy starts so post-deploy comparison has a
reference. Write the values into the deploy ticket.

- [ ] **Error rate** (rolling 5-min, all endpoints): \_\_\_\_ %
- [ ] **Latency p95** (top 5 endpoints): \_\_\_\_ ms each
- [ ] **GC pause time p99** (if applicable): \_\_\_\_ ms
- [ ] **DB connection pool utilization**: \_\_\_\_ %
- [ ] **Queue depth** (per queue): \_\_\_\_
- [ ] **Auth-failure rate** (if patch touches auth): \_\_\_\_ /min

These numbers feed Phase 7.4 (post-deploy comparison) and Phase 8
(rollback triggers). Without a baseline, post-deploy "looks fine" is
not a measurable claim.

---

## 1. CODE CLEANUP

### 1.1 Debug Code

- [ ] No console.log / dd() / dump()
- [ ] No debugger statements
- [ ] No TODO/FIXME in critical code

### 1.2 Commented Code

- [ ] No commented-out blocks
- [ ] No "temporary" code

### 1.3 Linter

- [ ] Linter passes (command actually run, not inferred)
- [ ] Type checker passes (command actually run, not inferred)
- [ ] No new warnings introduced

---

## 2. CODE QUALITY

### 2.1 Tests

- [ ] All tests pass on the deploy candidate commit (CI green)
- [ ] New code is covered by tests
- [ ] No `.skip`, `xfail`, or `it.only` in committed test files

### 2.2 Build

- [ ] Build succeeds in the deploy environment (not "works on my machine")
- [ ] No new warnings
- [ ] Bundle size within budget (if frontend)

### 2.3 Performance

- [ ] No N+1 queries introduced (run query log on smoke path)
- [ ] No new heavy queries (>100ms) without index plan
- [ ] Caching strategy chosen for new endpoints

---

## 3. DATABASE

### 3.1 Migrations

- [ ] Migrations have rollback
- [ ] NOT NULL columns have default (if PG: default is **immutable** —
  see `POSTGRES_PERFORMANCE_AUDIT.md` F-398 for volatile-default trap)
- [ ] Indexes added
- [ ] Dry run verified on a production-size dataset

### 3.2 Backward compatibility

- [ ] Running application code on the OLD schema **after** migration
  still works (forward-compatible window for rolling deploys)
- [ ] Running NEW application code on the OLD schema works (backward-
  compatible window — required if rollback ships old code against new
  schema). If neither direction is safe, this is a two-deploy migration:
  first deploy adds the column nullable, backfills, then the second
  deploy enforces NOT NULL and removes the old code path.
- [ ] No queries reference dropped columns / renamed columns / removed
  indexes during the deploy window.
- [ ] **Column-drop / rename ordering (mandatory if this deploy drops
  or renames a column):** code references to the affected column must
  have been removed in a **previous** deploy that shipped to production
  at least one full deploy cycle ago. Verify by grep against the
  deployed-image source tree (not local working tree): run
  `git log --oneline origin/main -n 20 -- <files-touching-the-column>`
  and confirm the `SELECT col` / `WHERE col` removal commit was
  released in a deploy strictly **before** this one. If the removal
  and the drop ship together, this is a **two-deploy migration** —
  abort and split.

### 3.3 Backup

- [ ] Backup created **before** migrations (not just "we have nightly
  backups" — a deploy-aligned snapshot)
- [ ] Backup verified for restorability (restore-test on staging if the
  migration is destructive)

### 3.4 Seeders

- [ ] Seeders DO NOT run in production
- [ ] No truncate without env check

---

## 4. ENVIRONMENT

### 4.1 Production Config

- [ ] APP_ENV=production
- [ ] DEBUG=false
- [ ] LOG_LEVEL not debug
- [ ] HTTPS required

### 4.2 Secrets

- [ ] All API keys — production versions
- [ ] Passwords strong and unique
- [ ] No secrets in code or in `.env.example`
- [ ] Secrets sourced from secret manager / environment, not committed
  files

### 4.3 Cache / Session / Queue Drivers

- [ ] Cache driver configured (not file in production unless single-host)
- [ ] Session driver configured (not file if multi-host)
- [ ] Queue driver configured (not sync in production)
- [ ] **Connectivity verified**: ping cache + session + queue endpoints
  from the deploy host before starting Phase 6 — a typo in
  `CACHE_HOST` is detected here, not after the deploy
- [ ] Queue depth pre-deploy < 80% capacity (giving headroom for the
  deploy-time backlog)

### 4.4 Feature Flags

- [ ] New features default OFF; explicit allow-list controls who sees them
- [ ] Flag-system reachability verified (the flag service responds and
  returns expected values for the deploy host)

---

## 5. SECURITY

### 5.1 Files

- [ ] `.env` not accessible via web
- [ ] `.git` not accessible via web
- [ ] Logs not accessible via web
- [ ] Backup files not in web-accessible paths

### 5.2 Permissions

- [ ] Correct directory permissions (least privilege)
- [ ] Owner correct (www-data/nginx)
- [ ] No world-writable files in app dir

### 5.3 Dependencies

- [ ] Vulnerability scan run (`npm audit` / `composer audit` /
  `pip-audit` / `go vuln check`) — **command actually executed**, not
  inferred from a pinned lock file
- [ ] No critical vulnerabilities
- [ ] No new transitive dependency from an unknown publisher

### 5.4 Auth / Crypto / Session changes (conditional)

If this deploy touches authentication, session handling, token issuance,
or cryptographic primitives, the next four boxes are mandatory. (For
non-auth deploys, mark "n/a" with a one-line justification per the
global n/a rule above.)

**Trigger grep (mandatory — run this to mechanically determine
whether 5.4 applies; do not eyeball the diff):**

```bash
git diff origin/main..HEAD -- \
  ':(glob)**/auth/**' \
  ':(glob)**/session/**' \
  ':(glob)**/middleware/**auth**' \
  ':(glob)**/security/**' \
  ':(glob)**/crypto/**' \
  ':(glob)**/jwt/**' \
  ':(glob)**/passport/**' \
| grep -E \
  '\b(login|logout|signup|signin|signout|register|password|reset_password|verify_email|mfa|2fa|otp|totp|webauthn|passkey|oauth|saml|sso|jwt|jwks|access_token|refresh_token|session|cookie|csrf|hmac|signature|encrypt|decrypt|hash_password|bcrypt|argon2|scrypt|pbkdf2|verify_signature)\b' \
  || echo 'NO AUTH/CRYPTO/SESSION CODE CHANGES DETECTED'
```

If the grep produces output → 5.4 is **mandatory** and `n/a` is
forbidden. If the grep prints `NO AUTH/CRYPTO/SESSION CODE CHANGES
DETECTED` → mark each 5.4 checkbox `n/a — grep clean per 5.4 trigger
block`. Treat unfamiliar matches as "yes" (false positives are cheaper
than false negatives in this gate).

- [ ] **Threat model updated** — link or paste the section from
  `.claude/rules/project-context.md` describing the new auth/crypto
  surface. Do not deploy a delta the threat model has not been updated
  to cover.
- [ ] **Auth-failure metrics armed** — login-failure rate, token-refresh
  failure rate, MFA-challenge failure rate visible in dashboards before
  the deploy starts (so a regression is observable in minutes, not
  hours).
- [ ] **Anomaly alerts armed** — anomaly thresholds (per-account login
  burst, geographic distribution shift, sudden permission-grant volume)
  active and routed to oncall.
- [ ] **Audit logs armed** — sign-in / sign-out / permission-change /
  token-issue events written to an append-only log accessible to
  incident response. Required for SOC 2 §CC7 / GDPR Art. 33.

### 5.5 CSRF / Rate-limit / Token expiry

- [ ] CSRF token generation and verification covered for new state-
  changing endpoints
- [ ] Rate limit configured for new auth endpoints (login, register,
  password-reset, API-key generation)
- [ ] Token expiry < session-fixation window (typically ≤ 30 minutes
  for access tokens; refresh-token policy documented)

---

## 6. DEPLOYMENT

> **Atomicity:** Steps within a phase run sequentially. If a step
> fails, **maintenance mode stays on** until Phase 8 (rollback) decides
> the recovery path. Do not auto-disable maintenance mode on partial
> success.

### 6.0 Phase 6 entry gate (mandatory)

Before any step in 6.1 runs, **every** prior phase must be in a clean
state. Treat this as a hard gate, not a vibe check:

- [ ] **Phase 0a baseline captured** — error rate, latency p95 (top 5
  endpoints), GC pause p99, DB pool utilization, queue depth recorded
  with timestamps in the deploy ticket. Empty cells = blocker.
- [ ] **Phases 1-5 fully checked** — every checkbox in `## 1. CODE
  CLEANUP`, `## 2. CODE QUALITY`, `## 3. DATABASE`, `## 4. ENVIRONMENT`,
  `## 5. SECURITY` is either `[x]` with evidence or `n/a` with a
  one-line justification per the global n/a rule. Run a literal grep
  against the deploy ticket: `grep -c '^- \[ \]'` must return 0
  outside of `## 6.`, `## 7.`, and `## 8.`.
- [ ] **Phase 5.4 trigger grep run** — output recorded in the deploy
  ticket. If grep produced auth/crypto matches, all four 5.4
  checkboxes are `[x]` with evidence (not `n/a`).
- [ ] **Deploy type honored** — the `## 0.2 DEPLOY TYPES` row for this
  deploy lists every phase that must be complete; confirm visually
  that the matching phases are all `[x]`. (Skipping phases the table
  marks `Phases 0-8 (full)` is grounds for abort.)
- [ ] **On-call decider named** — the human who will call rollback if
  Phase 7.4 / 8.2 triggers fire is named in the deploy ticket and
  paged-in **before** maintenance mode goes on. No anonymous deploys.

An unchecked entry-gate box blocks Phase 6.1. The gate is verified
once, immediately before 6.1 starts; it does not re-run between 6.1
/ 6.2 / 6.3 (atomicity guarantee from the callout above).

### 6.1 Pre-Deploy

```bash
1. Maintenance mode ON
2. Database backup (deploy-aligned snapshot, not "nightly")
3. Pull code (verify the SHA matches the CI-green commit)
4. Install dependencies (no network = abort; a half-installed deploy
   is worse than no deploy)
```

If any step 1-4 fails: maintenance stays ON, no migrations, no worker
restart, route to Phase 8.

### 6.2 Deploy

```bash
5. Run migrations (with --dry-run first if supported)
6. Clear caches
7. Rebuild caches (warm critical cache keys before traffic)
8. Restart workers (rolling, not all-at-once — see strategy in 0.1)
```

If step 5 fails: maintenance stays ON. Run the migration's rollback,
verify Phase 0a baseline metrics restored, then route to Phase 8.

If step 8 hangs > 60s per worker: do **not** force-kill. Investigate the
hung worker (`kill -QUIT <pid>` for Java/JS to dump state). A force-kill
can corrupt in-flight write transactions.

### 6.3 Post-Deploy

```bash
9. Verify a known-good page renders (smoke URL) — automated, not
   manual
10. Tail error logs for 60 seconds; abort to Phase 8 if error rate
    exceeds Phase 0a baseline by 2× or more
11. Disable maintenance mode (only after step 9 + 10 are CLEAN)
```

---

## 7. VERIFICATION

### 7.1 Smoke Tests (automated)

- [ ] Homepage 200
- [ ] Login flow end-to-end (HTTP request to confirmation page) —
  scripted, not "I clicked it"
- [ ] Top 3 critical user flows pass automated checks
- [ ] Health check endpoint returns expected payload (not just 200 — the
  body must contain DB-up, cache-up, queue-up signals)

### 7.2 Regression Suite

- [ ] Production smoke-test suite re-run post-deploy (the same suite
  CI ran, against production)
- [ ] If frontend deploy: visual-regression suite re-run post-deploy

### 7.3 Load / Traffic-Shape Validation (conditional)

If this deploy changes traffic shape (new endpoint, removed cache,
N+1 fix that releases pent-up DB load):

- [ ] Synthetic load run that simulates expected post-deploy traffic
  shape against staging or canary
- [ ] DB connection pool, cache hit rate, and worker queue depth observed
  under that load — within budget

### 7.4 Post-Deploy Comparison vs Phase 0a Baseline

7.4 gates the deploy as **green / warn / abort**. The bands here
must align with Phase 8.2 rollback triggers (gap closed in Wave-3
F-007 — the prior version's `+ 0.5%` (7.4) vs `+ 1pp` (8.2) left an
undefined window between them). Bands:

| Signal | Green (pass) | Warn (stay deployed, monitor) | Abort (Phase 8) |
| ------ | ------------ | ----------------------------- | --------------- |
| Error rate | ≤ baseline + 0.5pp | baseline + 0.5pp .. baseline + 1.0pp | > baseline + 1.0pp |
| Latency p95 (top 5 endpoints) | ≤ baseline × 1.2 | baseline × 1.2 .. baseline × 1.5 | > baseline × 1.5 |
| GC pause p99 | ≤ baseline × 1.5 | baseline × 1.5 .. baseline × 2.0 | > baseline × 2.0 |
| DB pool utilization | ≤ baseline + 10pp | baseline + 10pp .. baseline + 20pp | > baseline + 20pp |
| Queue depth | draining within 5 min | growing slowly, draining within 15 min | growing fast, not draining in 15 min |
| Auth-failure rate (if 5.4 triggered) | ≤ baseline + 10% | baseline + 10% .. + 25% | > baseline + 25% |

- [ ] All signals in **green** band for at least one rolling 5-minute
  window post-deploy. A signal in the **warn** band: stay deployed
  but oncall watches it until it recovers to green (mark deploy
  ticket "monitoring"). A signal in the **abort** band: route to
  Phase 8 immediately.
- [ ] No 5xx class new since Phase 0a baseline at > 10/min sustained
  for 5 minutes (this is the Phase 8.2 "new 5xx class" trigger
  surfaced here so 7.4 catches it before 8.2 does).

If any signal hits the **abort** band: route to Phase 8. Do **not**
wait for users to report regressions.

### 7.5 Feature Flag State

- [ ] All new features confirmed OFF by default
- [ ] Flag-flip path tested on a non-production user before announcing

---

## 8. ROLLBACK PLAN

### 8.1 Readiness

- [ ] Rollback script ready and tested (the script has been executed at
  least once on staging)
- [ ] Database backup available (verified in 3.3)
- [ ] Commit hash for rollback recorded in deploy ticket
- [ ] Rollback runbook link in deploy ticket — names the on-call
  decision-maker, the dashboards to watch, and the abort criteria

### 8.2 Triggers

Rollback when **any** trigger fires within the post-deploy window
(default 30 minutes; longer for canary):

| Signal | Threshold | Time window | Decider |
| ------- | ---------- | ----------- | ------- |
| Error rate | > Phase 0a baseline + 1pp | rolling 5 min | on-call |
| Latency p95 (top 5 endpoints) | > Phase 0a × 1.5 | rolling 5 min | on-call |
| Auth-failure rate (if Phase 5.4 triggered) | > Phase 0a + 25% | rolling 5 min | on-call + security oncall |
| Critical user-flow smoke test | failing | any single failure | on-call (immediate) |
| Database corruption | any signal: replication lag spike, foreign-key violation log entries, unexpected NULLs in a NOT NULL column | any | on-call + DBA (immediate) |
| New 5xx class not seen pre-deploy | > 10/min sustained 5 min | 5 min | on-call |

"Critical functionality" must be defined per project — list the
specific endpoints / user actions in `## 0.1 PROJECT SPECIFICS` so the
on-call decider does not improvise mid-incident.

### 8.3 Time Boundaries

- **Decision window** to abort: 5 minutes after the trigger fires.
  Beyond 5 minutes, switch from rollback to forward-fix unless the
  trigger is "database corruption" or "auth bypass".
- **Watch window** post-deploy: 30 minutes default, 2 hours for major
  schema or auth changes.
- **All-clear**: signed off by on-call and (if Phase 5.4 triggered)
  security on-call. Until then the deploy is "watching", not "done".

---

## Stack Specifics

The snippets below cover the minimum graceful-restart / migration /
verify primitives per stack. For operational runbook templates
(systemd unit, multi-stage Dockerfile, full deploy + rollback scripts,
Celery / Sidekiq introspection, pprof / hey load test), consult the
matching component:

| Stack | Component |
|-------|-----------|
| Go | `components/deploy-templates/go.md` |
| Python | `components/deploy-templates/python.md` |
| Rails | `components/deploy-templates/rails.md` |

### Laravel

```bash
# Pre-deploy
php artisan down --secret="recovery-token"

# Migrations
php artisan migrate --pretend  # dry run
php artisan migrate --force

# Caches
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Post-deploy
php artisan up
```

### Next.js

```bash
# Build
pnpm build

# Restart
pm2 reload ecosystem.config.js --update-env

# Verify
curl -f https://example.com/api/health
```

### Node.js (generic)

```bash
# Restart with zero-downtime (PM2)
pm2 reload <app>

# Or systemd (one-shot reload, watch state)
sudo systemctl reload <app>.service
sudo systemctl status <app>.service
```

### Python (gunicorn / uvicorn)

```bash
# Gracefully reload Gunicorn workers
kill -HUP $(cat /var/run/gunicorn.pid)

# Verify workers cycled
ps -ef | grep gunicorn | wc -l
```

### Go

```bash
# Drop-in replacement (systemd ExecReload sends SIGHUP if supported)
sudo systemctl reload <app>.service

# Verify build embedded the deploy-time SHA
curl -s https://example.com/version
```

### Rails

```bash
# Migrations
RAILS_ENV=production bin/rails db:migrate

# Asset precompile
RAILS_ENV=production bin/rails assets:precompile

# Restart Puma
bundle exec pumactl phased-restart
```
