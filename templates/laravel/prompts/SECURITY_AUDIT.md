# Security Audit — Laravel Template

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

## Goal

Comprehensive security audit of a Laravel application. Act as a Senior Security Engineer.

> **⚠️ Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for audits — works better with code analysis.

---

## 0. QUICK CHECK (5 minutes)

**Before full audit — go through these critical points:**

| # | Check | Command | Expected |
| --- | ------- | --------- | ---------- |
| 1 | Debug mode | `grep "APP_DEBUG" .env` | `false` in production |
| 2 | Secrets in code | `grep -rn "sk-\|password.*=.*['\"]" app/ --include="*.php"` | Empty |
| 3 | $guarded = [] | `grep -rn 'guarded.*=.*\[\]' app/Models/` | Empty |
| 4 | Raw SQL injection | `grep -rn 'DB::raw\|whereRaw' app/ --include="*.php"` | Check bindings |
| 5 | composer audit | `composer audit` | No vulnerabilities |
| 6 | APP_KEY set | `grep "APP_KEY=base64:" .env` | Key present |
| 7 | .env not public | `curl -s -o /dev/null -w "%{http_code}" http://yoursite.com/.env` | 403 or 404 |
| 8 | Dangerous functions | `grep -rn 'eval(\|extract(\|unserialize(' app/ --include="*.php"` | Empty |
| 9 | Command injection | `grep -rn 'exec(\|shell_exec(\|system(\|passthru(' app/ --include="*.php"` | Empty or escaped |

If all 9 = OK → Basic security level OK.

---

## 0.1 AUTO-CHECK SCRIPT

```bash
#!/bin/bash
# security-check.sh — run for automatic check

echo "🔐 Security Quick Check — Laravel..."

# 1. Debug mode
DEBUG=$(grep "APP_DEBUG=true" .env 2>/dev/null)
[ -z "$DEBUG" ] && echo "✅ Debug: APP_DEBUG=false" || echo "❌ Debug: APP_DEBUG=true in production!"

# 2. Hardcoded secrets
SECRETS=$(grep -rn "sk-\|api_key.*=.*['\"][a-zA-Z0-9]" app/ config/ --include="*.php" 2>/dev/null | grep -v ".env\|config(")
[ -z "$SECRETS" ] && echo "✅ Secrets: No hardcoded keys" || echo "❌ Secrets: Found hardcoded keys!"

# 3. Mass assignment vulnerability
GUARDED=$(grep -rn 'guarded\s*=\s*\[\]' app/Models/ 2>/dev/null)
[ -z "$GUARDED" ] && echo "✅ Models: No \$guarded = []" || echo "❌ Models: Found \$guarded = [] (mass assignment risk)"

# 4. Raw SQL patterns (need manual review)
RAW_SQL=$(grep -rn 'DB::raw\|whereRaw\|selectRaw\|orderByRaw' app/ --include="*.php" 2>/dev/null | wc -l)
[ "$RAW_SQL" -eq 0 ] && echo "✅ SQL: No raw queries" || echo "🟡 SQL: Found $RAW_SQL raw queries (verify bindings)"

# 5. CSRF exceptions
CSRF=$(grep -A5 'except' app/Http/Middleware/VerifyCsrfToken.php 2>/dev/null | grep -v "^--$")
echo "ℹ️  CSRF exceptions (verify webhooks only):"
echo "$CSRF"

# 6. composer audit
composer audit 2>/dev/null | grep -q "No security" && echo "✅ Composer: No vulnerabilities" || echo "❌ Composer: Run 'composer audit' for details"

# 7. npm audit
npm audit --production 2>/dev/null | grep -q "found 0" && echo "✅ NPM: No vulnerabilities" || echo "🟡 NPM: Run 'npm audit' for details"

# 8. APP_KEY
KEY=$(grep "APP_KEY=base64:" .env 2>/dev/null)
[ -n "$KEY" ] && echo "✅ APP_KEY: Set" || echo "❌ APP_KEY: Missing or not base64!"

# 9. Dangerous PHP functions
DANGEROUS=$(grep -rn 'eval(\|extract(\|unserialize(' app/ --include="*.php" 2>/dev/null | wc -l)
[ "$DANGEROUS" -eq 0 ] && echo "✅ No eval/extract/unserialize" || echo "❌ Found $DANGEROUS dangerous function calls!"

# 10. Command injection patterns
CMD_INJ=$(grep -rn 'exec(\|shell_exec(\|system(\|passthru(\|proc_open(' app/ --include="*.php" 2>/dev/null | wc -l)
[ "$CMD_INJ" -eq 0 ] && echo "✅ No shell execution" || echo "🟡 Found $CMD_INJ shell exec calls (verify escapeshellarg)"

# 11. env() outside config (broken with config:cache)
ENV_CALLS=$(grep -rn 'env(' app/ routes/ --include="*.php" 2>/dev/null | wc -l)
[ "$ENV_CALLS" -eq 0 ] && echo "✅ No env() outside config/" || echo "🟡 Found $ENV_CALLS env() calls outside config/"

echo "Done!"
```

