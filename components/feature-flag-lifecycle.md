# Feature Flag Lifecycle

> A flag is a debt instrument: it lets you ship faster *now* by promising to clean up *later*. The lifecycle below is what the cleanup looks like — it's not optional, and it's not a future-Claude problem.

---

## The Five Stages

Every feature flag passes through five stages. Skip a stage and the flag becomes either a load-bearing config (Stage 5 was skipped) or a permanent fork in the codebase (Stage 4 was skipped).

| Stage | Name | Purpose | Typical duration | Exit criterion |
|-------|------|---------|------------------|----------------|
| 1 | **Born** | Hide an in-progress change behind an off-by-default flag | Hours to days | Code paths exist for both states; flag is OFF in prod |
| 2 | **Ramped** | Enable the new path for a controlled subset (canary, %, allowlist) | Days to weeks | Confidence threshold met; both paths are still maintainable |
| 3 | **Defaulted** | Flip default ON; old path runs only behind explicit OFF override | Days to weeks | Zero opt-outs in last N days; no incidents that required flipping it back |
| 4 | **Deleted** | Remove the OFF code path, the flag plumbing, the config | Hours | No reference to the flag name remains in code, config, or telemetry |
| 5 | **Forgotten** | Audit / clean up: remove the flag from feature-flag service, delete metrics, remove from docs | Hours | Flag does not appear in your flag-management dashboard |

**Stage 4 → Stage 5 is the most-skipped transition.** A flag deleted from code but left in your flag service is a foot-gun: someone toggles it 6 months later expecting it to do something, and gets silently no-op'd.

---

## Stage 1 — Born

Add a flag when:

- The change has non-trivial blast radius and you want a kill switch.
- You're shipping behavior that is partially-implemented and want to merge often.
- You need to ship to a specific tenant / cohort first.

Do **not** add a flag when:

- The change is fully covered by existing tests and rolls back cleanly via `git revert`. A flag is added latency in your release process; don't pay it for nothing.
- You can't articulate the "kill switch trigger" in one sentence. If you don't know what would make you flip it back, you don't need the flag.

**Naming:** Use `<domain>_<verb>_<noun>` — `billing_v2_invoice_split`, `auth_passkey_enrollment`, `ingest_kafka_replace_kinesis`. Avoid temporal names (`new_pricing`, `2026_redesign`); they age out of meaning the moment they ship.

**Default:** Always OFF on creation. Even for "internal-only" features. The first deploy of the new code path should change the *binary*, not the *behavior*.

**Lifecycle metadata:** Capture at flag creation:

- Owner (a person, not a team — teams reorg)
- Expected lifetime (concrete date — "Q2" is not a date, "2026-06-30" is)
- Stage 4 trigger (e.g. "after 14 days of 100% rollout with zero rollbacks")

If your flag service stores these as free-text, file an issue to make them required fields.

---

## Stage 2 — Ramped

Ramping is **not** "I'll set it to 50% and see." It is a sequenced rollout with explicit gates:

| Step | Cohort | Wait | Gate to next step |
|------|--------|------|-------------------|
| Internal | Your team's accounts | 1+ business day | No P0/P1 incidents; you actually exercise the new path |
| Beta | Opt-in tenants / power users | 3-7 days | Beta cohort error rate ≤ control cohort error rate ± noise band |
| 1% | Random 1% of prod traffic | 24 hours minimum | No new error signatures in the 1%; no pager events |
| 10% | 10% | 24-72 hours | Same as 1%; check user-visible metrics (latency, conversion) |
| 50% | 50% | 24-72 hours | Same |
| 100% | All traffic | 7+ days | Stage 3 trigger fires |

**Skip a step only if you have a written reason** ("the change is read-only and idempotent, so 1% → 100% is the same as 1% → 10% → 100% in terms of risk"). Document it in the rollout plan; do not just do it.

**Cohort selection:** *Random 1%* is not the same as *the first 1% of users alphabetically*. Bucket on a stable hash of the user/tenant ID, not on a list. Otherwise the same 1% sees every flag and your experiment population is poisoned.

---

## Stage 3 — Defaulted

The new path is now the default. The old path runs only when something explicitly sets the flag to OFF.

**Zero opt-outs check:** before flipping to defaulted, query your flag service for:

- Number of accounts with explicit OFF override
- When the most recent override was set
- Reasons (if your flag tooling captures notes)

If anyone has set an explicit OFF in the last 30 days, do *not* default. Find them, ask why, fix the underlying issue.

**Telemetry note:** at this stage, your code is still running both paths conditionally on the flag value. Latency / error metrics should now be tagged with `flag_state=on|off|defaulted`. The first time the `flag_state=off` series goes to zero for 7+ days, you have your trigger to move to Stage 4.

---

## Stage 4 — Deleted

Stage 4 has three substeps and they go in this order:

1. **Delete the OFF branch in code.** The `if (flagOn) { newPath } else { oldPath }` becomes just `newPath`. Remove dead imports, dead helpers, dead tests. Do not leave an `// TODO: remove old path` comment — the comment becomes load-bearing the moment a future engineer reads it as "this might come back."
2. **Delete the flag check.** Now that there's only one path, `if (flagOn) { newPath }` becomes `newPath`. Delete the flag read entirely.
3. **Delete the flag plumbing.** Config files, env vars, helm values, IaC parameters, fixture-test overrides. Grep for the flag name and remove every reference *except* the flag-management service itself (Stage 5).

