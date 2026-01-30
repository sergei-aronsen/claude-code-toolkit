# Code Review — Python Template

## Goal

Comprehensive code review of a Python application. Act as a Senior Tech Lead.

> **Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for code review — works better with code analysis.

---

## 0. QUICK CHECK (5 minutes)

| # | Check | Command | Expected |
| --- | ------- | --------- | ---------- |
| 1 | Tests | `pytest --tb=short -q` | All pass |
| 2 | Type check | `mypy src/` | No errors |
| 3 | Lint | `ruff check .` | No violations |
| 4 | Formatting | `ruff format --check .` | No changes |
| 5 | Security scan | `bandit -r src/ -q` | No high/critical |
| 6 | Django checks | `python manage.py check --deploy` | No warnings (Django only) |

---

## 0.1 AUTO-CHECK SCRIPT

```bash
#!/bin/bash
# code-check.sh — Python project quality gate

echo "Code Quality Check..."

# 1. Tests
pytest --tb=short -q > /dev/null 2>&1 && echo "OK Tests" || echo "FAIL Tests"

# 2. Type checking
mypy src/ --no-error-summary > /dev/null 2>&1 && echo "OK mypy" || echo "WARN mypy: type errors found"

# 3. Linting
ruff check . --quiet > /dev/null 2>&1 && echo "OK ruff lint" || echo "WARN ruff: lint issues"

# 4. Formatting
ruff format --check . > /dev/null 2>&1 && echo "OK ruff format" || echo "WARN ruff: needs formatting"

# 5. Security
bandit -r src/ -q --severity-level high > /dev/null 2>&1 && echo "OK bandit" || echo "WARN bandit: security issues"

# 6. God modules (>300 lines)
GOD_MODULES=$(find src -name "*.py" -exec wc -l {} \; | awk '$1 > 300 {print $2}' | wc -l)
[ "$GOD_MODULES" -eq 0 ] && echo "OK No god modules" || echo "WARN God modules: $GOD_MODULES files >300 lines"

# 7. TODO/FIXME/HACK
TODOS=$(grep -rn "TODO\|FIXME\|HACK\|XXX" src/ --include="*.py" 2>/dev/null | wc -l)
echo "INFO TODO/FIXME/HACK: $TODOS comments"

# 8. Debug artifacts
DEBUGS=$(grep -rn "breakpoint()\|pdb\.set_trace\|import pdb\|print(" src/ --include="*.py" 2>/dev/null | wc -l)
[ "$DEBUGS" -eq 0 ] && echo "OK No debug artifacts" || echo "FAIL Debug code: $DEBUGS occurrences found"

# 9. Bare except clauses
BARE_EXCEPT=$(grep -rn "except:" src/ --include="*.py" 2>/dev/null | wc -l)
[ "$BARE_EXCEPT" -eq 0 ] && echo "OK No bare except" || echo "WARN Bare except: $BARE_EXCEPT occurrences"

echo "Done!"
```

---

## 0.2 PROJECT SPECIFICS — [Project Name]

**Accepted decisions (no need to fix):**

- [Conscious architectural decisions]

**Key files for review:**

- `src/services/` — business logic
- `src/api/` — API endpoints (FastAPI routers / Django views)
- `src/models/` — ORM models (SQLAlchemy / Django)
- `src/schemas/` — Pydantic schemas
- `src/core/` — configuration, security, exceptions
- `tasks/` or `src/tasks/` — Celery / background tasks

**Project patterns:**

- Pydantic for validation
- Services for business logic
- Dependency injection via FastAPI Depends / Django middleware

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

