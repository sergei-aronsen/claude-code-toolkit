# Code Review — Laravel Template

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

## Goal

Comprehensive code review of a Laravel application. Act as a Senior Tech Lead.

> **⚠️ Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for code review — works better with code analysis.

---

## 0. QUICK CHECK (5 minutes)

| # | Check | Command | Expected |
| --- | ------- | --------- | ---------- |
| 1 | PHP Syntax | `php -l app/**/*.php` | No errors |
| 2 | Pint (style) | `./vendor/bin/pint --test` | No changes |
| 3 | PHPStan | `./vendor/bin/phpstan analyse` | Level OK |
| 4 | Build | `npm run build` | Success |
| 5 | Tests | `php artisan test` | Pass |

---

## 0.1 AUTO-CHECK SCRIPT

```bash
#!/bin/bash
# code-check.sh

echo "📝 Code Quality Check..."

# 1. PHP Syntax
php -l app/**/*.php 2>&1 | grep -q "error" && echo "❌ PHP Syntax errors" || echo "✅ PHP Syntax"

# 2. Pint
./vendor/bin/pint --test > /dev/null 2>&1 && echo "✅ Pint" || echo "🟡 Pint: needs formatting"

# 3. Build
npm run build > /dev/null 2>&1 && echo "✅ Build" || echo "❌ Build failed"

# 4. God classes (>300 lines)
GOD_CLASSES=$(find app -name "*.php" -exec wc -l {} \; | awk '$1 > 300 {print $2}' | wc -l)
[ "$GOD_CLASSES" -eq 0 ] && echo "✅ No god classes" || echo "🟡 God classes: $GOD_CLASSES files >300 lines"

# 5. TODO/FIXME
TODOS=$(grep -rn "TODO\|FIXME" app/ resources/js/ --include="*.php" --include="*.vue" --include="*.js" 2>/dev/null | wc -l)
echo "ℹ️  TODO/FIXME: $TODOS comments"

# 6. dd() / dump() left in code
DD_CALLS=$(grep -rn "dd(\|dump(" app/ --include="*.php" 2>/dev/null | wc -l)
[ "$DD_CALLS" -eq 0 ] && echo "✅ No dd()/dump()" || echo "❌ dd()/dump(): $DD_CALLS calls found"

# 7. console.log in Vue
CONSOLE=$(grep -rn "console.log" resources/js/ --include="*.vue" --include="*.js" 2>/dev/null | wc -l)
[ "$CONSOLE" -lt 10 ] && echo "✅ console.log: $CONSOLE" || echo "🟡 console.log: $CONSOLE (too many)"

echo "Done!"
```text

---

## 0.2 PROJECT SPECIFICS — [Project Name]

**Accepted decisions (no need to fix):**

- [Conscious architectural decisions]

**Key files for review:**

- `app/Services/` — business logic
- `app/Http/Controllers/` — should be thin
- `resources/js/Pages/` — Inertia pages (if used)
- `app/Jobs/` — background tasks

**Project patterns:**

- FormRequest for validation
- Services for business logic
- Jobs for long operations

---

## 0.3 SEVERITY LEVELS

| Level | Description | Action |
| ------- | ---------- | ---------- |
| CRITICAL | Bug, security issue, data loss | **BLOCKER** — fix now |
| HIGH | Serious logic problem | Fix before merge |
| MEDIUM | Code smell, maintainability | Fix in this PR |
| LOW | Style, nice-to-have | Can be deferred |

---

## 1. SCOPE REVIEW

### 1.1 Define review scope

```bash
# Recent changes
git diff --name-only HEAD~5

# Uncommitted changes
git status --short
```text

- [ ] Which files changed
- [ ] Which new files created
- [ ] Relationship between changes

### 1.2 Categorization

