---
name: diagnose-ci
description: Walk a failing CI run through a 7-step diagnosis loop — fetch the failure, classify the layer, isolate the offending change, reproduce locally, fix, verify, and learn. Designed for the case where CI fails on a PR and you need to triage without bouncing between browser tabs and terminal.
---

# /diagnose-ci — CI Failure Diagnosis Loop

## Purpose

When a PR's CI is red, you need a structured way to find the root cause without losing time to noise (flaky tests, cache misses, infra blips). This command walks the 7 most common CI failure layers in order of *increasing* effort to fix, so you stop at the cheapest layer that explains the failure.

The loop is designed to be runnable by a single Claude Code session: each step is a concrete action with concrete output, no "investigate further" hand-waving.

---

## Usage

```text
/diagnose-ci [<run-id> | <pr-number>]
```

- **`<run-id>`** — explicit GitHub Actions run ID. Use this when you already have the URL or `gh run list` output.
- **`<pr-number>`** — PR number. Resolves to the latest CI run on that PR's head SHA.
- **No argument** — picks the latest failed run on the current branch.

**Examples:**

- `/diagnose-ci` — diagnose the latest failure on the current branch.
- `/diagnose-ci 25636200176` — diagnose run ID 25636200176.
- `/diagnose-ci 94` — diagnose the latest failure on PR #94.

---

## When to Use

**Use this when:**

- A PR's CI just turned red and you want a triaged diagnosis before guessing.
- You're rebasing or squashing and want to confirm a specific job is to blame, not noise.
- Multiple jobs failed in one run and you want to know whether they share a root cause.
- You hit a pre-merge gate and need to ship a minimal fix, not refactor the whole pipeline.

**Do NOT use this when:**

- The CI is green. There is nothing to diagnose; this command will exit with no findings.
- You are designing a new pipeline. Use `/research` or read `components/github-actions-guide.md`.
- The failure is a well-known intermittent flake your team already has a runbook for. Run the runbook directly.

---

## The 7-Step Loop

The loop runs sequentially. Stop at the first step that explains *every* failed job.

### Step 1 — Fetch the failure surface

Goal: a list of `{job, step, conclusion, exit_code, log_tail}` for every failed job, not just the one that surfaced first.

Concrete action:

```bash
RUN_ID=<resolved-id>
gh run view "$RUN_ID" --log-failed 2>&1 | tail -200 > /tmp/ci-fail.log
gh run view "$RUN_ID" --json jobs --jq '
  .jobs[] | select(.conclusion == "failure") | {
    name: .name,
    failed_step: ([.steps[] | select(.conclusion == "failure")][0] // null) | .name,
    started: .startedAt,
    completed: .completedAt
  }
'
```

Expected output: 1+ failed jobs with the specific step name. **If the count is zero, the run actually passed and the failure is upstream of GitHub Actions** (e.g. the merge-queue, branch-protection, or a status check from a non-GHA provider). Stop and re-check.

### Step 2 — Classify the failure layer

Match the failure against these layers in order. Stop at the first match:

| Layer | Symptom | Cheapest fix |
|-------|---------|--------------|
| **Infrastructure** | `Failed to download action`, `runner lost connection`, `429 Too Many Requests`, `ENOTFOUND`, `getaddrinfo`, "context deadline exceeded" | Re-run the job once. If it fails again, file an infra ticket — no code change needed. |
| **Cache miss** | `Cache not found`, restore-key hit but post-restore script fails, `node_modules` re-built from scratch | Bump the cache key. Do not invalidate the entire cache — that hides the real issue. |
| **Pinned action drift** | Action was renamed, archived, or had a security advisory triggering forced upgrade | Pin to a SHA, not a tag. Update via Dependabot. |
| **Secret / permissions** | `403`, `Bad credentials`, `Resource not accessible by integration`, `permission denied (publickey)` | Check the workflow's `permissions:` block. Most "Resource not accessible" errors are missing `contents: write` or `pull-requests: write`. |
| **Test logic** | A specific test name appears in the log; assertion failure with a diff | Reproduce locally (Step 4). |
| **Build logic** | Compile error, type error, lint error, missing dependency at install step | Reproduce locally (Step 4). |
| **Environment drift** | Test passes locally but fails in CI; passes on macOS runner but fails on ubuntu (or vice versa); passes with one Node version but fails with another | Pin the runner OS + tool version. Add the failing matrix combo to your local pre-push hook. |

### Step 3 — Isolate the offending change

If the layer is **Test logic**, **Build logic**, or **Environment drift**, the failure was almost certainly introduced by a specific commit on this branch. Find it:

```bash
# Get the head SHA of the branch
HEAD_SHA=$(gh run view "$RUN_ID" --json headSha --jq '.headSha')

# Get the merge base with main
MAIN_SHA=$(git rev-parse origin/main)
BASE_SHA=$(git merge-base "$MAIN_SHA" "$HEAD_SHA")

# List commits between base and head
git log --oneline "$BASE_SHA..$HEAD_SHA"
```

Then for each suspect commit (start from the most recent), check whether reverting it locally makes the failing test pass. If you have many commits, `git bisect` against a one-line `npm test` (or equivalent) is faster than eyeballing.

