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

If all 5 = OK → Basic security level OK.

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

## 10. DEPENDENCY SECURITY

```bash
# pip-audit
pip-audit

# safety (alternative)
safety check
```

- [ ] pip-audit without critical vulnerabilities
- [ ] Dependencies updated

---

## 11. FILE UPLOAD

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

## 12. REPORT FORMAT

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

## 13. ACTIONS

1. **Quick Check** — go through 5 points
2. **Scan** — go through all sections
3. **Classify** — Critical → Low
4. **Document** — file, line, code
5. **Fix** — suggest concrete fix

Start the audit. First Quick Check, then Executive Summary.