# Changed Python files only
git diff --name-only HEAD~5 -- '*.py'
```

- [ ] Which files changed
- [ ] Which new files created
- [ ] Relationship between changes

### 1.2 Categorization

- [ ] API endpoints (`src/api/`, `apps/*/views.py`)
- [ ] Services (`src/services/`, `apps/*/services.py`)
- [ ] Models (`src/models/`, `apps/*/models.py`)
- [ ] Schemas (`src/schemas/`, `apps/*/serializers.py`)
- [ ] Migrations (`alembic/versions/`, `apps/*/migrations/`)
- [ ] Configuration (`src/core/config.py`, `config/settings/`)
- [ ] Background tasks (`src/tasks/`, `apps/*/tasks.py`)
- [ ] Tests (`tests/`)

---

## 2. ARCHITECTURE & STRUCTURE

### 2.1 Single Responsibility

```python
# BAD — endpoint does everything
@router.post("/sites")
async def create_site(request: SiteCreate, db: AsyncSession = Depends(get_db)):
    if not request.url.startswith("https"):
        raise HTTPException(400, "URL must be HTTPS")
    async with httpx.AsyncClient() as client:
        response = await client.get(str(request.url))
    title = BeautifulSoup(response.text, "html.parser").title
    site = Site(url=str(request.url), title=title, user_id=current_user.id)
    db.add(site)
    await db.commit()
    await send_email(current_user.email, "Site created", f"Site {title} added")
    return site


# GOOD — endpoint only coordinates
@router.post("/sites", response_model=SiteResponse)
async def create_site(
    request: SiteCreate,
    service: SiteService = Depends(get_site_service),
    user: User = Depends(get_current_user),
) -> SiteResponse:
    site = await service.create(request, user)
    return SiteResponse.model_validate(site)
```

- [ ] Endpoints/views < 100 lines, endpoint functions < 20 lines
- [ ] Business logic in services, not in endpoints
- [ ] Validation in Pydantic schemas or Django forms, not in endpoints

### 2.2 Dependency Injection

```python
# BAD — hardcoded dependencies
class ParserService:
    def parse(self, url: str) -> dict:
        client = httpx.Client()  # Hardcoded, untestable
        return {"title": self._extract_title(client.get(url).text)}


# GOOD — FastAPI Depends
class ParserService:
    def __init__(self, client: httpx.AsyncClient) -> None:
        self._client = client

    async def parse(self, url: str) -> ParsedResult:
        response = await self._client.get(url)
        return ParsedResult(title=self._extract_title(response.text))

def get_parser_service(
    client: httpx.AsyncClient = Depends(get_http_client),
) -> ParserService:
    return ParserService(client)


# GOOD — Django class-based view
class SiteView(LoginRequiredMixin, View):
    def setup(self, request, *args, **kwargs):
        super().setup(request, *args, **kwargs)
        self.site_service = SiteService(parser=get_parser_service())
```

- [ ] Dependencies injected via constructor or FastAPI Depends
- [ ] No hardcoded instantiation inside methods (except DTOs/dataclasses)
- [ ] Services accept interfaces/protocols, not concrete classes

### 2.3 Proper Placement

```text
# FastAPI layout                    # Django layout
src/                                project/
├── api/            # Routing       ├── config/         # Settings
│   ├── v1/                         │   ├── settings/
│   └── deps.py     # Dependencies  │   ├── urls.py
├── core/           # Config        │   └── wsgi.py
├── models/         # ORM models    ├── apps/
├── schemas/        # Pydantic I/O  │   ├── sites/
├── services/       # Business      │   │   ├── models.py
├── repositories/   # Data access   │   │   ├── views.py
└── tasks/          # Celery        │   │   ├── services.py
                                    │   │   └── tasks.py
                                    └── utils/
```

- [ ] Files in correct directories
- [ ] No God-modules (> 300 lines)
- [ ] Logic extracted from models/views into services

### 2.4 Python-Specific Patterns

```python
# GOOD — Protocol for interfaces (structural typing)
from typing import Protocol, runtime_checkable

@runtime_checkable
class NotificationSender(Protocol):
    def send(self, user_id: int, message: str) -> None: ...

# GOOD — dataclass for value objects
from dataclasses import dataclass

