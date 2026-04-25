# Code Review — Python Template

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

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

## 8. SELF-CHECK (FP Recheck — 6-Step Procedure)
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

## 9. OUTPUT FORMAT (Structured Report Schema — Phase 14)
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

1. **Run Quick Check** — execute the auto-check script (5 minutes)
2. **Define scope** — identify changed files with `git diff`
3. **Go through categories** — Architecture, Code Quality, Error Handling, Async, Security, Performance
4. **Self-check** — filter out false positives using the checklist
5. **Prioritize** — Critical then High then Medium
6. **Show fixes** — specific code before/after with file paths and line numbers

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