- [ ] Controllers (app/Http/Controllers/*)
- [ ] Services (app/Services/*)
- [ ] Models (app/Models/*)
- [ ] Jobs (app/Jobs/*)
- [ ] Migrations (database/migrations/*)
- [ ] Config (config/*)
- [ ] Routes (routes/*)

---

## 2. ARCHITECTURE & STRUCTURE

### 2.1 Single Responsibility Principle

```php
// ❌ Bad — Controller does everything
class SiteController extends Controller
{
    public function store(Request $request)
    {
        // Validation here
        $validated = $request->validate([...]);

        // Business logic here
        $html = Http::get($validated['url'])->body();
        preg_match('/<title>(.*?)<\/title>/', $html, $matches);
        $title = $matches[1] ?? null;

        // Saving here
        $site = Site::create([...]);

        // Notification here
        Mail::to($request->user())->send(new SiteCreated($site));

        return redirect()->route('sites.show', $site);
    }
}

// ✅ Good — Controller only coordinates
class SiteController extends Controller
{
    public function store(StoreSiteRequest $request, SiteService $service)
    {
        $site = $service->create($request->validated());
        return redirect()->route('sites.show', $site);
    }
}
```text

- [ ] Controllers < 100 lines
- [ ] Controller methods < 20 lines
- [ ] Business logic in Services, not in Controllers
- [ ] Validation in FormRequest, not in Controller

### 2.2 Dependency Injection

```php
// ❌ Bad — hardcoded dependencies
class ParserService
{
    public function parse(string $url): array
    {
        $client = new GuzzleHttp\Client(); // Hardcoded
        $response = $client->get($url);
    }
}

// ✅ Good — DI via constructor
class ParserService
{
    public function __construct(
        private ClientInterface $client
    ) {}

    public function parse(string $url): array
    {
        $response = $this->client->get($url);
    }
}
```text

- [ ] Dependencies injected via constructor
- [ ] No `new ClassName()` inside methods (except DTO)
- [ ] No static service calls

### 2.3 Proper File Placement

```text
app/
├── Http/
│   ├── Controllers/        // Routing only
│   └── Requests/           // Validation
├── Services/               // Business logic
├── Models/                 // Eloquent only
├── Jobs/                   // Background tasks
├── DTOs/                   // Data Transfer Objects
└── Enums/                  // Enumerations
```text

- [ ] Files in correct directories
- [ ] No God-classes (> 300 lines)
- [ ] Logic extracted from Models

---

## 3. CODE QUALITY

### 3.1 Naming Conventions

```php
// ❌ Bad — unclear names
$d = Site::find($id);
$res = $this->proc($d);

// ✅ Good — descriptive names
$site = Site::find($siteId);
$parsedData = $this->parseContent($site);
```text

- [ ] **Variables** — nouns, camelCase: `$siteUrl`, `$parsedContent`
- [ ] **Methods** — verbs, camelCase: `getSite()`, `parseContent()`
- [ ] **Classes** — nouns, PascalCase: `SiteService`, `ParsedResult`
- [ ] **Boolean** — is/has/can/should: `$isActive`, `$hasLabels`

### 3.2 Method Length & Complexity

```php
// ❌ Bad — long method with deep nesting
public function process(array $data): array
{
    foreach ($data as $item) {
        if ($item['type'] === 'site') {
            if ($item['status'] === 'active') {
                if (!empty($item['url'])) {
                    // deep nesting...
                }
            }
        }
    }
}

// ✅ Good — split into methods, early returns
public function process(array $data): array
{
    return collect($data)
        ->filter(fn($item) => $this->shouldProcess($item))
        ->mapWithKeys(fn($item) => $this->processItem($item))
        ->filter()
        ->toArray();
}

private function shouldProcess(array $item): bool
{
    return $item['type'] === 'site'
        && $item['status'] === 'active'
        && !empty($item['url']);
}
```text

- [ ] Methods < 20 lines (ideally < 10)
- [ ] Nesting < 3 levels
- [ ] Early returns are used

### 3.3 DRY (Don't Repeat Yourself)

```php
// ❌ Bad — duplication
$active = Site::where('status', 'active')
    ->where('user_id', auth()->id())
    ->orderBy('created_at', 'desc')
    ->get();

$pending = Site::where('status', 'pending')
    ->where('user_id', auth()->id())
    ->orderBy('created_at', 'desc')
    ->get();

// ✅ Good — scope in model
class Site extends Model
{
    public function scopeForUser($query, ?User $user = null)
    {
        return $query->where('user_id', ($user ?? auth()->user())->id);
    }

    public function scopeStatus($query, string $status)
    {
        return $query->where('status', $status);
    }
}

// Usage
$active = Site::forUser()->status('active')->latest()->get();
```text

- [ ] No copy-paste code
- [ ] Repeated queries extracted to scopes

### 3.4 Type Safety

```php
// ❌ Bad — no typing
function process($data) {
    $result = [];
}

// ✅ Good — full typing
declare(strict_types=1);

public function process(array $sites, ?ParserOptions $options = null): ProcessedResult
{
}
```text

- [ ] All methods have return type
- [ ] Parameters are typed
- [ ] Nullable types explicitly specified (`?string`, `?int`)

---

## 4. LARAVEL BEST PRACTICES

### 4.1 Eloquent Usage

```php
// ❌ Bad
$site = Site::where('id', $id)->first();
$sites = Site::all()->where('status', 'active');
$count = Site::get()->count();

// ✅ Good
$site = Site::find($id);
$sites = Site::where('status', 'active')->get();
$count = Site::count();
```text

- [ ] Using `find()` instead of `where('id', $id)->first()`
- [ ] Using `findOrFail()` when record must exist
- [ ] Filtering in Query Builder, not in Collection

### 4.2 Request Validation

```php
// ❌ Bad — validation in controller
public function store(Request $request)
{
    $request->validate([
        'url' => 'required|url|max:255',
    ]);
}

// ✅ Good — FormRequest
class StoreSiteRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'url' => ['required', 'url', 'max:255'],
            'labels' => ['array'],
            'labels.*' => ['exists:labels,id'],
        ];
    }

    public function messages(): array
    {
        return [
            'url.required' => 'Site URL is required',
        ];
    }
}
```text

- [ ] Validation in FormRequest classes
- [ ] Custom error messages
- [ ] `authorize()` checks access rights

### 4.3 Config & Environment

```php
// ❌ Bad — env() in code
class ScreenshotService
{
    public function capture(string $url): string
    {
        $apiKey = env('SCREENSHOT_API_KEY'); // Breaks config:cache!
    }
}

// ✅ Good — via config
// config/services.php
'screenshot' => [
    'api_key' => env('SCREENSHOT_API_KEY'),
],

// In service
$this->apiKey = config('services.screenshot.api_key');
```text

- [ ] `env()` only in config files
- [ ] All settings via `config()`

---

## 5. ERROR HANDLING

### 5.1 Exception Handling

```php
// ❌ Bad — suppressing errors
try {
    $result = $this->parse($url);
} catch (Exception $e) {
    // Silence...
}

// ✅ Good — specific exceptions with logging
try {
    $result = $this->parser->parse($url);
} catch (ConnectionException $e) {
    Log::warning('Failed to connect', [
        'url' => $url,
        'error' => $e->getMessage()
    ]);
    throw new SiteUnreachableException($url, $e);
}
```text

- [ ] Specific exception types
- [ ] Logging with context
- [ ] No empty catch blocks

### 5.2 User-Facing Errors

```php
// ❌ Bad — technical errors to user
return response()->json([
    'error' => $e->getMessage() // "SQLSTATE[23000]..."
], 500);

// ✅ Good — clear messages
if ($e instanceof SiteUnreachableException) {
    return back()->with('error', 'Could not connect to the site.');
}
```text

- [ ] User sees clear messages
- [ ] Technical details only in logs

---

## 6. SECURITY & PERFORMANCE CHECK

### 6.1 Security Quick Check

- [ ] No SQL injection (raw queries without bindings)
- [ ] No XSS (v-html with user data, {!! !!})
- [ ] No mass assignment vulnerabilities
- [ ] Authorization is checked
- [ ] No dd()/dump() in production code

### 6.2 Performance Quick Check

- [ ] No N+1 queries
- [ ] Eager loading is used
- [ ] Pagination for lists
- [ ] Heavy operations in queue

---

## 7. SELF-CHECK (FP Recheck — 6-Step Procedure)
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

## 8. REPORT FORMAT

```markdown
# Code Review Report — [Project Name]
Date: [date]
Scope: [which files/commits reviewed]

## Summary

| Category | Issues | Critical |
|-----------|---------|-----------|
| Architecture | X | X |
| Code Quality | X | X |
| Laravel | X | X |
| Security | X | X |
| Performance | X | X |

## CRITICAL Issues

| # | File | Line | Issue | Solution |
|---|------|--------|----------|---------|
| 1 | SiteController.php | 45 | 200 lines of business logic | Extract to SiteService |

## Code Suggestions

### 1. SiteController — extract logic

```php
// Before (app/Http/Controllers/SiteController.php:45-120)
public function store(Request $request) {
    // 75 lines...
}

// After
public function store(StoreSiteRequest $request, SiteService $service) {
    $site = $service->create($request->validated());
    return redirect()->route('sites.show', $site);
}
```text

## Good Practices Found

- [What's good]

```text

---

## 9. ACTIONS

## 8. OUTPUT FORMAT (Structured Report Schema — Phase 14)
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
2. **Define scope** — which files to check
3. **Go through categories** — Architecture, Code Quality, Laravel
4. **Self-check** — filter out false positives
5. **Prioritize** — Critical → High → Medium
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