@dataclass(frozen=True)
class ParsedResult:
    title: str | None
    description: str | None

# GOOD — Pydantic for validated external data
class SiteCreate(BaseModel):
    url: HttpUrl
    name: str = Field(min_length=1, max_length=255)
    tags: list[str] = Field(default_factory=list)

# GOOD — Enum for fixed choices
class SiteStatus(StrEnum):
    ACTIVE = "active"
    PENDING = "pending"
    ARCHIVED = "archived"
```

- [ ] Protocols for interfaces instead of ABC (unless inheritance is needed)
- [ ] dataclasses for internal value objects, Pydantic for external/validated data
- [ ] Enums for fixed choices (`StrEnum`, `IntEnum`)
- [ ] `@dataclass(frozen=True)` for immutable data
- [ ] Composition over inheritance

---

## 3. CODE QUALITY

### 3.1 Naming Conventions

```python
# BAD — unclear or non-PEP 8 names
d = Site.objects.get(id=id)
res = self.proc(d)
siteURL = data["url"]

# GOOD — PEP 8 compliant, descriptive names
site = Site.objects.get(id=site_id)
parsed_data = self.parse_content(site)
site_url = data["url"]
```

- [ ] **Variables** — nouns, `snake_case`: `site_url`, `parsed_content`
- [ ] **Functions/methods** — verbs, `snake_case`: `get_site()`, `parse_content()`
- [ ] **Classes** — nouns, `PascalCase`: `SiteService`, `ParsedResult`
- [ ] **Constants** — `UPPER_SNAKE_CASE`: `MAX_RETRIES`, `DEFAULT_TIMEOUT`
- [ ] **Private** — leading underscore: `_internal_method()`, `_cached_value`
- [ ] **Boolean** — is/has/can/should: `is_active`, `has_labels`, `can_retry`
- [ ] **No shadowing** builtins: avoid `id`, `type`, `list`, `dict` as variable names

### 3.2 Complexity

```python
# BAD — deep nesting
def process_sites(sites: list[dict]) -> list[dict]:
    results = []
    for site in sites:
        if site["type"] == "web":
            if site["status"] == "active":
                if site.get("url"):
                    # deep nesting...
                    results.append(fetch(site["url"]))
    return results


# GOOD — flat structure, early returns, extracted helpers
def process_sites(sites: list[dict]) -> list[ProcessedSite]:
    return [
        processed
        for site in sites
        if (processed := _try_process(site)) is not None
    ]

def _should_process(site: dict) -> bool:
    return site["type"] == "web" and site["status"] == "active" and bool(site.get("url"))
```

- [ ] Functions < 20 lines (ideally < 10)
- [ ] Nesting < 3 levels
- [ ] Early returns are used
- [ ] List comprehensions readable (no multi-level nested comprehensions)
- [ ] Complex conditions extracted to helper functions with descriptive names

### 3.3 DRY

```python
# BAD — duplicated query logic
async def get_active_sites(db, user_id):
    return await db.execute(select(Site).where(Site.status == "active", Site.user_id == user_id))

async def get_pending_sites(db, user_id):
    return await db.execute(select(Site).where(Site.status == "pending", Site.user_id == user_id))


# GOOD — parameterized (SQLAlchemy)
async def get_sites_by_status(db: AsyncSession, user_id: int, status: SiteStatus) -> list[Site]:
    result = await db.execute(
        select(Site).where(Site.user_id == user_id, Site.status == status)
    )
    return list(result.scalars().all())

# GOOD — Django QuerySet methods
class SiteQuerySet(models.QuerySet):
    def for_user(self, user: User) -> "SiteQuerySet":
        return self.filter(user=user)

    def active(self) -> "SiteQuerySet":
        return self.filter(status=SiteStatus.ACTIVE)

# Usage: Site.objects.for_user(user).active()
```

- [ ] No copy-paste code
- [ ] Repeated queries extracted to repository methods or QuerySet managers
- [ ] Common patterns extracted to utility functions

### 3.4 Type Safety

```python
# BAD — no type hints
def process(data, options=None):
    return [transform(item) for item in data]


