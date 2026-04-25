# Code Review — Next.js Template

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

## Goal

Comprehensive code review of a Next.js application. Act as a Senior Tech Lead.

> **Warning: Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for conducting code review — works better with code analysis.

---

## 0. QUICK CHECK (5 minutes)

| # | Check | Command | Expected |
| --- | ------- | --------- | ---------- |
| 1 | TypeScript | `npm run build` | No type errors |
| 2 | Lint | `npm run lint` | No errors |
| 3 | Tests | `npm test` | Pass |
| 4 | console.log | `grep -rn "console.log" app/ components/ --include="*.tsx"` | Minimal |

---

## 0.1 AUTO-CHECK SCRIPT

```bash
#!/bin/bash
# code-check.sh

echo "📝 Code Quality Check — Next.js..."

# 1. Build (includes TypeScript check)
npm run build > /dev/null 2>&1 && echo "✅ Build" || echo "❌ Build failed"

# 2. Lint
npm run lint > /dev/null 2>&1 && echo "✅ Lint" || echo "🟡 Lint has warnings"

# 3. console.log
CONSOLE=$(grep -rn "console.log" app/ components/ lib/ --include="*.ts" --include="*.tsx" 2>/dev/null | wc -l)
[ "$CONSOLE" -lt 10 ] && echo "✅ console.log: $CONSOLE" || echo "🟡 console.log: $CONSOLE (too many)"

# 4. 'use client' count
USE_CLIENT=$(grep -rn "'use client'" app/ components/ --include="*.tsx" 2>/dev/null | wc -l)
echo "ℹ️  Client components: $USE_CLIENT files"

# 5. Large files (>300 lines)
LARGE_FILES=$(find app components lib -name "*.ts" -o -name "*.tsx" | xargs wc -l 2>/dev/null | awk '$1 > 300 {print $2}' | wc -l)
[ "$LARGE_FILES" -eq 0 ] && echo "✅ No large files" || echo "🟡 Large files: $LARGE_FILES files >300 lines"

# 6. TODO/FIXME
TODOS=$(grep -rn "TODO\|FIXME" app/ components/ lib/ --include="*.ts" --include="*.tsx" 2>/dev/null | wc -l)
echo "ℹ️  TODO/FIXME: $TODOS comments"

echo "Done!"
```text

---

## 0.2 PROJECT SPECIFICS — [Project Name]

**Accepted decisions (no need to fix):**

- [Intentional architectural decisions]

**Key files for review:**

- `app/` — pages and API routes
- `components/` — UI components
- `lib/` — utilities and helpers

**Project patterns:**

- Server Components by default
- 'use client' only for interactivity
- Zod for validation
- API routes for mutations

---

## 0.3 SEVERITY LEVELS

| Level | Description | Action |
| ------- | ---------- | ---------- |
| CRITICAL | Bug, security issue, data loss | **BLOCKER** — fix now |
| HIGH | Serious logic issue | Fix before merge |
| MEDIUM | Code smell, maintainability | Fix in this PR |
| LOW | Style, nice-to-have | Can postpone |

---

## 1. SCOPE REVIEW

### 1.1 Define scope of review

```bash
git diff --name-only HEAD~5
git status --short
```text

- [ ] Which files are changed
- [ ] Which new files are created
- [ ] Relationship between changes

### 1.2 Categorization

- [ ] Pages (app/**/page.tsx)
- [ ] API Routes (app/api/**/route.ts)
- [ ] Components (components/*)
- [ ] Lib/Utils (lib/*)
- [ ] Config (next.config.ts, etc.)

---

## 2. ARCHITECTURE & STRUCTURE

### 2.1 Server Components vs Client Components

```tsx
// ❌ Bad — entire component client without necessity
'use client';

import { useState } from 'react';

export function ProjectPage({ projects }) {
  const [filter, setFilter] = useState('all');

  return (
    <div>
      <h1>Projects</h1>  {/* Static content */}
      <FilterButton onFilter={setFilter} />
      {projects.map(p => <ProjectCard key={p.id} project={p} />)}  {/* Static */}
    </div>
  );
}

