# Security Audit — Python Template

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

## Objective

Comprehensive security audit of a Python application (FastAPI/Django). Act as a Senior Security Engineer.

> **Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for conducting audits.

---

## 0. QUICK CHECK (5 minutes)

| # | Check | Command | Expected |
| --- | ------- | --------- | ---------- |
| 1 | Debug mode | `grep -rn "DEBUG.*=.*True" src/ settings/` | Empty in production |
| 2 | Secrets in code | `grep -rn "sk-\|password.*=.*['\"]" src/ --include="*.py"` | Empty |
| 3 | SQL injection | `grep -rn "execute.*f[\"\']SELECT\|\.raw(" src/ --include="*.py"` | Check |
| 4 | pip audit | `pip-audit` | No vulnerabilities |
| 5 | Hardcoded keys | `grep -rn "API_KEY.*=.*['\"][a-zA-Z0-9]" src/ --include="*.py"` | Empty |
| 6 | Secret key | `echo $SECRET_KEY \| wc -c` | >= 32 characters |
| 7 | Open redirect | `grep -rn "redirect.*request\.\|RedirectResponse.*request" src/ --include="*.py"` | Check validation |
| 8 | .env public | Verify `.env` not in static/ directory | Not accessible |

If all 8 = OK → Basic security level OK.

---

## 0.1 AUTO-CHECK SCRIPT

```bash
#!/bin/bash
# security-check.sh

echo "Security Quick Check — Python..."

# 1. Debug mode
DEBUG=$(grep -rn "DEBUG.*=.*True" src/ config/ settings/ 2>/dev/null | grep -v "test\|example")
[ -z "$DEBUG" ] && echo "Debug: No DEBUG=True" || echo "Debug: Found DEBUG=True!"

# 2. Hardcoded secrets
SECRETS=$(grep -rn "sk-\|api_key.*=.*['\"][a-zA-Z0-9]" src/ --include="*.py" 2>/dev/null | grep -v "os.environ\|settings\.")
[ -z "$SECRETS" ] && echo "Secrets: No hardcoded keys" || echo "Secrets: Found hardcoded keys!"

# 3. SQL injection patterns
SQLI=$(grep -rn 'execute.*f"SELECT\|\.raw(' src/ --include="*.py" 2>/dev/null)
[ -z "$SQLI" ] && echo "SQL: No injection patterns" || echo "SQL: Potential injection!"

# 4. pip-audit
pip-audit 2>/dev/null | grep -q "No known" && echo "Pip: No vulnerabilities" || echo "Pip: Run 'pip-audit' for details"

# 5. eval/exec usage
EXEC=$(grep -rn "eval(\|exec(" src/ --include="*.py" 2>/dev/null)
[ -z "$EXEC" ] && echo "Exec: No dangerous eval/exec" || echo "Exec: Found dangerous patterns!"

# 6. Missing Pydantic validation
ROUTES=$(grep -rn "@app\.\(get\|post\|put\|delete\)" src/ --include="*.py" 2>/dev/null | wc -l)
echo "Found $ROUTES route definitions (verify Pydantic validation)"

# 7. Secret key strength
SECRET_LEN=$(echo -n "$SECRET_KEY" | wc -c)
[ "$SECRET_LEN" -ge 32 ] && echo "✅ Secret: SECRET_KEY is strong (${SECRET_LEN} chars)" || echo "❌ Secret: SECRET_KEY too short (${SECRET_LEN} chars, need >= 32)"

# 8. Open redirect
REDIRECT=$(grep -rn "RedirectResponse.*request\|redirect.*request\.\|redirect(.*url" src/ --include="*.py" 2>/dev/null | grep -v "test\|spec")
[ -z "$REDIRECT" ] && echo "✅ Redirect: No open redirect patterns" || echo "🟡 Redirect: Found redirect patterns (verify validation)"

# 9. Dangerous functions
DANGEROUS=$(grep -rn "pickle\.loads\|yaml\.load\b\|eval(\|exec(" src/ --include="*.py" 2>/dev/null | grep -v "test\|yaml\.safe_load")
[ -z "$DANGEROUS" ] && echo "✅ Functions: No dangerous functions" || echo "🟡 Functions: Found dangerous functions (verify usage)"

# 10. Dangerous functions (extended)
DANGEROUS=$(grep -rn "eval(\|exec(\|os\.system(\|subprocess.*shell=True\|__import__(" src/ app/ 2>/dev/null | grep -v "test\|spec\|__pycache__\|\.pyc\|venv")
[ -z "$DANGEROUS" ] && echo "✅ Functions: No dangerous patterns" || echo "🟡 Functions: Found dangerous function patterns (verify input)"

# 11. .env exposure
[ ! -f static/.env ] && [ ! -f public/.env ] && echo "✅ .env: Not in public dirs" || echo "❌ .env: Exposed in public directory!"

echo "Done!"
```