# GOOD — full type annotations
def process(
    data: Sequence[RawItem],
    options: ProcessOptions | None = None,
) -> list[ProcessedItem]:
    return [transform(item, options or ProcessOptions()) for item in data]

# GOOD — Generic types, TypedDict
class PaginatedResponse(BaseModel, Generic[T]):
    items: list[T]
    total: int

class SiteConfig(TypedDict):
    url: str
    timeout: int
    retries: NotRequired[int]
```

- [ ] All functions have return type annotations
- [ ] All parameters are typed
- [ ] Use `X | None` instead of `Optional[X]` (Python 3.10+)
- [ ] Use `collections.abc` types (`Sequence`, `Mapping`) over `typing` equivalents
- [ ] Generic types for reusable data structures
- [ ] `TypedDict` for structured dictionaries instead of bare `dict`
- [ ] No `Any` unless justified with a comment
- [ ] `mypy --strict` passes (or project-level mypy config is followed)

### 3.5 Python Idioms

```python
# BAD — non-idiomatic Python
f = open("data.json", "r")
data = json.load(f)
f.close()

items = []
for x in raw_items:
    if x.is_valid():
        items.append(x.value)

if len(items) == 0:
    return None


# GOOD — idiomatic Python
with open("data.json") as f:
    data = json.load(f)

items = [x.value for x in raw_items if x.is_valid()]

if not items:
    return None

# EAFP — Easier to Ask Forgiveness than Permission
try:
    value = cache[key]
except KeyError:
    value = compute(key)
    cache[key] = value

# Walrus operator for compute-and-check
if (match := pattern.search(text)) is not None:
    process(match.group(1))

# Generators for large datasets
def read_large_file(path: Path) -> Iterator[ProcessedLine]:
    with open(path) as f:
        for line in f:
            if processed := parse_line(line.strip()):
                yield processed
```

- [ ] Context managers (`with`) for resource management
- [ ] Comprehensions for simple transforms (list/dict/set)
- [ ] Generators/iterators for large or lazy data
- [ ] EAFP over LBYL where appropriate (try/except vs if-check)
- [ ] Walrus operator (`:=`) used judiciously for assign-and-test
- [ ] `pathlib.Path` instead of `os.path` string manipulation
- [ ] f-strings for formatting (not `%` or `.format()`)
- [ ] `enumerate()` instead of manual index counters, `zip()` for parallel iteration

---

## 4. ERROR HANDLING

```python
# BAD — bare except, swallowed errors
try:
    result = parse_site(url)
except:
    pass

# BAD — print instead of logging
try:
    data = fetch_data(site_id)
except Exception as e:
    print(f"Error: {e}")
    return None


# GOOD — custom exception hierarchy
class AppError(Exception):
    def __init__(self, message: str, code: str | None = None) -> None:
        self.message = message
        self.code = code
        super().__init__(message)

class SiteUnreachableError(AppError):
    def __init__(self, url: str, cause: Exception | None = None) -> None:
        self.url = url
        super().__init__(message=f"Cannot reach site: {url}", code="SITE_UNREACHABLE")
        if cause:
            self.__cause__ = cause

# GOOD — specific exceptions with structured logging
async def fetch_site_data(url: str) -> SiteData:
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(url)
            response.raise_for_status()
    except httpx.ConnectError as exc:
        logger.warning("Connection failed", extra={"url": url, "error": str(exc)})
        raise SiteUnreachableError(url, cause=exc)

    return parse_response(response)

# GOOD — FastAPI exception handler
@app.exception_handler(AppError)
async def app_error_handler(request: Request, exc: AppError) -> JSONResponse:
    return JSONResponse(
        status_code=getattr(exc, "status_code", 500),
        content={"error": exc.code, "detail": exc.message},
    )