---

## 0.2 PROJECT SPECIFICS — [Project Name]

**Fill before audit:**

**What is already implemented:**

- [ ] Authentication mechanism: [Laravel Sanctum / Breeze / Jetstream]
- [ ] Authorization: [Policies / Gates / Middleware]
- [ ] Input validation: [FormRequest classes]
- [ ] CSRF protection: [automatic in web routes]

**Public endpoints (by design):**

- `/api/health` — health check
- `/webhooks/*` — webhooks (check signature!)

---

## 0.3 SEVERITY LEVELS

| Level | Description | Action |
| ------- | ---------- | ---------- |
| 🔴 CRITICAL | Exploitable vulnerability: SQLi, RCE, auth bypass | **BLOCKER** — fix immediately |
| 🟠 HIGH | Serious vulnerability, requires auth or complex exploitation | Fix before deploy |
| 🟡 MEDIUM | Potential vulnerability, low risk | Fix in next sprint |
| 🔵 LOW | Best practice, defense in depth | Backlog |
| ⚪ INFO | Information, no action required | — |

---

## 1. SQL INJECTION

### 1.1 Raw Queries

```bash
# Find potentially dangerous patterns
grep -rn "DB::raw" app/
grep -rn "DB::select" app/
grep -rn "whereRaw\|selectRaw\|orderByRaw\|havingRaw" app/
```

```php
// ❌ CRITICAL — SQL Injection
DB::select("SELECT * FROM sites WHERE url = '$url'");
DB::raw("WHERE status = $status");
Site::whereRaw("url LIKE '%$search%'");
Site::orderByRaw($request->sort); // User controls ORDER BY!

// ✅ Safe — parameterized queries
DB::select("SELECT * FROM sites WHERE url = ?", [$url]);
Site::whereRaw("url LIKE ?", ["%{$search}%"]);
Site::orderByRaw("FIELD(status, ?, ?, ?)", ['active', 'pending', 'error']);

// ✅ Even better — Query Builder
Site::where('url', $url)->get();
Site::where('url', 'like', "%{$search}%")->get();
```

- [ ] All `DB::raw()` use bindings
- [ ] All `whereRaw()` use bindings
- [ ] User input is NEVER concatenated into SQL
- [ ] `orderBy`, `groupBy` don't accept raw user input

### 1.2 Dynamic Column/Table Names

```php
// ❌ CRITICAL — user controls column name
$column = $request->input('sort_by');
Site::orderBy($column)->get();

// ✅ Safe — whitelist
$allowed = ['created_at', 'url', 'title', 'status'];
$column = in_array($request->sort_by, $allowed) ? $request->sort_by : 'created_at';
Site::orderBy($column)->get();
```

- [ ] Column names validated via whitelist
- [ ] Table names never from user input

---

### 1.3 Validation Rule SQL Injection

```php
// ❌ CRITICAL — user input in ignore()
Rule::unique('users')->ignore($request->input('id'));
// Attacker sends: id=1) OR 1=1--

// ✅ Safe — only auth user ID
Rule::unique('users')->ignore(auth()->id());
// Or validate ID is integer first
```

- [ ] `Rule::unique()->ignore()` never uses raw request input
- [ ] `Rule::exists()->where()` doesn't accept unvalidated data

---

## 2. CROSS-SITE SCRIPTING (XSS)

### 2.1 Laravel Blade

```bash
# Find dangerous patterns
grep -rn "{!!" resources/views/
grep -rn "@php" resources/views/
```

```php
// ❌ CRITICAL — XSS
{!! $site->description !!}
{!! $userComment !!}

// ✅ Safe — auto-escaping
{{ $site->description }}

// ✅ If HTML needed — sanitization
{!! clean($site->description) !!}  // With HTML Purifier
{!! Str::markdown($site->description) !!}
```