// ✅ Good — minimal client boundary
// app/projects/page.tsx (Server Component)
export default async function ProjectsPage() {
  const projects = await getProjects();

  return (
    <div>
      <h1>Projects</h1>
      <ProjectFilters />  {/* Client Component */}
      <ProjectList projects={projects} />  {/* Server Component */}
    </div>
  );
}

// components/ProjectFilters.tsx
'use client';
export function ProjectFilters() {
  const [filter, setFilter] = useState('all');
  return <FilterButton onFilter={setFilter} />;
}
```text

- [ ] Client boundary as low as possible in tree
- [ ] 'use client' only where interactivity is really needed
- [ ] Data fetching in Server Components

### 2.2 API Route Structure

```typescript
// ❌ Bad — too much logic in route handler
// app/api/projects/route.ts
export async function POST(request: Request) {
  // 100 lines of business logic...
}

// ✅ Good — logic in separate files
// app/api/projects/route.ts
import { createProject } from '@/lib/services/projects';
import { CreateProjectSchema } from '@/lib/schemas/projects';

export async function POST(request: Request) {
  const body = await request.json();

  const parsed = CreateProjectSchema.safeParse(body);
  if (!parsed.success) {
    return Response.json({ error: parsed.error.flatten() }, { status: 400 });
  }

  const project = await createProject(parsed.data);
  return Response.json(project);
}
```text

- [ ] Route handlers are thin
- [ ] Business logic in lib/services/
- [ ] Schemas in lib/schemas/

### 2.3 File Structure

```text
app/
├── (auth)/
│   ├── login/
│   │   └── page.tsx
│   └── layout.tsx
├── dashboard/
│   └── page.tsx
├── api/
│   └── projects/
│       └── route.ts
├── layout.tsx
└── page.tsx

components/
├── ui/           # Reusable UI components
├── features/     # Feature-specific components
└── layouts/      # Layout components

lib/
├── services/     # Business logic
├── schemas/      # Zod schemas
├── db/           # Database utilities
└── utils/        # Helpers
```text

- [ ] Files in correct directories
- [ ] No God-components (> 300 lines)
- [ ] UI and business logic separated

---

## 3. CODE QUALITY

### 3.1 TypeScript

```typescript
// ❌ Bad — any, missing types
function process(data: any) {
  return data.something;
}

// ❌ Bad — implicit any in parameters
const handleClick = (e) => console.log(e);

// ✅ Good — full typing
interface ProcessInput {
  id: string;
  data: Record<string, unknown>;
}

function process(input: ProcessInput): ProcessResult {
  return { id: input.id, processed: true };
}

const handleClick = (e: React.MouseEvent<HTMLButtonElement>) => {
  console.log(e.currentTarget.id);
};
```text

- [ ] No `any` without explicit need
- [ ] All functions typed
- [ ] Interfaces/types defined

### 3.2 Naming Conventions

```typescript
// ❌ Bad
const d = await fetchData();
const res = processStuff(d);

// ✅ Good
const projects = await fetchProjects();
const processedProjects = processProjects(projects);
```text

- [ ] **Variables** — nouns, camelCase: `projectList`, `userData`
- [ ] **Functions** — verbs, camelCase: `getProjects()`, `processData()`
- [ ] **Components** — PascalCase: `ProjectCard`, `UserProfile`
- [ ] **Boolean** — is/has/can/should: `isLoading`, `hasError`

### 3.3 Component Structure

```tsx
// ❌ Bad — everything mixed
'use client';

import { useState, useEffect } from 'react';

export function ProjectCard({ project }) {
  const [loading, setLoading] = useState(false);

  // 200 lines of logic and rendering
}

// ✅ Good — separation into parts
// hooks/useProjectActions.ts
export function useProjectActions(projectId: string) {
  const [loading, setLoading] = useState(false);

  const deleteProject = async () => {
    setLoading(true);
    // ...
  };

  return { loading, deleteProject };
}

// components/ProjectCard.tsx
'use client';

import { useProjectActions } from '@/hooks/useProjectActions';

interface ProjectCardProps {
  project: Project;
}