```

- [ ] **No bare `except:`** — always catch specific exception types
- [ ] **No empty `except` blocks** — at minimum log the error
- [ ] **Custom exception hierarchy** — base `AppError` with specific subclasses
- [ ] **Exception chaining** — use `raise X from original` to preserve context
- [ ] **Logging with context** — use `extra={}` or structured logging (structlog)
- [ ] **User-facing errors** — return clean JSON/messages, not tracebacks
- [ ] **Technical details** — only in logs, never exposed to API consumers
- [ ] **`contextlib.suppress()`** — for intentionally ignoring specific exceptions

---

## 5. ASYNC PATTERNS

### 5.1 Sync vs Async

```python
# BAD — blocking call inside async function
async def get_site_info(url: str) -> dict:
    response = requests.get(url)  # BLOCKS the event loop!
    return response.json()

# BAD — unnecessary async for CPU-bound work
async def compute_hash(data: str) -> str:
    return hashlib.sha256(data.encode()).hexdigest()


# GOOD — proper async HTTP
async def get_site_info(url: str) -> SiteInfo:
    async with httpx.AsyncClient() as client:
        response = await client.get(url)
        return SiteInfo.model_validate(response.json())

# GOOD — offload CPU-bound work
async def compute_hash(data: str) -> str:
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, partial(hashlib.sha256, data.encode()))

# GOOD — Django sync_to_async for ORM calls
async def get_user_sites(user_id: int) -> list[Site]:
    return await sync_to_async(
        lambda: list(Site.objects.filter(user_id=user_id).select_related("owner"))
    )()
```

- [ ] No `requests` / synchronous HTTP in async code (use `httpx` or `aiohttp`)
- [ ] CPU-bound work offloaded to `run_in_executor`
- [ ] Django ORM calls wrapped in `sync_to_async` in async views
- [ ] No `asyncio.run()` inside already-running event loop
- [ ] Async libraries used where available (`aiofiles`, `aioredis`, `asyncpg`)

### 5.2 Database Access

```python
# BAD — session leak, no cleanup
async def get_user(db: AsyncSession, user_id: int) -> User:
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one()  # Session never closed on error


# GOOD — async session with context manager
async def get_user(user_id: int) -> User | None:
    async with async_session() as session:
        result = await session.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()

# GOOD — FastAPI dependency for session lifecycle
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

- [ ] Async sessions use context managers (`async with`)
- [ ] Session lifecycle managed by dependency injection
- [ ] Transactions committed/rolled back properly
- [ ] Django ORM used synchronously (or wrapped with `sync_to_async`)
- [ ] Connection pools configured (`pool_size`, `max_overflow`)

### 5.3 Resource Management

```python
# BAD — resource leak
async def process_urls(urls: list[str]) -> list[str]:
    client = httpx.AsyncClient()  # Never closed!
    return [await client.get(url) for url in urls]


# GOOD — async context manager, concurrent execution
async def process_urls(urls: list[str]) -> list[str]:
    async with httpx.AsyncClient() as client:
        tasks = [client.get(url) for url in urls]
        responses = await asyncio.gather(*tasks, return_exceptions=True)
        return [r.text for r in responses if isinstance(r, httpx.Response) and r.is_success]

# GOOD — graceful shutdown with signal handling
async def main() -> None:
    loop = asyncio.get_running_loop()
    stop_event = asyncio.Event()
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, stop_event.set)
    server = await start_server()
    await stop_event.wait()
    await server.shutdown()
```

- [ ] `async with` for all async resources (clients, sessions, connections)
- [ ] `asyncio.gather()` with `return_exceptions=True` for concurrent I/O
- [ ] Graceful shutdown handles `SIGINT`/`SIGTERM`
- [ ] Background tasks cancelled on shutdown
- [ ] No fire-and-forget coroutines (`asyncio.create_task` results tracked)
- [ ] `asyncio.TaskGroup` (Python 3.11+) preferred over bare `gather`