**Time-box this step at 15 minutes.** If you can't isolate after 15 minutes of bisect, the failure is probably *not* a single-commit regression and Step 4 is the right move.

### Step 4 — Reproduce locally

A CI failure you cannot reproduce locally is a debugging black box. Get it on your machine:

```bash
# Run the exact same command the failed step ran
gh run view "$RUN_ID" --json jobs --jq '
  .jobs[] | select(.conclusion == "failure")
  | .steps[] | select(.conclusion == "failure")
  | .name
'

# Then either:
# (a) Run the same command locally
npm test -- --testNamePattern="<the failing test name>"

# (b) If the failure only repros in CI, run with -j 1 to remove parallelism
npm test -- --runInBand --testNamePattern="..."

# (c) If the failure is OS-specific, use act or a Docker runner
act -j <job-name>
```

If you cannot reproduce locally even with `--runInBand` and matching tool versions, the failure is **environment-dependent** (filesystem case, line endings, locale, timezone, parallelism, file-handle limits). Switch to Step 5.

### Step 5 — Diagnose environment dependency

Most environment-dependent CI failures fall into these buckets:

- **Filesystem case** — macOS is case-insensitive, Linux is case-sensitive. `import "./Foo"` works on Mac, fails on Linux.
- **Line endings** — Windows runners may produce CRLF. Snapshot tests with raw byte comparisons will fail.
- **Locale** — `LANG=en_US.UTF-8` on macOS vs `LANG=C` on Linux runners. String collation, month names, decimal separators all change.
- **Timezone** — `Asia/Tokyo` on Mac vs `UTC` on runner. Date math drifts by hours.
- **Parallelism** — Tests that share a DB / temp file / global will flake under `--maxWorkers > 1`.
- **File-handle / process limits** — Linux runners cap `ulimit -n` at 1024 by default. Tests that open many connections fail in CI but pass locally.

Concrete probe: run the failing test with `LANG=C TZ=UTC --runInBand` locally. If it now fails, you've found the environment dependency.

### Step 6 — Apply the minimal fix

The fix lives at the layer you stopped at in Step 2. **Do not climb the stack.**

- Test logic failure → fix the test or the code under test. Do not add a `--shard` flag to the workflow.
- Environment drift → pin the locale / TZ / runner OS. Do not rewrite the test.
- Cache miss → bump the cache key. Do not switch cache providers.
- Pinned action drift → re-pin to a SHA. Do not rewrite the workflow.

Commit the fix on the same branch. Push. Watch the same job re-run.

### Step 7 — Verify and learn

After the re-run is green:

1. **Verify all failed jobs are now green**, not just the one you focused on. A side-effect can mask another failure.
2. **Capture a one-line lesson** in `.claude/rules/lessons-learned.md` if the failure mode was non-obvious. Format: `<date> — <one-sentence symptom>. Root cause: <X>. Fix: <Y>.`
3. **Decide if the fix needs prevention**: should a pre-push hook, a pre-commit lint rule, or a new test catch this class of failure earlier? File a tracking issue if yes.

---

## What this command does NOT do

- It does not write the fix for you. Step 6 is a human (or focused subagent) decision — you have to read the code and apply the change.
- It does not trigger a re-run. After Step 6 you push manually.
- It does not handle non-GitHub CI providers (GitLab CI, CircleCI, Buildkite). The 7-step framework still applies but the `gh run` commands need substitution.
- It does not bypass branch protection. If a job is required and you can't fix it, the right move is to escalate, not to override.

---

## Output Format

When invoked, surface a structured report:

```markdown
# CI Diagnosis — Run <run-id>

## Step 1 — Failure surface

- Failed jobs: <count>
- <job-name> @ <step-name> — exit code <N>
- <job-name> @ <step-name> — exit code <N>

## Step 2 — Classified layer

**Layer:** <Infrastructure | Cache | Pinned-action | Secret | Test | Build | Environment>
**Reasoning:** <one sentence>

## Step 3 — Suspect commit

- HEAD: <sha> — <subject>
- <sha> — <subject>  ← suspected first failure
- <sha> — <subject>

## Step 4 — Reproduction

- Local repro command: `<command>`
- Result: <reproduced | not reproduced>

## Step 5 — Environment dependency (if Step 4 fails to reproduce)

- Probe: <command>
- Bucket: <case | line-endings | locale | tz | parallelism | ulimit>

## Step 6 — Recommended fix

- File: `<path>:<line>`
- Change: <one-line description>
- Reasoning: <why this layer, not a higher one>

## Step 7 — Verification + lesson

- Re-run command: `gh run rerun <run-id> --failed`
- Lesson to capture: <one-sentence lesson>, OR `none — already a known pattern`.
```

---

## Related Commands

- `/research` — Use this to investigate a failing test's history beyond CI (e.g. find similar test names that passed in the last 30 days).
- `/audit` — Use after a CI failure to check whether the underlying code has other latent issues.
- `/learn` — Save the lesson to `.claude/rules/lessons-learned.md` automatically.