export function ProjectCard({ project }: ProjectCardProps) {
  const { loading, deleteProject } = useProjectActions(project.id);

  return (
    <div>
      <h3>{project.name}</h3>
      <button onClick={deleteProject} disabled={loading}>
        Delete
      </button>
    </div>
  );
}
```text

- [ ] Logic extracted to custom hooks
- [ ] Props typed via interface
- [ ] Components < 150 lines

### 3.4 DRY (Don't Repeat Yourself)

```typescript
// ❌ Bad — duplication
// components/ProjectCard.tsx
const formatDate = (date: Date) => date.toLocaleDateString('en-US');

// components/UserCard.tsx
const formatDate = (date: Date) => date.toLocaleDateString('en-US');

// ✅ Good — shared utilities
// lib/utils/date.ts
export function formatDate(date: Date, locale = 'en-US'): string {
  return date.toLocaleDateString(locale);
}

// Usage
import { formatDate } from '@/lib/utils/date';
```text

- [ ] No duplicated code
- [ ] Shared utilities in lib/utils/

---

## 4. REACT/NEXT.JS BEST PRACTICES

### 4.1 Data Fetching

```tsx
// ❌ Bad — useEffect for initial data
'use client';

export function ProjectList() {
  const [projects, setProjects] = useState([]);

  useEffect(() => {
    fetch('/api/projects').then(r => r.json()).then(setProjects);
  }, []);

  return <div>{projects.map(...)}</div>;
}

// ✅ Good — Server Component
// app/projects/page.tsx
export default async function ProjectsPage() {
  const projects = await getProjects();  // Direct DB query
  return <ProjectList projects={projects} />;
}
```text

- [ ] Data fetching in Server Components
- [ ] No useEffect for initial data loading
- [ ] API routes for mutations

### 4.2 Error Handling

```tsx
// ❌ Bad — no error handling
export async function POST(request: Request) {
  const data = await request.json();
  const result = await createProject(data);
  return Response.json(result);
}