- [ ] No `{!! !!}` with user data
- [ ] If `{!! !!}` is necessary — data is sanitized

### 2.2 Vue / Inertia (if used)

```bash
grep -rn "v-html" resources/js/
```

```vue
// ❌ CRITICAL — XSS
<div v-html="site.description"></div>

// ✅ Safe — text
<div>{{ site.description }}</div>

// ✅ If HTML needed — DOMPurify
import DOMPurify from 'dompurify'
<div v-html="DOMPurify.sanitize(site.description)"></div>
```

- [ ] No `v-html` with user-controlled data
- [ ] If `v-html` is necessary — DOMPurify is used

---

## 3. CSRF PROTECTION

### 3.1 Forms & Routes

```php
// Check VerifyCsrfToken middleware
// ❌ Bad — CSRF disabled
protected $except = [
    'api/*',        // Entire API without CSRF!
];

// ✅ Good — only webhooks
protected $except = [
    'webhooks/stripe',  // Only webhook with signature verification
];
```

- [ ] `VerifyCsrfToken::$except` contains only webhooks
- [ ] Webhooks verify signature
- [ ] No `withoutMiddleware('csrf')` on web routes

---

## 4. MASS ASSIGNMENT

### 4.1 Model Protection

```bash
grep -rn "guarded\s*=\s*\[\]" app/Models/
grep -rn "fillable" app/Models/
```

```php
// ❌ CRITICAL — everything allowed
class Site extends Model
{
    protected $guarded = [];  // Any field can be changed!
}

// ❌ Bad — sensitive fields in fillable
class User extends Model
{
    protected $fillable = [
        'name', 'email', 'password',
        'is_admin',     // DANGEROUS!
        'role',         // DANGEROUS!
    ];
}

// ✅ Good — only safe fields
class Site extends Model
{
    protected $fillable = [
        'url',
        'title',
        'description',
        'status',
    ];
}
```

- [ ] No `$guarded = []` in production models
- [ ] `$fillable` doesn't contain sensitive fields (role, is_admin, etc.)

### 4.2 Foreign Keys in $fillable

```php
// ❌ DANGEROUS — attacker can reassign ownership
class Post extends Model
{
    protected $fillable = [
        'title', 'body',
        'user_id',      // FK! Attacker changes post owner
        'category_id',  // FK! May access restricted categories
    ];
}

// ✅ Good — set FK explicitly in controller
class Post extends Model
{
    protected $fillable = ['title', 'body', 'category_id'];
}

// Controller:
$post = auth()->user()->posts()->create($request->validated());
```

- [ ] Foreign keys (`*_id`) not in `$fillable` unless intentional
- [ ] Owner relationships set via `auth()->user()->relation()->create()`

### 4.3 Controller Validation

```php
// ❌ Bad — passing entire request
Site::create($request->all());

// ✅ Good — only validated data
Site::create($request->validated());
```

- [ ] Using `$request->validated()` or `$request->only()`
- [ ] No `$request->all()` in create/update

---

## 5. AUTHENTICATION

### 5.1 Password Security

```php
// Check config/hashing.php
// ✅ Should be bcrypt or argon2
'driver' => 'bcrypt',
'bcrypt' => [
    'rounds' => 12,  // Minimum 10, recommended 12
],
```

- [ ] Passwords hashed via `Hash::make()` or cast
- [ ] Bcrypt rounds >= 10
- [ ] No plain text passwords in DB or logs

### 5.2 Session Security

```php
// config/session.php
return [
    'secure' => env('SESSION_SECURE_COOKIE', true),  // ✅ HTTPS only
    'http_only' => true,         // ✅ Not accessible from JS
    'same_site' => 'lax',        // ✅ CSRF protection
];
```

- [ ] `SESSION_SECURE_COOKIE=true` in production
- [ ] `http_only` = true
- [ ] `same_site` = 'lax' or 'strict'

### 5.3 Cookie Encryption

```php
// Check EncryptCookies middleware
// app/Http/Middleware/EncryptCookies.php
protected $except = [
    // ❌ Bad — sensitive cookies unencrypted
    'session_token',
    // ✅ OK — only analytics/tracking cookies
    'ga_cookie',
];
```

- [ ] `EncryptCookies::$except` contains only non-sensitive cookies
- [ ] Session cookie is encrypted (never in $except)

### 5.4 Session Timeout

