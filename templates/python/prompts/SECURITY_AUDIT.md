# Security Audit — Python Template

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

1. **Quick Check** — go through 5 points
2. **Scan** — go through all sections
3. **Classify** — Critical → Low
4. **Document** — file, line, code
5. **Fix** — suggest concrete fix

Start the audit. First Quick Check, then Executive Summary.