---

## 0.2 PROJECT SPECIFICS

**Fill before audit:**

**Already implemented:**

- [ ] Authentication: [JWT / OAuth2 / Session]
- [ ] Authorization: [Dependencies / Permissions / RBAC]
- [ ] Input validation: [Pydantic v2]
- [ ] ORM: [SQLAlchemy 2.0 / Django ORM / raw SQL]

**Public endpoints (by design):**

- `/health` — health check
- `/api/webhooks/*` — webhooks (check signature!)

---

## 0.3 SEVERITY LEVELS

| Level | Description | Action |
| ------- | ---------- | ---------- |
| CRITICAL | Exploitable vulnerability: RCE, SQLi, auth bypass | **BLOCKER** — fix immediately |
| HIGH | Serious vulnerability, requires auth or complex exploitation | Fix before deploy |
| MEDIUM | Potential vulnerability, low risk | Fix in next sprint |
| LOW | Best practice, defense in depth | Backlog |
| INFO | Information, no action required | — |

---

## 1. INPUT VALIDATION

### 1.1 Pydantic v2 Validation

```python
# CRITICAL — no validation
@app.post("/users")
async def create_user(request: Request):
    data = await request.json()  # Anything!
    return await db.create_user(**data)

# Good — Pydantic validation
from pydantic import BaseModel, EmailStr, Field

class CreateUserRequest(BaseModel):
    email: EmailStr
    name: str = Field(min_length=2, max_length=100)
    age: int | None = Field(default=None, ge=0, le=150)

@app.post("/users")
async def create_user(data: CreateUserRequest):
    return await db.create_user(**data.model_dump())
```

- [ ] All endpoints use Pydantic models
- [ ] String fields have max_length
- [ ] Number fields have boundaries (ge, le)

### 1.2 Path/Query Validation

```python
# CRITICAL — no UUID validation
@app.get("/users/{user_id}")
async def get_user(user_id: str):
    return await db.get_user(user_id)  # SQL injection?

# Good — strict typing
from uuid import UUID

@app.get("/users/{user_id}")
async def get_user(user_id: UUID):  # FastAPI validates automatically
    return await db.get_user(str(user_id))
```

- [ ] Path parameters are typed (UUID, int)
- [ ] Query parameters use Pydantic or Query()

---

## 2. SQL INJECTION

### 2.1 Raw Queries

```python
# CRITICAL — SQL Injection
cursor.execute(f"SELECT * FROM users WHERE email = '{email}'")

# CRITICAL — format strings
query = "SELECT * FROM users WHERE name LIKE '%{}%'".format(search)

# Good — parameterized queries
cursor.execute("SELECT * FROM users WHERE email = %s", (email,))

# Better — ORM
user = await session.execute(
    select(User).where(User.email == email)
)
```

- [ ] No f-strings in SQL
- [ ] No .format() in SQL
- [ ] Using ORM (SQLAlchemy/Django ORM)

### 2.2 SQLAlchemy 2.0 Style

```python
# CRITICAL — text() without bindings
from sqlalchemy import text

result = session.execute(text(f"SELECT * FROM users WHERE id = {user_id}"))

# Good — bindings
result = session.execute(
    text("SELECT * FROM users WHERE id = :id"),
    {"id": user_id}
)

# Better — Query API
result = await session.execute(
    select(User).where(User.id == user_id)
)
```

- [ ] text() always with bindings
- [ ] Using select() instead of raw SQL

---

## 3. COMMAND INJECTION

### 3.1 subprocess

```python
# CRITICAL — Command Injection
import subprocess

@app.post("/convert")
async def convert(filename: str):
    subprocess.run(f"convert {filename} output.pdf", shell=True)

# Good — no shell, argument list
import shlex
from pathlib import Path

@app.post("/convert")
async def convert(filename: str):
    safe_filename = Path(filename).name  # Only basename
    subprocess.run(["convert", safe_filename, "output.pdf"])
```

- [ ] No shell=True with user input
- [ ] Using argument list
- [ ] Filenames are sanitized

---

## 4. AUTHENTICATION

### 4.1 JWT Security (FastAPI)