```php
// config/session.php
'lifetime' => 120,          // ✅ 2 hours — reasonable
'expire_on_close' => false,

// ❌ Bad — session lives forever
'lifetime' => 525600,       // 1 year!
```

- [ ] `SESSION_LIFETIME` reasonable (< 480 minutes for web apps)
- [ ] `idle_in_transaction_session_timeout` set for database sessions

### 5.5 Rate Limiting

```php
// ❌ Bad — no rate limiting on login
Route::post('/login', [AuthController::class, 'login']);

// ✅ Good — throttle
Route::post('/login', [AuthController::class, 'login'])
    ->middleware('throttle:5,1');  // 5 attempts per minute
```

- [ ] Login endpoint has rate limiting
- [ ] Password reset has rate limiting
- [ ] API endpoints have rate limiting

---

## 6. AUTHORIZATION

### 6.1 Policy Implementation

```php
// ❌ CRITICAL — no owner check
public function update(Request $request, Site $site)
{
    $site->update($request->validated());  // Anyone can edit!
}

// ✅ Good — Policy
public function update(UpdateSiteRequest $request, Site $site)
{
    $this->authorize('update', $site);
    $site->update($request->validated());
}
```

- [ ] All update/delete operations check ownership
- [ ] Policies registered in AuthServiceProvider
- [ ] `$this->authorize()` used in controllers

---

## 7. FILE UPLOAD SECURITY

### 7.1 Validation

```php
// ❌ Bad — insufficient validation
$request->validate([
    'file' => 'required|file',  // Any file!
]);

// ✅ Good — strict validation
$request->validate([
    'file' => [
        'required',
        'file',
        'mimes:jpg,jpeg,png,pdf,csv,txt',  // Only allowed types
        'max:10240',                        // Maximum 10MB
    ],
]);
```

- [ ] All uploads validate `mimes`
- [ ] `max` size is set

### 7.2 Storage Security

```php
// ❌ CRITICAL — original filename
$path = $request->file('file')->storeAs('uploads', $request->file('file')->getClientOriginalName());
// Filename: "../../../config/app.php" = path traversal!

// ✅ Good — safe name
$path = $request->file('file')->store('uploads');  // Auto-generated name
```

- [ ] Never use `getClientOriginalName()` for storage
- [ ] Files stored with UUID/hash names
- [ ] No path traversal (`../`)

---

## 8. API SECURITY

### 8.1 API Response Filtering

```php
// ❌ Bad — returning entire model
return response()->json($site);  // Includes all fields!

// ✅ Good — Resource
return new SiteResource($site);
```

- [ ] API Resources are used
- [ ] Sensitive fields are not returned
- [ ] Models have `$hidden` for sensitive fields

### 8.2 CORS Configuration

```php
// config/cors.php
return [
    'allowed_origins' => [
        env('FRONTEND_URL'),
        // ❌ DO NOT use '*' in production!
    ],
    'supports_credentials' => true,
];
```

- [ ] `allowed_origins` — specific domains, not `*`

---

## 9. SENSITIVE DATA EXPOSURE

### 9.1 Environment Variables

- [ ] `.env` in `.gitignore`
- [ ] `.env.example` doesn't contain real keys
- [ ] Production credentials only on server

### 9.2 Debug Mode

```php
// ❌ CRITICAL in production
APP_DEBUG=true  // Shows stack traces with sensitive data!

// ✅ Production
APP_DEBUG=false
APP_ENV=production
```

- [ ] `APP_DEBUG=false` in production
- [ ] `APP_ENV=production`
- [ ] No `dd()`, `dump()` in production code

### 9.3 Error Messages

```php
// ❌ Bad — technical details to user
return back()->with('error', $e->getMessage());

// ✅ Good — generic messages
return back()->with('error', 'An error occurred. Please try again later.');
```

- [ ] User doesn't see stack traces
- [ ] User doesn't see SQL errors

---

### 9.4 APP_KEY Validation

```bash
# Must be set and base64 encoded
grep "APP_KEY=base64:" .env
```

- [ ] `APP_KEY` is set (not empty)
- [ ] `APP_KEY` is base64 encoded (`base64:...`)
- [ ] Different keys for each environment (dev/staging/prod)

### 9.5 .env Public Access

```bash
# Test from outside — must return 403/404
curl -s -o /dev/null -w "%{http_code}" https://yoursite.com/.env
```

- [ ] `.env` returns 403 or 404 from web
- [ ] Web server blocks dotfiles (`.env`, `.git`)