// ✅ Good — full handling
export async function POST(request: Request) {
  try {
    const body = await request.json();

    const parsed = CreateProjectSchema.safeParse(body);
    if (!parsed.success) {
      return Response.json(
        { error: 'Validation failed', details: parsed.error.flatten() },
        { status: 400 }
      );
    }

    const result = await createProject(parsed.data);
    return Response.json(result, { status: 201 });

  } catch (error) {
    console.error('Create project error:', error);

    if (error instanceof UniqueConstraintError) {
      return Response.json(
        { error: 'Project already exists' },
        { status: 409 }
      );
    }

    return Response.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
```text

- [ ] Try-catch in API routes
- [ ] Specific error responses
- [ ] Error logging

### 4.3 Loading & Error States

```tsx
// app/projects/loading.tsx
export default function Loading() {
  return <ProjectsSkeleton />;
}

// app/projects/error.tsx
'use client';

export default function Error({
  error,
  reset,
}: {
  error: Error;
  reset: () => void;
}) {
  return (
    <div>
      <h2>Something went wrong!</h2>
      <button onClick={reset}>Try again</button>
    </div>
  );
}
```text

- [ ] loading.tsx for Suspense
- [ ] error.tsx for error boundaries
- [ ] Skeleton components for loading states

---

## 5. SECURITY & PERFORMANCE QUICK CHECK

### 5.1 Security

- [ ] API routes check auth
- [ ] Input validated via Zod
- [ ] No SQL injection (parameterized queries)
- [ ] No secrets in client-side code
- [ ] No dangerouslySetInnerHTML with user content

### 5.2 Performance

- [ ] Server Components used where possible
- [ ] Heavy components — dynamic import
- [ ] Images via next/image
- [ ] No N+1 queries

---

## 6. SELF-CHECK (FP Recheck — 6-Step Procedure)
<!-- v42-splice: fp-recheck-section -->

## Procedure

For every candidate finding, execute these six steps in order. Produce a `## SELF-CHECK` block per finding (in your scratchpad — not the final report) before deciding whether to report or drop it. Each step has a fail-fast condition: if the finding fails any step, drop it and record the reason in `## Skipped (FP recheck)` (see schema below). Do not skip steps. Do not reorder.

1. **Read context** — Open the source file at `<path>:<line>` and load ±20 lines around the flagged line. Read the full surrounding function or block; do not reason from the rule label alone.
2. **Trace data flow** — Follow user input from its origin to the flagged sink. Name each hop (≤ 6 hops). If input never reaches the sink, the finding is a false positive — drop with `dropped_at_step: 2`.
3. **Check execution context** — Identify whether the code runs in test / production / background worker / service worker / build script / CI. Patterns that look exploitable in production may be required by the platform in another context (e.g. `eval` inside a build-time codegen script).
4. **Cross-reference exceptions** — Re-read `.claude/rules/audit-exceptions.md`. Look for entries on the same file or neighbouring lines that change the threat surface (e.g. an upstream sanitizer documented in another exception). Match key is byte-exact: same path, same line, same rule, same U+2014 em-dash separator.
5. **Apply platform-constraint rule** — If the pattern is required by the platform (MV3 service-worker MUST NOT use dynamic `importScripts`, OAuth `client_id` MUST be in `manifest.json`, CSP requires inline-style hashes, etc.), the finding is a design trade-off, not a vulnerability. Drop with the constraint named in the reason.
6. **Severity sanity check** — Re-rate severity using the actual exploit scenario, not the rule label. A theoretical XSS sink behind 3 unlikely preconditions and no PII is not CRITICAL. If you cannot describe a concrete attack path the user would care about, drop or downgrade.

If a finding survives all six steps, it proceeds to `## Findings` in the structured report.

---

## Skipped (FP recheck) Entry Format

Findings dropped at any step are listed in the report's `## Skipped (FP recheck)` table with these columns in order. The `one_line_reason` MUST be ≤ 100 characters and grounded in concrete tokens from the code — never `looks fine`, `trusted code`, or `out of scope`.

| path:line | rule | dropped_at_step | one_line_reason |
|-----------|------|-----------------|-----------------|
| `src/auth.ts:42` | `SEC-XSS` | 2 | `value flows through escapeHtml() at line 38 before reaching innerHTML` |
| `lib/utils.py:5` | `SEC-EVAL` | 5 | `eval is required by build-time codegen; never reached at runtime` |

`dropped_at_step` MUST be an integer in the range 1-6 matching the step where the finding was dropped.

---

## When a Finding Survives All Six Steps

Promote it to `## Findings` using the entry schema documented in `components/audit-output-format.md` (ID, Severity, Rule, Location, Claim, Code, Data flow, Why it is real, Suggested fix). The `Why it is real` field MUST cite concrete tokens visible in the verbatim code block — that is the artifact the Council reasons from in Phase 15.

---

## Anti-Patterns

These behaviors break the recheck and MUST NOT appear in any audit report:

- Dropping a finding without recording the step number and reason — every drop is auditable.
- Reasoning from the rule label instead of the code — the recheck exists because rule names are pattern-matched, not exploit-verified.
- Reusing a generic `one_line_reason` across multiple findings — every reason MUST cite tokens from the specific code block.
- Skipping Step 4 because `audit-exceptions.md` is absent — when the file is missing, Step 4 is a no-op (record `cross-ref skipped: no allowlist file present`) but the step itself MUST be acknowledged in the SELF-CHECK trace.

---

## 7. REPORT FORMAT

```markdown
# Code Review Report — [Project Name]
Date: [date]
Scope: [which files/commits reviewed]

## Summary

| Category | Issues | Critical |
|-----------|---------|-----------|
| Architecture | X | X |
| Code Quality | X | X |
| TypeScript | X | X |
| Security | X | X |
| Performance | X | X |

## CRITICAL Issues

| # | File | Line | Issue | Solution |
|---|------|--------|----------|---------|
| 1 | route.ts | 45 | No auth check | Add getServerSession |

## Code Suggestions

### 1. Add auth check

```typescript
// Before (app/api/projects/route.ts:10-15)
export async function POST(request: Request) {
  const data = await request.json();
  // ...
}

// After
import { getServerSession } from 'next-auth';

export async function POST(request: Request) {
  const session = await getServerSession(authOptions);
  if (!session) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 });
  }
  const data = await request.json();
  // ...
}
```text

## Good Practices Found

- [What's good]

```text