```python
# CRITICAL — weak secret
SECRET_KEY = "secret"

# CRITICAL — no algorithm check
payload = jwt.decode(token, SECRET_KEY)

# Good
from jose import jwt, JWTError

SECRET_KEY = os.environ["JWT_SECRET"]  # At least 32 characters

def decode_token(token: str) -> dict:
    try:
        return jwt.decode(
            token,
            SECRET_KEY,
            algorithms=["HS256"]  # Explicitly specified
        )
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
```

- [ ] SECRET_KEY from env (at least 32 characters)
- [ ] Algorithm explicitly specified
- [ ] JWTError is handled

### 4.2 Password Hashing

```python
# CRITICAL — plain text
user.password = request.password

# CRITICAL — weak hash
import hashlib
user.password = hashlib.md5(password.encode()).hexdigest()

# ✅ BEST — Argon2id (OWASP recommended)
from passlib.context import CryptContext

pwd_context = CryptContext(
    schemes=["argon2"],
    deprecated="auto",
    argon2__memory_cost=65536,  # 64MB
    argon2__time_cost=3,
    argon2__parallelism=4,
)

hashed = pwd_context.hash(password)
is_valid = pwd_context.verify(password, hashed)

# ✅ Good — bcrypt (acceptable alternative)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
```

- [ ] Passwords hashed with Argon2id (preferred) or bcrypt
- [ ] Using passlib
- [ ] No MD5/SHA1/SHA256 for passwords

---

## 5. AUTHORIZATION

### 5.1 Dependency Injection (FastAPI)

```python
# CRITICAL — no ownership check
@app.get("/documents/{doc_id}")
async def get_document(doc_id: UUID, db: AsyncSession = Depends(get_db)):
    return await db.get(Document, doc_id)  # Anyone can access!

# Good — ownership check
@app.get("/documents/{doc_id}")
async def get_document(
    doc_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    doc = await db.execute(
        select(Document).where(
            Document.id == doc_id,
            Document.user_id == current_user.id
        )
    )
    if not doc.scalar_one_or_none():
        raise HTTPException(404, "Not found")
    return doc
```

- [ ] Protected routes use Depends(get_current_user)
- [ ] Resource ownership is checked

---

## 6. SSRF PROTECTION

```python
# CRITICAL — SSRF
@app.post("/fetch")
async def fetch_url(url: str):
    response = httpx.get(url)  # Can request internal URLs!

# Good — URL validation
from urllib.parse import urlparse

BLOCKED_HOSTS = ["localhost", "127.0.0.1", "169.254.169.254", "10.", "172.16.", "192.168."]

def is_url_safe(url: str) -> bool:
    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https"):
        return False
    for blocked in BLOCKED_HOSTS:
        if parsed.hostname and (parsed.hostname == blocked or parsed.hostname.startswith(blocked)):
            return False
    return True

@app.post("/fetch")
async def fetch_url(url: str):
    if not is_url_safe(url):
        raise HTTPException(400, "URL not allowed")
    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.get(url)
```

- [ ] URLs are validated
- [ ] Internal IPs are blocked
- [ ] Timeout is set

---

## 7. SECRETS MANAGEMENT

```python
# CRITICAL — hardcoded
STRIPE_KEY = "sk_live_xxxxx"

# CRITICAL — in code
API_KEY = "sk-ant-xxxxx"

# Good — pydantic-settings
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    stripe_secret_key: str
    database_url: str
    jwt_secret: str

    class Config:
        env_file = ".env"

settings = Settings()
```

- [ ] No hardcoded secrets
- [ ] Using pydantic-settings
- [ ] .env in .gitignore

### 7.2 Secret Key Validation

```python
# ❌ Weak secret
SECRET_KEY = "secret"
SECRET_KEY = os.environ.get("SECRET_KEY", "changeme")  # Weak fallback!

# ✅ Strong secret with validation (FastAPI)
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    secret_key: str

    @validator('secret_key')
    def validate_secret_key(cls, v):
        if len(v) < 32:
            raise ValueError('SECRET_KEY must be at least 32 characters')
        return v

# ✅ Django — validate in settings
SECRET_KEY = os.environ['SECRET_KEY']
if len(SECRET_KEY) < 50:
    raise ImproperlyConfigured('SECRET_KEY too short')
```

- [ ] SECRET_KEY is at least 32 characters (Django default generates 50)
- [ ] No weak fallback values in `os.environ.get()`
- [ ] Secret validated on application startup
- [ ] Different secrets per environment

### 7.3 .env Public Access

`.env` files accessible via web expose all secrets.