### 9.6 PHP.ini Security

```ini
; php.ini — secure settings
expose_php = Off              ; Don't reveal PHP version
allow_url_fopen = Off         ; Prevent remote file inclusion
allow_url_include = Off       ; CRITICAL — never On
display_errors = Off          ; No errors to users
display_startup_errors = Off
log_errors = On               ; Log instead of display
```

- [ ] `expose_php = Off`
- [ ] `allow_url_include = Off`
- [ ] `display_errors = Off` in production

### 9.7 File Permissions

```bash
# Check dangerous permissions
find storage/ -perm -0002 -type f  # World-writable files
stat -c "%a %n" .env               # .env should be 640 or 600
```

- [ ] `.env` is 640 or more restrictive
- [ ] `storage/` not world-writable (no 777)
- [ ] `bootstrap/cache/` writable only by web server

---

## 10. SECURITY HEADERS

### 10.1 Middleware

```php
// app/Http/Middleware/SecurityHeaders.php
class SecurityHeaders
{
    public function handle($request, $next)
    {
        $response = $next($request);

        $response->headers->set('X-Content-Type-Options', 'nosniff');
        $response->headers->set('X-Frame-Options', 'DENY');
        $response->headers->set('X-XSS-Protection', '1; mode=block');
        $response->headers->set('Referrer-Policy', 'strict-origin-when-cross-origin');

        return $response;
    }
}
```

- [ ] Security headers middleware added
- [ ] X-Frame-Options = DENY

### 10.2 HSTS (HTTP Strict Transport Security)

```php
// Add to SecurityHeaders middleware
$response->headers->set(
    'Strict-Transport-Security',
    'max-age=31536000; includeSubDomains'
);

// Or via web server (nginx):
// add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

- [ ] HSTS header present with `max-age >= 31536000`
- [ ] `includeSubDomains` if applicable

### 10.3 HTTPS

```php
// app/Providers/AppServiceProvider.php
public function boot()
{
    if (app()->environment('production')) {
        URL::forceScheme('https');
    }
}
```

- [ ] HTTPS forced in production

---

## 11. DEPENDENCY SECURITY

```bash
# PHP
composer audit

# NPM
npm audit
```

- [ ] `composer audit` shows no vulnerabilities
- [ ] `npm audit` without critical/high vulnerabilities

---

## 12. INJECTION ATTACKS

### 12.1 Command Injection

```bash
grep -rn "exec(\|shell_exec(\|system(\|passthru(\|proc_open(\|popen(" app/ --include="*.php"
```

```php
// ❌ CRITICAL — user input in shell command
exec("ping " . $request->host);
shell_exec("convert " . $request->file_path);

// ✅ Safe — escapeshellarg/escapeshellcmd
exec("ping " . escapeshellarg($request->host));

// ✅ Better — use Laravel Process (10+)
Process::run(['ping', $validatedHost]);
```

- [ ] No `exec()`, `shell_exec()`, `system()`, `passthru()` with user input
- [ ] If shell execution necessary — `escapeshellarg()` used

### 12.2 Object Injection

```php
// ❌ CRITICAL — unserialize user data
$data = unserialize($request->input('data'));
// Attacker crafts serialized object that executes code!

// ✅ Safe — use JSON
$data = json_decode($request->input('data'), true);

// ✅ If unserialize needed — restrict classes
$data = unserialize($input, ['allowed_classes' => [SafeClass::class]]);
```

- [ ] No `unserialize()` on user-controlled data
- [ ] Prefer `json_decode()` over `unserialize()`

### 12.3 Dangerous PHP Functions

```bash
grep -rn "eval(\|extract(\|assert(" app/ --include="*.php"
```

```php
// ❌ CRITICAL — code execution
eval($request->input('expression'));

// ❌ DANGEROUS — variable injection
extract($request->all());
// Now $is_admin, $role etc. are local variables!

// ✅ Safe — no eval, no extract
// Use proper logic/validation instead
```

- [ ] No `eval()` in application code
- [ ] No `extract()` with user data
- [ ] No `assert()` with user input

### 12.4 Open Redirection

```php
// ❌ CRITICAL — attacker controls redirect URL
return redirect($request->input('redirect_url'));
// Attacker sends: redirect_url=https://evil.com/phishing

// ✅ Safe — whitelist or relative-only
$url = $request->input('redirect_url', '/');
if (! Str::startsWith($url, '/') || Str::startsWith($url, '//')) {
    $url = '/';
}
return redirect($url);

