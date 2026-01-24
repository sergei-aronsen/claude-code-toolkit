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

If all 5 = OK → Basic security level OK.

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

### 4.2 Controller Validation

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

### 5.3 Rate Limiting

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

### 10.2 HTTPS

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

## 12. SELF-CHECK

**Before adding a vulnerability to the report:**

| Question | If "no" → reconsider severity |
| -------- | ---------------------------------- |
| Is it **exploitable** in real conditions? | Theoretical ≠ real threat |
| Is there an **attack path** for an attacker? | Internal-only ≠ CRITICAL |
| **What's the damage** on successful attack? | Public data leak ≠ password leak |
| Is **auth required** for exploitation? | Auth-required reduces severity |

---

## 13. REPORT FORMAT

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

## 14. ACTIONS

1. **Quick Check** — go through 5 points from section 0
2. **Scan** — go through all sections
3. **Classify** — Critical → Low
4. **Self-check** — filter false positives
5. **Document** — file, line, code
6. **Fix** — suggest specific fix

Start the audit. First Quick Check, then Executive Summary.