---

## 8. ACTIONS

## 7. OUTPUT FORMAT (Structured Report Schema — Phase 14)
<!-- v42-splice: output-format-section -->

## Report Path

```text
.claude/audits/<type>-<YYYY-MM-DD-HHMM>.md
```

- `<type>` is one of the 7 canonical slugs documented in the next section. Backward-compat aliases resolve to a canonical slug at dispatch time.
- Timestamp is local time, generated with `date '+%Y-%m-%d-%H%M'` (24-hour, no separator between hour and minute).
- The audit creates the directory with `mkdir -p .claude/audits` on first write.
- The toolkit does NOT auto-add `.claude/audits/` to `.gitignore` — let the user decide which audit reports to commit.

---

## Type Slug to Prompt File Map

| `/audit` argument | Report filename slug | Prompt loaded |
|-------------------|----------------------|---------------|
| `security` | `security` | `templates/<framework>/prompts/SECURITY_AUDIT.md` |
| `code-review` | `code-review` | `templates/<framework>/prompts/CODE_REVIEW.md` |
| `performance` | `performance` | `templates/<framework>/prompts/PERFORMANCE_AUDIT.md` |
| `deploy-checklist` | `deploy-checklist` | `templates/<framework>/prompts/DEPLOY_CHECKLIST.md` |
| `mysql-performance` | `mysql-performance` | `templates/<framework>/prompts/MYSQL_PERFORMANCE_AUDIT.md` |
| `postgres-performance` | `postgres-performance` | `templates/<framework>/prompts/POSTGRES_PERFORMANCE_AUDIT.md` |
| `design-review` | `design-review` | `templates/<framework>/prompts/DESIGN_REVIEW.md` |

Backward-compat aliases: `code` resolves to `code-review` and `deploy` resolves to `deploy-checklist` at dispatch time. The report filename ALWAYS uses the canonical slug, never the alias.

---

## YAML Frontmatter

Every report opens with a YAML frontmatter block containing exactly these 7 keys:

```yaml
---
audit_type: security
timestamp: "2026-04-25-1730"
commit_sha: a1b2c3d
total_findings: 3
skipped_allowlist: 1
skipped_fp_recheck: 2
council_pass: pending
---
```

- `audit_type` — one of the 7 canonical slugs from the type map.
- `timestamp` — quoted `YYYY-MM-DD-HHMM` (the same string used in the report filename).
- `commit_sha` — `git rev-parse --short HEAD` output, or the literal string `none` when the project is not a git repo.
- `total_findings` — integer count of entries in the `## Findings` section.
- `skipped_allowlist` — integer count of rows in the `## Skipped (allowlist)` table.
- `skipped_fp_recheck` — integer count of rows in the `## Skipped (FP recheck)` table.
- `council_pass` — starts at `pending`. Phase 15's `/council audit-review` mutates this to `passed`, `failed`, or `disputed` after collating per-finding verdicts.

---

## Section Order (Fixed)

After the YAML frontmatter, the report MUST contain these five H2 sections in this exact order:

1. `## Summary`
2. `## Findings`
3. `## Skipped (allowlist)`
4. `## Skipped (FP recheck)`
5. `## Council verdict`

Plus the report's title H1 (`# <Type Title> Audit — <project name>`) immediately after the closing `---` of the frontmatter and before `## Summary`.

Do NOT reorder. Do NOT introduce intermediate H2 sections. Render an empty section as the literal placeholder `_None_` — the allowlist case uses a longer placeholder shown verbatim in the Skipped (allowlist) section below. Phase 15 navigates by these literal H2 headings.

---

## Summary Section

The Summary table has columns `severity | count_reported | count_skipped_allowlist | count_skipped_fp_recheck`, with one row per severity (CRITICAL, HIGH, MEDIUM, LOW). The rubric is in `components/severity-levels.md` — do not redefine. INFO is NOT a reportable finding severity; informational observations belong in the audit's scratchpad, never in `## Findings`. See the Full Report Skeleton below for the verbatim layout.