// ✅ Better — use intended()
return redirect()->intended('/dashboard');
```

- [ ] `redirect()` never uses raw user input as URL
- [ ] External redirects validated against whitelist

### 12.5 Host Injection

```php
// ❌ DANGEROUS — attacker spoofs Host header
$url = "https://" . request()->getHost() . "/reset-password?token=$token";
// Attacker sets Host: evil.com → reset link points to evil.com

// ✅ Safe — use APP_URL
$url = config('app.url') . "/reset-password?token=$token";

// ✅ Better — enable TrustHosts middleware
// app/Http/Middleware/TrustHosts.php
public function hosts(): array
{
    return [
        $this->allSubdomainsOfApplicationUrl(),
    ];
}
```

- [ ] `TrustHosts` middleware enabled
- [ ] URLs built from `config('app.url')`, not `request()->getHost()`

### 12.6 SSRF (Server-Side Request Forgery)

If the application uses `Http::get()` or Guzzle with user-provided URLs, attackers can target internal services or cloud metadata.

```php
// ❌ Dangerous — SSRF
$response = Http::get($request->input('url'));

// ✅ Safe — validate URL
use Illuminate\Support\Str;

$url = $request->input('url');
$parsed = parse_url($url);
$host = strtolower($parsed['host'] ?? '');

$blocked = ['127.0.0.1', 'localhost', '169.254.169.254', '0.0.0.0', '[::1]'];
$blockedPrefixes = ['10.', '172.16.', '172.17.', '172.18.', '172.19.', '172.20.',
    '172.21.', '172.22.', '172.23.', '172.24.', '172.25.', '172.26.',
    '172.27.', '172.28.', '172.29.', '172.30.', '172.31.', '192.168.'];

if (in_array($host, $blocked) || Str::startsWith($host, $blockedPrefixes)) {
    abort(400, 'URL not allowed');
}
if (!in_array($parsed['scheme'] ?? '', ['http', 'https'])) {
    abort(400, 'Invalid protocol');
}

$response = Http::timeout(10)->get($url);
```

- [ ] URLs from user input are validated before `Http::get()` / Guzzle calls
- [ ] Internal/private IP ranges are blocked
- [ ] Only http/https protocols allowed
- [ ] Cloud metadata endpoints blocked (169.254.169.254)
- [ ] Request timeouts are set

---

## 13. SELF-CHECK (FP Recheck — 6-Step Procedure)
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

## 14. REPORT FORMAT

Create file `.claude/reports/SECURITY_AUDIT_[DATE].md`:

```markdown
# Security Audit Report — [Project Name]
Date: [date]
Auditor: Claude (Senior Security Engineer)

## Executive Summary

| Severity | Count | Status |
|----------|-------|--------|
| 🔴 Critical | X | X fixed |
| 🟠 High | X | X fixed |
| 🟡 Medium | X | X fixed |
| 🔵 Low | X | - |

**Overall Risk Level**: [Critical/High/Medium/Low]

## 🔴 Critical Vulnerabilities

### CRIT-001: [Title]
**Location**: `app/Http/Controllers/xxx.php:XX`
**Description**: ...
**Impact**: ...
**Remediation**: ...
**Status**: ✅ Fixed / ❌ Pending

## ✅ Security Controls in Place
- [x] CSRF protection enabled
- [x] Password hashing with bcrypt
- [ ] Rate limiting on all endpoints

## 📋 Remediation Checklist

### Immediate (24h)
- [ ] ...
```

---

## 15. ACTIONS

## 14. OUTPUT FORMAT (Structured Report Schema — Phase 14)
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

1. **Quick Check** — go through 5 points from section 0
2. **Scan** — go through all sections
3. **Classify** — Critical → Low
4. **Self-check** — filter false positives
5. **Document** — file, line, code
6. **Fix** — suggest specific fix

Start the audit. First Quick Check, then Executive Summary.

## Council Handoff
<!-- v42-splice: council-handoff -->

When the structured report is complete, hand it off to the Supreme Council for
peer review. See `commands/audit.md` Phase 5 (Council Pass — mandatory) for the
invocation: `/council audit-review --report <path>`. The Council runs in
audit-review mode (see `commands/council.md` `## Modes`). The Council verdict
slot in the report is pre-populated with the byte-exact placeholder
`_pending — run /council audit-review_` (U+2014 em-dash) and is overwritten by
the Council pass.
