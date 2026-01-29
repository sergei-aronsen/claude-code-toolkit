# Security Audit — Laravel Template

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

---

## 13. SELF-CHECK

**Before adding a vulnerability to the report:**

| Question | If "no" → reconsider severity |
| -------- | ---------------------------------- |
| Is it **exploitable** in real conditions? | Theoretical ≠ real threat |
| Is there an **attack path** for an attacker? | Internal-only ≠ CRITICAL |
| **What's the damage** on successful attack? | Public data leak ≠ password leak |
| Is **auth required** for exploitation? | Auth-required reduces severity |

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

1. **Quick Check** — go through 5 points from section 0
2. **Scan** — go through all sections
3. **Classify** — Critical → Low
4. **Self-check** — filter false positives
5. **Document** — file, line, code
6. **Fix** — suggest specific fix

Start the audit. First Quick Check, then Executive Summary.