---

## Finding Entry Schema (### Finding F-NNN)

Each surviving finding becomes an `### Finding F-NNN` H3 block. `F-NNN` is zero-padded to 3 digits and sequential per report (`F-001`, `F-002`, ...). The 9 fields appear in this exact order:

1. **ID** — the `F-NNN` identifier matching the H3 heading.
2. **Severity** — one of CRITICAL, HIGH, MEDIUM, LOW (per `components/severity-levels.md`).
3. **Rule** — the auditor's rule-id (e.g. `SEC-SQL-INJECTION`, `PERF-N+1`).
4. **Location** — `<path>:<start>-<end>` for a range, or `<path>:<line>` for a single point.
5. **Claim** — one-sentence statement of the alleged issue, ≤ 160 chars.
6. **Code** — verbatim ±10 lines around the flagged line, fenced with the language matching the source extension (see Verbatim Code Block section).
7. **Data flow** — markdown bullet list tracing input from origin to the flagged sink, ≤ 6 hops.
8. **Why it is real** — 2-4 sentences citing concrete tokens visible in the Code block. This field is what the Council reasons from in Phase 15.
9. **Suggested fix** — diff-style hunk or replacement snippet showing the corrected pattern.

See the Full Report Skeleton below for the verbatim entry template (a SQL-INJECTION example demonstrating all 9 fields).

The bullet labels (`**Severity:**`, `**Rule:**`, `**Location:**`, `**Claim:**`) and section labels (`**Code:**`, `**Data flow:**`, `**Why it is real:**`, `**Suggested fix:**`) are byte-exact — Phase 15's Council parser navigates the entry by them.

---

## Verbatim Code Block (AUDIT-03)

### Layout

```text
<!-- File: <path> Lines: <start>-<end> -->
[optional clamp note]
[fenced code block here with <lang> from the Extension Map]
```

`<lang>` is the language fence selected per the Extension to Language Fence Map below. `start = max(1, L - 10)` and `end = min(T, L + 10)` where `L` is the flagged line and `T` is the total line count of the file. The HTML range comment is the FIRST line above the fence; the clamp note (when present) is the SECOND line above the fence.

### Clamp Behaviour

When the ±10 range is clipped by the start or end of the file, emit a `<!-- Range clamped to file bounds (start-end) -->` note immediately above the fenced block. Example: flagged line 5 in an 8-line file → `start = max(1, 5-10) = 1`, `end = min(8, 5+10) = 8`, rendered range `1-8`, clamp note required.

### Extension to Language Fence Map

| Extension(s) | Fence |
|--------------|-------|
| `.ts`, `.tsx` | `ts` (or `tsx` for JSX-bearing files) |
| `.js`, `.jsx`, `.mjs`, `.cjs` | `js` |
| `.py` | `python` |
| `.sh`, `.bash`, `.zsh` | `bash` |
| `.rb` | `ruby` |
| `.go` | `go` |
| `.php` | `php` |
| `.md` | `markdown` |
| `.yml`, `.yaml` | `yaml` |
| `.json` | `json` |
| `.toml` | `toml` |
| `.html`, `.htm` | `html` |
| `.css`, `.scss`, `.sass` | `css` |
| `.sql` | `sql` |
| `.rs` | `rust` |
| `.java` | `java` |
| `.kt`, `.kts` | `kotlin` |
| `.swift` | `swift` |
| *unknown* | `text` |

The code block MUST be verbatim — no ellipses, no redaction, no `// ... rest of function` cuts. Council reasons from the actual code, not a paraphrase.

---

## Skipped (allowlist) Section

Columns: `ID | path:line | rule | council_status`. Empty-state placeholder is the literal string `_None — no` followed by a backtick-quoted `audit-exceptions.md` reference and `in this project_`. The verbatim layout is in the Full Report Skeleton below.