**Do not skip substep 3.** A flag whose plumbing remains is a flag that can be re-introduced as a regression: someone copy-pastes the env-var into a new config, the flag-service still has a record, and now you have a partially-resurrected flag with no code paths to honor it.

**Verification:**

```bash
# After Stage 4, this should return only Stage-5 references:
git grep -i 'billing_v2_invoice_split\|BILLING_V2_INVOICE_SPLIT' \
  | grep -v '^docs/cleanup-log.md' \
  | grep -v '^.flag-management/'
```

Empty output → Stage 4 complete.

---

## Stage 5 — Forgotten

Stage 5 is administrative cleanup, but it's the stage with the highest "weeks later" bug rate because nobody owns it.

Checklist:

- [ ] Remove the flag from your flag-management service (LaunchDarkly, Statsig, internal tool, etc.). If you cannot remove it (audit-trail policy), set it to **archived** + **default-off**.
- [ ] Remove flag-specific dashboards, alerts, and runbook pages.
- [ ] Remove flag-specific cost-tracking line items if you had any.
- [ ] Remove the flag from any "active experiments" doc your team maintains.
- [ ] Add a one-line entry to `docs/cleanup-log.md` with the flag name, deletion date, and outcome ("default ON, no incidents, no opt-outs in final 30 days").

The cleanup-log entry is what lets a future engineer search for the flag name and find a definitive "yes this was deleted, here's why" instead of a confused archaeology session.

---

## Anti-Patterns

These show up in real codebases. Recognize them.

### "Flag-as-config"

A flag that has been ON for >6 months with no plan to delete is a config value. Either:

- Move it to your config layer (env var, settings file, feature config) and delete the flag plumbing, or
- Schedule the Stage 4 cleanup.

Do not let it linger — flag services have query latency, audit overhead, and per-flag costs. Configs do not.

### "Flag-as-dependency"

A flag whose ON state requires another flag to also be ON, or whose OFF state breaks if a sibling flag is OFF. This means your flag has implicit coupling that no one captured.

Fix: at Stage 1, document the coupling. At Stage 3, replace the implicit coupling with explicit ordered evaluation in code. At Stage 4, the coupling disappears with the flags.

### "Flag-with-no-owner"

The owner left the company. The team reorg-ed. The flag predates your tenure. Now nobody knows whether to flip it.

Fix at the policy level: every flag without a current owner gets re-assigned at quarterly cleanup, or auto-archived after a grace period. **A flag without an owner is a flag without a Stage 4 plan**, and Stage 4 is mandatory.

### "Flag-as-dark-launch-with-no-exit"

A flag was created to dark-launch a feature, the feature was launched, the flag stayed at 100%, and the cleanup never happened. The OFF branch in code now contains 18 months of bit-rot.

Fix: at Stage 3 (defaulted), set a hard date for Stage 4. Put it on a calendar. Block the calendar with a meeting. Do the cleanup.

---

## Quick-Reference Decision Tree

```text
                  Is the change risky to ship without a kill switch?
                                |
                  ┌─────────────┴─────────────┐
                  │                           │
                 yes                          no
                  │                           │
                  ▼                           ▼
         Add a flag (Stage 1).      Just ship it. `git revert` is your kill switch.
                  │
                  ▼
         Does the change touch user-facing behavior?
                  │
        ┌─────────┴─────────┐
        │                   │
       yes                  no
        │                   │
        ▼                   ▼
Ramp via cohorts          Internal-only? Skip to 100% after internal QA.
(Stage 2 sequence)
        │
        ▼
Defaulted (Stage 3)
        │
        ▼
Stage 4 trigger fires? ── no ──→ Wait. Re-evaluate weekly.
        │
       yes
        │
        ▼
Delete code, plumbing, references (Stage 4)
        │
        ▼
Archive in flag service + cleanup log (Stage 5)
```

---

## Operational Checklist (per-flag)

Copy this into the flag's tracking ticket at Stage 1 and update through the lifecycle:

```markdown
## Feature Flag: <name>

- [ ] **Stage 1 — Born**
  - Owner: <person>
  - Expected lifetime: <YYYY-MM-DD>
  - Stage 4 trigger: <one-sentence condition>
  - Default: OFF
  - Created: <YYYY-MM-DD>
- [ ] **Stage 2 — Ramped**
  - Internal: <date completed>
  - Beta: <date completed>
  - 1%: <date completed>
  - 10%: <date completed>
  - 50%: <date completed>
  - 100%: <date completed>
- [ ] **Stage 3 — Defaulted**
  - Defaulted on: <YYYY-MM-DD>
  - Zero-opt-out check passed: <YYYY-MM-DD>
  - Stage 4 trigger met: <YYYY-MM-DD>
- [ ] **Stage 4 — Deleted**
  - OFF branch removed: <commit-sha>
  - Flag check removed: <commit-sha>
  - Plumbing removed: <commit-sha>
  - `git grep` clean: <YYYY-MM-DD>
- [ ] **Stage 5 — Forgotten**
  - Archived in flag service: <YYYY-MM-DD>
  - Dashboards / alerts removed: <YYYY-MM-DD>
  - Cleanup log entry: <PR link>
```

---

## Related Components

- `components/deployment-strategies.md` — flag-driven rollouts vs blue/green / canary at the deploy layer.
- `components/api-health-monitoring.md` — what to monitor *during* Stage 2 ramps to detect a need to flip back.
- `components/severity-levels.md` — how to score the impact of a Stage-2 incident that triggers a flip-back.