- [ ] `.env` is not in static files directory (`static/`, `public/`, `www/`)
- [ ] `.env` is in `.gitignore`
- [ ] Web server blocks access to dotfiles (Nginx: `location ~ /\. { deny all; }`)
- [ ] Verify: `curl -s https://yoursite.com/.env` returns 403/404
- [ ] Sensitive settings are loaded from environment, not `.env` in production

**Django-specific:**

```python
# settings.py — never read .env directly in production
# Use environment variables or a secrets manager
SECRET_KEY = os.environ["DJANGO_SECRET_KEY"]  # Not from .env file
```

### 7.4 Session Timeout

```python
# FastAPI + JWT
ACCESS_TOKEN_EXPIRE_MINUTES = 30  # ✅ 30 minutes

def create_access_token(data: dict):
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    return jwt.encode({**data, "exp": expire}, SECRET_KEY, algorithm="HS256")

# Django
SESSION_COOKIE_AGE = 1800        # ✅ 30 minutes
SESSION_EXPIRE_AT_BROWSER_CLOSE = True
SESSION_SAVE_EVERY_REQUEST = True # Reset on activity
```

- [ ] JWT `exp` claim is set (recommended: 15-60 minutes)
- [ ] Django `SESSION_COOKIE_AGE` is configured
- [ ] Session expires on browser close for sensitive apps

---

## 8. RATE LIMITING

```python
# CRITICAL — no rate limiting
@app.post("/login")
async def login(credentials: LoginRequest):
    # Brute force possible
    pass

# Good — slowapi
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@app.post("/login")
@limiter.limit("5/minute")
async def login(request: Request, credentials: LoginRequest):
    pass
```

- [ ] Login endpoint has rate limiting
- [ ] Sensitive endpoints are protected

---

## 9. DEBUG MODE

```python
# CRITICAL in production
DEBUG = True
app = FastAPI(debug=True)

# Django
DEBUG = True  # in settings.py

# Good
DEBUG = os.environ.get("DEBUG", "false").lower() == "true"
app = FastAPI(debug=DEBUG)
```

- [ ] DEBUG=False in production
- [ ] No stack traces in responses

---

## 10. Open Redirection

```python
# ❌ Dangerous — redirect to user-supplied URL
from fastapi.responses import RedirectResponse

@app.get("/callback")
async def callback(return_url: str):
    return RedirectResponse(url=return_url)  # Open redirect!

# Django
def callback(request):
    return redirect(request.GET['next'])  # Open redirect!

# ✅ Safe — validate URL (FastAPI)
from urllib.parse import urlparse

ALLOWED_HOSTS = {"myapp.com", "www.myapp.com"}

@app.get("/callback")
async def callback(return_url: str):
    parsed = urlparse(return_url)
    if parsed.hostname and parsed.hostname not in ALLOWED_HOSTS:
        return RedirectResponse(url="/")
    return RedirectResponse(url=return_url)

# ✅ Safe — Django has built-in url_has_allowed_host_and_scheme
from django.utils.http import url_has_allowed_host_and_scheme

def callback(request):
    next_url = request.GET.get('next', '/')
    if not url_has_allowed_host_and_scheme(next_url, allowed_hosts={request.get_host()}):
        next_url = '/'
    return redirect(next_url)
```

- [ ] No `RedirectResponse` / `redirect()` with raw user input
- [ ] Redirect URLs validated against whitelist
- [ ] Django uses `url_has_allowed_host_and_scheme`

### 10.2 Host Injection

```python
# ❌ Dangerous — trusting Host header
@app.post("/forgot-password")
async def forgot_password(request: Request, email: str):
    host = request.headers.get("host")
    reset_link = f"https://{host}/reset?token={token}"  # Spoofable!

# ✅ Safe — use configured base URL
BASE_URL = os.environ["APP_URL"]

@app.post("/forgot-password")
async def forgot_password(email: str):
    reset_link = f"{BASE_URL}/reset?token={token}"

# ✅ Django — ALLOWED_HOSTS validates Host header
ALLOWED_HOSTS = ['myapp.com', 'www.myapp.com']  # settings.py
```

- [ ] Password reset links use configured `APP_URL`, not Host header
- [ ] Django `ALLOWED_HOSTS` is set (not `['*']` in production)
- [ ] FastAPI uses configured base URL for all generated links

### 10.3 HSTS (HTTP Strict Transport Security)

```python
# FastAPI — middleware
from starlette.middleware.httpsredirect import HTTPSRedirectMiddleware

app.add_middleware(HTTPSRedirectMiddleware)

# Or custom HSTS header
@app.middleware("http")
async def add_hsts(request, call_next):
    response = await call_next(request)
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains; preload"
    return response

# Django
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SECURE_SSL_REDIRECT = True
```