`council_status` is parsed from the matching entry's `**Council:**` bullet inside `audit-exceptions.md`. Allowed values: `unreviewed`, `council_confirmed_fp`, `disputed`. Use `sed '/^<!--/,/^-->/d'` (per `commands/audit-restore.md` post-13-05 fix) to strip HTML comment blocks before walking entries — the seed file ships with an HTML-commented example heading that would otherwise produce false matches. The `F-A001`..`F-ANNN` numbering is independent of `F-NNN` for surviving findings.

---

## Skipped (FP recheck) Section

Columns: `path:line | rule | dropped_at_step | one_line_reason`. Empty-state placeholder: `_None_`. The verbatim layout is in the Full Report Skeleton below.

`dropped_at_step` MUST be an integer in 1-6 matching the FP-recheck step where the finding was dropped (see `components/audit-fp-recheck.md`). `one_line_reason` MUST be ≤ 100 chars and reference concrete tokens visible in the source — never `looks fine`, `trusted code`, or `out of scope`.

---

## Council Verdict Slot (handoff to Phase 15)

The audit writes this section as a literal placeholder. Phase 15's `/council audit-review` mutates it in place after collating Gemini + ChatGPT verdicts.

```markdown
## Council verdict

_pending — run /council audit-review_
```

Byte-exact constraints: U+2014 em-dash (literal `—`, not hyphen-minus, not en-dash); single-underscore italic (`_..._`), no asterisks; no backticks, no bold, no code fence, no trailing whitespace. DO NOT REFORMAT — Phase 15 greps for this exact byte sequence to locate the slot before rewriting it.

---

## Full Report Skeleton

<output_format>

```text
---
audit_type: security
timestamp: "2026-04-25-1730"
commit_sha: a1b2c3d
total_findings: 1
skipped_allowlist: 1
skipped_fp_recheck: 1
council_pass: pending
---

# Security Audit — claude-code-toolkit

## Summary

| severity | count_reported | count_skipped_allowlist | count_skipped_fp_recheck |
|----------|----------------|-------------------------|--------------------------|
| HIGH | 1 | 1 | 1 |

## Findings

### Finding F-001

- **Severity:** HIGH
- **Rule:** SEC-SQL-INJECTION
- **Location:** src/users.ts:42
- **Claim:** User-supplied id flows into a string-concatenated SQL query without parameterization.

**Code:**

[fenced code block here — verbatim ±10 lines around src/users.ts:42, ts language fence]

**Data flow:**

- `req.params.id` arrives from the HTTP route handler.
- Passed unchanged into `db.query()`.
- No parameterized binding between origin and sink.

**Why it is real:**

The literal `db.query("SELECT * FROM users WHERE id=" + req.params.id)` concatenates an Express request parameter directly into the SQL string. The route is public, so an attacker can supply a malicious id and reach the sink unauthenticated.

**Suggested fix:**

[fenced code block here — replacement using parameterized query]

## Skipped (allowlist)

| ID | path:line | rule | council_status |
|----|-----------|------|----------------|
| F-A001 | lib/utils.py:5 | SEC-EVAL | unreviewed |

## Skipped (FP recheck)

| path:line | rule | dropped_at_step | one_line_reason |
|-----------|------|-----------------|-----------------|
| src/legacy.js:14 | SEC-EVAL | 3 | eval guarded by isBuildTime(); never reached at runtime |

## Council verdict

_pending — run /council audit-review_
```

</output_format>

1. **Run Quick Check** — 5 minutes
2. **Define scope** — which files to review
3. **Go through categories** — Architecture, Code Quality, Security
4. **Self-check** — filter out false positives
5. **Prioritize** — Critical → Low
6. **Show fixes** — specific code before/after

Start code review. Show scope and summary first.

## Council Handoff
<!-- v42-splice: council-handoff -->

When the structured report is complete, hand it off to the Supreme Council for
peer review. See `commands/audit.md` Phase 5 (Council Pass — mandatory) for the
invocation: `/council audit-review --report <path>`. The Council runs in
audit-review mode (see `commands/council.md` `## Modes`). The Council verdict
slot in the report is pre-populated with the byte-exact placeholder
`_pending — run /council audit-review_` (U+2014 em-dash) and is overwritten by
the Council pass.