---

## 6. DOCUMENTATION

```python
# BAD — no docstring, unclear purpose
def process(data, mode=1):
    if mode == 1:
        return [x * 2 for x in data]
    return [x + 1 for x in data]


# GOOD — Google-style docstring
def transform_measurements(
    raw_data: Sequence[float],
    mode: TransformMode = TransformMode.SCALE,
) -> list[float]:
    """Transform raw measurement data using the specified mode.

    Applies the given transformation to each measurement value.
    Used during the data ingestion pipeline before storage.

    Args:
        raw_data: Raw measurement values from sensors.
        mode: Transformation to apply. Defaults to SCALE.

    Returns:
        Transformed measurement values ready for storage.

    Raises:
        ValueError: If raw_data contains negative values.
    """
    if any(v < 0 for v in raw_data):
        raise ValueError("Measurements cannot be negative")
    return [mode.apply(v) for v in raw_data]
```

- [ ] Public functions/methods have docstrings
- [ ] Docstrings explain **why**, not **what** (type hints show what)
- [ ] Consistent docstring style across project (Google or NumPy)
- [ ] Module-level docstrings for non-obvious modules
- [ ] No commented-out code checked in
- [ ] Comments explain **intent**, not mechanics
- [ ] Type hints are present and serve as inline documentation

---

## 7. SECURITY & PERFORMANCE

### 7.1 Security

```python
# BAD — SQL injection via f-string
result = await db.execute(text(f"SELECT * FROM sites WHERE name LIKE '%{query}%'"))

# BAD — command injection
subprocess.check_output(f"wkhtmltopdf {filename} -", shell=True)

# BAD — no input validation
@router.post("/sites")
async def create_site(data: dict) -> dict:
    site = Site(**data)  # Accepts anything!


# GOOD — ORM parameterized query
result = await db.execute(select(Site).where(Site.name.ilike(f"%{query}%")))

# GOOD — safe subprocess with path validation
safe_path = Path(filename).resolve()
if not safe_path.is_relative_to(REPORTS_DIR):
    raise ValueError("Invalid file path")
subprocess.check_output(["wkhtmltopdf", str(safe_path), "-"], shell=False)

# GOOD — Pydantic validation
class SiteCreate(BaseModel):
    url: HttpUrl
    name: str = Field(min_length=1, max_length=255, pattern=r"^[\w\s-]+$")
```

- [ ] No SQL injection — use ORM queries or parameterized `text()` bindings
- [ ] No command injection — `shell=False`, validate all paths
- [ ] Input validation — Pydantic schemas for all external data
- [ ] No `pickle.load()` on untrusted data
- [ ] No `eval()` / `exec()` with user input
- [ ] CSRF protection enabled (Django `CsrfViewMiddleware`)
- [ ] CORS configured restrictively (not `allow_origins=["*"]` in production)
- [ ] Secrets via environment variables (`pydantic-settings`), not hardcoded
- [ ] Dependencies scanned for vulnerabilities (`pip-audit`, `safety`)
- [ ] Password hashing with `passlib` (bcrypt/argon2), never plaintext

### 7.2 Performance

```python
# BAD — N+1 query
sites = await db.execute(select(Site))
for site in sites.scalars():
    print(site.owner.name)  # Lazy load each iteration

# BAD — loading millions of rows
for user in User.objects.all():
    process(user)


# GOOD — eager loading (SQLAlchemy)
sites = await db.execute(select(Site).options(selectinload(Site.owner)))

# GOOD — eager loading (Django)
sites = Site.objects.select_related("owner").prefetch_related("tags")

# GOOD — chunked processing
for user in User.objects.all().iterator(chunk_size=1000):
    process(user)

# GOOD — async batched processing
result = await db.stream(select(Site))
async for partition in result.partitions(100):
    await asyncio.gather(*[process_site(row) for row in partition])
```