- [ ] HSTS header configured
- [ ] `max-age` >= 31536000 (1 year)
- [ ] Django: `SECURE_HSTS_SECONDS` and `SECURE_SSL_REDIRECT` set

### 10.4 Dangerous Python Functions

```python
# ❌ CRITICAL — Remote Code Execution
eval(user_input)
exec(user_input)

# ❌ CRITICAL — Deserialization attack
import pickle
data = pickle.loads(user_input)  # Arbitrary code execution!

# ❌ CRITICAL — YAML injection
import yaml
data = yaml.load(user_input)     # Code execution via !!python/object

# ✅ Safe alternatives
import json
data = json.loads(user_input)    # JSON is safe

import yaml
data = yaml.safe_load(user_input)  # safe_load blocks dangerous tags

import ast
value = ast.literal_eval(user_input)  # Only literals, no code
```

- [ ] No `eval()` / `exec()` with user input
- [ ] No `pickle.loads()` with untrusted data
- [ ] `yaml.safe_load()` instead of `yaml.load()`
- [ ] No `os.system()` or `subprocess.run(shell=True)` with user input

### 10.5 Dangerous Functions

Some Python built-in functions allow arbitrary code execution.

```python
# ❌ Never use with user input
eval(user_input)                    # Arbitrary code execution
exec(user_input)                    # Arbitrary code execution
os.system(user_input)               # Shell injection
subprocess.call(user_input, shell=True)  # Shell injection
__import__(user_input)              # Arbitrary module import
compile(user_input, '<string>', 'exec')  # Code compilation

# ✅ Safe alternatives
import ast
ast.literal_eval(user_input)        # Only literals (strings, numbers, lists)
subprocess.run(["cmd", arg], shell=False)  # No shell injection
```

- [ ] No `eval()` / `exec()` with user-controlled input
- [ ] No `os.system()` or `subprocess` with `shell=True` and user input
- [ ] No `__import__()` with user-controlled module names
- [ ] If dynamic evaluation needed, use `ast.literal_eval()` for data only

### 10.6 File Permissions

- [ ] `.env` file permissions: `600` or `640`
- [ ] Log directory is not world-writable
- [ ] Upload directory does not allow script execution
- [ ] Application runs as non-root user
- [ ] Django `SECRET_KEY` file (if used) has restricted permissions

---

## 11. DEPENDENCY SECURITY

```bash
# pip-audit
pip-audit

# safety (alternative)
safety check
```

- [ ] pip-audit without critical vulnerabilities
- [ ] Dependencies updated

---

## 12. FILE UPLOAD

```python
# CRITICAL — no validation
@app.post("/upload")
async def upload(file: UploadFile):
    content = await file.read()  # Any file!

# Good — validation
ALLOWED_TYPES = {"image/jpeg", "image/png", "application/pdf"}
MAX_SIZE = 10 * 1024 * 1024  # 10MB

@app.post("/upload")
async def upload(file: UploadFile):
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(400, "Invalid file type")

    content = await file.read()
    if len(content) > MAX_SIZE:
        raise HTTPException(400, "File too large")

    # Generate safe name
    safe_name = f"{uuid4()}{Path(file.filename).suffix}"
```

- [ ] Content-type is validated
- [ ] Size is limited
- [ ] Filename is generated

---

## 15. SELF-CHECK (FP Recheck — 6-Step Procedure)
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

## 13. REPORT FORMAT

```markdown
# Security Audit Report — [Project Name]
Date: [date]
Auditor: Claude (Senior Security Engineer)

## Executive Summary

| Severity | Count | Status |
|----------|-------|--------|
| CRITICAL | X | X fixed |
| HIGH | X | X fixed |
| MEDIUM | X | X fixed |
| LOW | X | - |

**Overall Risk Level**: [Critical/High/Medium/Low]

## CRITICAL Vulnerabilities

### CRIT-001: [Title]
**Location**: `src/api/xxx.py:XX`
**Description**: ...
**Impact**: ...
**Remediation**: ...

## Security Controls in Place
- [x] Pydantic validation
- [x] bcrypt password hashing
- [ ] Rate limiting on all endpoints
```

---

## 14. ACTIONS

## 16. OUTPUT FORMAT (Structured Report Schema — Phase 14)
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

1. **Quick Check** — go through 5 points
2. **Scan** — go through all sections
3. **Classify** — Critical → Low
4. **Document** — file, line, code
5. **Fix** — suggest concrete fix

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