- [ ] No N+1 queries — `selectinload`/`joinedload` or `select_related`/`prefetch_related`
- [ ] QuerySets not evaluated unnecessarily (`.all()` then filter in Python)
- [ ] Pagination for list endpoints (`limit`/`offset` or cursor-based)
- [ ] Heavy operations offloaded to Celery/background tasks
- [ ] Database indexes on frequently filtered/sorted columns
- [ ] Caching strategy (`functools.lru_cache`, Redis)
- [ ] Bulk operations used where possible (`bulk_create`, `bulk_update`)
- [ ] Streaming responses for large payloads (`StreamingResponse`)

---

## 8. SELF-CHECK

**Before adding an issue to the report:**

| Question | If "no" then do not include |
| -------- | ------------------------- |
| Does it affect **functionality** or **maintainability**? | Cosmetics are not critical |
| Will **fixing benefit** developers or users? | Refactoring for the sake of refactoring is a waste |
| Is it a **violation** of project conventions? | Check existing patterns first |
| Is the **time worth** fixing? | 5 min fix vs 1 hour review |

**DO NOT include in report:**

| Seems like a problem | Why it may not be |
| ------------------- | --------------------- |
| "No docstring" | Code may be self-documenting with type hints |
| "Long file" | If logically related — OK |
| "Could be more abstract" | Without specifics not actionable |
| "Not using latest syntax" | Python 3.9 project may not support 3.12 features |
| "Missing `__all__`" | Internal module may not need explicit exports |

**Python-specific false positives:**

| Pattern | When it is acceptable |
| -------- | ---------------------- |
| `type: ignore` comment | When mypy cannot infer types from dynamic library |
| `noqa` comment | When ruff rule conflicts with project convention |
| Mutable default `Field(default_factory=list)` | Pydantic/dataclass handle this correctly |
| `# pragma: no cover` | Unreachable defensive code or platform-specific branches |
| `Any` type | When interfacing with untyped third-party libraries |
| Bare `except Exception` | At top-level request handlers for catch-all logging |

**Checklist:**

```text
[ ] This is a REAL problem, not a preference
[ ] There is a CONCRETE fix suggestion
[ ] The fix WILL NOT BREAK functionality
[ ] This is NOT an intentional design decision
[ ] I checked if the project has a custom ruff/mypy config that allows this
```

---

## 9. REPORT FORMAT

```markdown
# Code Review Report — [Project Name]
Date: [date]
Scope: [which files/commits reviewed]
Python version: [3.x]
Framework: [FastAPI/Django/Flask]

## Summary

| Category | Issues | Critical |
|-----------|---------|-----------|
| Architecture | X | X |
| Code Quality | X | X |
| Error Handling | X | X |
| Async Patterns | X | X |
| Security | X | X |
| Performance | X | X |

## CRITICAL Issues

| # | File | Line | Issue | Solution |
|---|------|------|-------|----------|
| 1 | site_service.py | 45 | Bare except swallows all errors | Catch specific exceptions |
| 2 | views.py | 78 | SQL injection via f-string | Use ORM parameterized query |

## Code Suggestions

### 1. site_service.py — catch specific exceptions

```python
# Before (src/services/site_service.py:45-52)
try:
    result = await self.fetch(url)
except:
    return None

# After
try:
    result = await self.fetch(url)
except httpx.HTTPError as exc:
    logger.warning("Fetch failed", extra={"url": url, "error": str(exc)})
    raise SiteUnreachableError(url) from exc
```text

## Good Practices Found

- [What's good]

```text

---

## 10. ACTIONS

1. **Run Quick Check** — execute the auto-check script (5 minutes)
2. **Define scope** — identify changed files with `git diff`
3. **Go through categories** — Architecture, Code Quality, Error Handling, Async, Security, Performance
4. **Self-check** — filter out false positives using the checklist
5. **Prioritize** — Critical then High then Medium
6. **Show fixes** — specific code before/after with file paths and line numbers

Start code review. Show scope and summary first.
