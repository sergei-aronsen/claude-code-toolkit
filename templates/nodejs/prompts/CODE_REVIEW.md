# Code Review — Node.js Template

## Goal

Comprehensive code review of a Node.js application. Act as a Senior Tech Lead.

> **Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for code review — works better with code analysis.

---

## 0. QUICK CHECK (5 minutes)

| # | Check | Command | Expected |
| --- | ------- | --------- | ---------- |
| 1 | Build | `npm run build` | No errors |
| 2 | Lint | `npx eslint .` | No warnings/errors |
| 3 | Tests | `npm test` | All passing |
| 4 | Types | `npx tsc --noEmit` | No type errors |
| 5 | Debug code | `grep -rn "console.log\|debugger" src/` | None in production code |

---

## 0.1 AUTO-CHECK SCRIPT

```bash
#!/bin/bash
# code-check.sh — Node.js quality gate

echo "=== Code Quality Check ==="

npx tsc --noEmit > /dev/null 2>&1 && echo "PASS TypeScript" || echo "FAIL TypeScript errors"

npx eslint . --quiet > /dev/null 2>&1 && echo "PASS ESLint" || echo "WARN ESLint issues"

npm run build > /dev/null 2>&1 && echo "PASS Build" || echo "FAIL Build failed"

npm test -- --run > /dev/null 2>&1 && echo "PASS Tests" || echo "FAIL Tests failing"

LARGE=$(find src -name "*.ts" -o -name "*.tsx" | xargs wc -l 2>/dev/null | awk '$1 > 300 && !/total/' | wc -l | tr -d ' ')
[ "$LARGE" -eq 0 ] && echo "PASS No large files" || echo "WARN $LARGE files >300 lines"

TODOS=$(grep -rn "TODO\|FIXME" src/ --include="*.ts" --include="*.tsx" 2>/dev/null | wc -l | tr -d ' ')
echo "INFO TODO/FIXME: $TODOS comments"

DEBUG=$(grep -rn "console\.log\|debugger" src/ --include="*.ts" --include="*.tsx" 2>/dev/null | wc -l | tr -d ' ')
[ "$DEBUG" -eq 0 ] && echo "PASS No debug code" || echo "FAIL Debug code: $DEBUG occurrences"

ANY=$(grep -rn ": any\|as any\|<any>" src/ --include="*.ts" --include="*.tsx" 2>/dev/null | wc -l | tr -d ' ')
[ "$ANY" -lt 5 ] && echo "PASS any usage: $ANY" || echo "WARN any usage: $ANY (too many)"

echo "=== Done ==="
```

---

## 0.2 PROJECT SPECIFICS — [Project Name]

**Accepted decisions (no need to fix):**

- [Conscious architectural decisions]

**Key files for review:**

- `src/routes/` — route definitions and handlers
- `src/services/` — business logic
- `src/middleware/` — Express/Fastify middleware
- `src/validators/` — Zod schemas

**Project patterns:**

- Zod for input validation
- Services for business logic
- Middleware for cross-cutting concerns
- Custom AppError for error hierarchy

---

## 0.3 SEVERITY LEVELS

| Level | Description | Action |
| ------- | ---------- | ---------- |
| CRITICAL | Bug, security issue, data loss | **BLOCKER** -- fix now |
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
```

- [ ] Which files changed
- [ ] Which new files created
- [ ] Relationship between changes

### 1.2 Categorization

- [ ] Routes (src/routes/*)
- [ ] Services (src/services/*)
- [ ] Middleware (src/middleware/*)
- [ ] Validators (src/validators/*)
- [ ] Types (src/types/*)
- [ ] Config (src/config/*)
- [ ] Migrations (migrations/*, prisma/migrations/*)
- [ ] Tests (src/**/*.test.ts, tests/*)

---

## 2. ARCHITECTURE & STRUCTURE

### 2.1 Single Responsibility

```typescript
// BAD -- Route handler does everything
router.post('/users', async (req, res) => {
  const { email, name } = req.body;
  if (!email) return res.status(400).json({ error: 'Invalid' });
  const hashed = await bcrypt.hash(req.body.password, 10);
  const user = await db.query('INSERT INTO users ...', [email, name, hashed]);
  await sendWelcomeEmail(user.rows[0]);
  res.status(201).json(user.rows[0]);
});

// GOOD -- Route handler only coordinates
router.post('/users', validate(CreateUserSchema), asyncHandler(async (req, res) => {
  const user = await userService.create(req.body);
  res.status(201).json(user);
}));
```

- [ ] Route handlers < 20 lines
- [ ] Business logic in services, not in route handlers
- [ ] Validation in dedicated middleware or Zod schemas
- [ ] One module -- one clear responsibility
- [ ] Barrel exports (`index.ts`) do not re-export entire modules blindly

### 2.2 Dependency Injection

```typescript
// BAD -- hardcoded dependencies
class UserService {
  async findAll(): Promise<User[]> {
    const prisma = new PrismaClient(); // Created per call
    return prisma.user.findMany();
  }
}

// GOOD -- DI via constructor or factory
class UserService {
  constructor(private readonly db: PrismaClient, private readonly mailer: MailService) {}
  async findAll(): Promise<User[]> { return this.db.user.findMany(); }
}

export function createUserService(deps: { db: PrismaClient; mailer: MailService }) {
  return new UserService(deps.db, deps.mailer);
}
```

- [ ] Dependencies injected via constructor or factory function
- [ ] No `new ClassName()` for services inside methods
- [ ] Database clients shared, not created per-call

### 2.3 Proper Placement

```text
src/
├── routes/              # Route definitions only
├── controllers/         # Request/response handling
├── services/            # Business logic
├── middleware/           # Cross-cutting concerns (auth, errors, validation)
├── validators/          # Zod schemas
├── types/               # TypeScript interfaces and types
├── utils/               # Pure helper functions
├── config/              # Environment and app config
├── jobs/                # Background task processors
└── index.ts             # App entry point
```

- [ ] Files in correct directories
- [ ] No God-modules (> 300 lines)
- [ ] Logic extracted from route handlers
- [ ] Shared types in `types/`, not scattered across modules

### 2.4 Node.js-Specific Patterns

```typescript
// BAD -- middleware does not propagate errors
app.use((req, res, next) => {
  const user = jwt.verify(req.headers.authorization, SECRET); // Can throw!
  req.user = user;
  next();
});

// GOOD -- async/await with error propagation
app.use(async (req: Request, res: Response, next: NextFunction) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');
    if (!token) throw new AppError(401, 'No token', 'AUTH_NO_TOKEN');
    req.user = jwt.verify(token, SECRET) as TokenPayload;
    next();
  } catch (error) { next(error); }
});
```

- [ ] Async/await used consistently (no mixing callbacks and promises)
- [ ] Errors propagated through middleware chain via `next(error)`
- [ ] Middleware order correct (auth before handlers, error handler last)
- [ ] Graceful shutdown handling (SIGTERM, SIGINT)

---

## 3. CODE QUALITY

### 3.1 Naming Conventions

```typescript
// BAD                              // GOOD
const d = await repo.get(id);      const user = await repo.findById(userId);
type user_input = {};               type UserInput = {};
```

- [ ] **Variables** -- nouns, camelCase: `userId`, `parsedContent`
- [ ] **Functions** -- verbs, camelCase: `getUser()`, `parseContent()`
- [ ] **Classes** -- PascalCase: `UserService`, **Types** -- PascalCase: `UserResponse`
- [ ] **Constants** -- UPPER_SNAKE_CASE: `MAX_RETRIES`
- [ ] **Files** -- kebab-case: `user-service.ts`
- [ ] **Boolean** -- is/has/can/should prefix: `isActive`, `hasPermission`

### 3.2 Complexity

```typescript
// BAD -- deep nesting
for (const order of orders) {
  if (order.status === 'pending') {
    if (order.items.length > 0) {
      for (const item of order.items) {
        if (item.stock > 0) { /* ... */ }
      }
    }
  }
}

// GOOD -- extracted + flat
const pending = orders.filter(isPendingWithItems);
return Promise.all(pending.map(processOrder));
```

- [ ] Functions < 20 lines (ideally < 10)
- [ ] Nesting < 3 levels
- [ ] Early returns are used
- [ ] No nested ternaries: `a ? b ? c : d : e`

### 3.3 DRY

```typescript
// BAD -- duplicated queries
async function getActiveUsers() {
  return prisma.user.findMany({ where: { status: 'active', deletedAt: null } });
}
async function getPendingUsers() {
  return prisma.user.findMany({ where: { status: 'pending', deletedAt: null } });
}

// GOOD -- parameterized
async function getUsersByStatus(status: UserStatus) {
  return prisma.user.findMany({ where: { status, deletedAt: null } });
}
```

- [ ] No copy-paste code
- [ ] Repeated query logic extracted to repository or helper
- [ ] Shared Zod schemas reuse base via `.extend()` or `.merge()`

### 3.4 Type Safety

```typescript
// BAD
function process(data: any): any { return { name: data.name }; }
const config = JSON.parse(raw); // untyped

// GOOD
function process(data: ProcessInput): ProcessResult {
  return { displayName: data.name.trim(), normalizedEmail: data.email.toLowerCase() };
}
const config = ConfigSchema.parse(JSON.parse(raw));
```

- [ ] No `any` usage (use `unknown` with type guards)
- [ ] All parameters and return types explicitly typed
- [ ] Zod for runtime validation at trust boundaries
- [ ] `as` assertions minimized (prefer type guards)
- [ ] Generics have proper constraints
- [ ] `strict: true` in `tsconfig.json`

### 3.5 Node.js Idioms

```typescript
// BAD -- sequential when parallel is possible
const users = await getUsers();
const orders = await getOrders();

// GOOD -- parallel
const [users, orders] = await Promise.all([getUsers(), getOrders()]);

// GOOD -- controlled concurrency
import pMap from 'p-map';
const results = await pMap(urls, (url) => fetch(url), { concurrency: 5 });
```

- [ ] `Promise.all` for independent parallel operations
- [ ] Controlled concurrency for batch processing (p-map, p-limit)
- [ ] No mixing `async/await` with `.then()` chains
- [ ] `for...of` instead of `.forEach()` for async iteration

---

## 4. ERROR HANDLING

### 4.1 Custom Error Hierarchy

```typescript
export class AppError extends Error {
  constructor(
    public readonly statusCode: number,
    message: string,
    public readonly code: string,
    public readonly details?: Record<string, unknown>
  ) {
    super(message);
    this.name = 'AppError';
  }
  static notFound(resource: string, id: string) {
    return new AppError(404, `${resource} not found`, 'NOT_FOUND', { resource, id });
  }
  static forbidden(msg = 'Access denied') { return new AppError(403, msg, 'FORBIDDEN'); }
}
```

- [ ] Custom AppError with status code and error code
- [ ] Factory methods for common error types
- [ ] Error codes are machine-readable strings
- [ ] Errors carry structured context for logging

### 4.2 Async Error Middleware

```typescript
// Centralized async wrapper
const asyncHandler = (fn: RequestHandler) =>
  (req: Request, res: Response, next: NextFunction) =>
    Promise.resolve(fn(req, res, next)).catch(next);

// Error middleware (registered last)
app.use((err: Error, req: Request, res: Response, _next: NextFunction) => {
  if (err instanceof AppError) {
    logger.warn({ err, path: req.path }, 'Application error');
    return res.status(err.statusCode).json({ error: { message: err.message, code: err.code } });
  }
  logger.error({ err, path: req.path }, 'Unhandled error');
  res.status(500).json({ error: { message: 'Internal server error' } });
});
```

- [ ] `asyncHandler` wrapper for all async route handlers
- [ ] Centralized error middleware registered last
- [ ] Unknown errors return 500 without leaking stack traces

### 4.3 Unhandled Rejections and Process Errors

```typescript
process.on('unhandledRejection', (reason) => { logger.fatal({ reason }, 'Unhandled rejection'); process.exit(1); });
process.on('uncaughtException', (error) => { logger.fatal({ error }, 'Uncaught exception'); process.exit(1); });

async function shutdown(signal: string) {
  logger.info({ signal }, 'Shutting down');
  await server.close();
  await db.disconnect();
  process.exit(0);
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
```

- [ ] `unhandledRejection` and `uncaughtException` handlers registered
- [ ] Graceful shutdown on SIGTERM/SIGINT
- [ ] No `process.exit()` scattered throughout the codebase

### 4.4 Try/Catch Patterns

```typescript
// BAD
try { await sendNotification(user); } catch { /* Silence */ }
try { return await svc.find(id); } catch (e) { throw e; } // Pointless

// GOOD -- catch adds value
try {
  await externalApi.notify(user.email);
} catch (error) {
  logger.warn({ userId: user.id, error }, 'Notification failed, queuing retry');
  await retryQueue.add('notification', { userId: user.id });
}
```

- [ ] No empty catch blocks
- [ ] Catch blocks add value (logging, transformation, recovery)
- [ ] Errors logged with context (userId, operation, etc.)

---

## 5. ASYNC PATTERNS

### 5.1 Event Loop Safety

```typescript
// BAD -- blocking the event loop
app.get('/report', (req, res) => {
  const data = readFileSync('large.csv', 'utf-8'); // Blocks!
  res.json(data.split('\n').map(heavyComputation));
});

// GOOD -- non-blocking
app.get('/report', asyncHandler(async (req, res) => {
  const stream = createReadStream('large.csv');
  const results = await processStream(stream);
  res.json(results);
}));
```

- [ ] No `*Sync` functions in request handlers (`readFileSync`, `writeFileSync`)
- [ ] No synchronous crypto (`pbkdf2Sync`, `randomBytesSync`)
- [ ] CPU-intensive ops offloaded to worker threads
- [ ] No large `JSON.parse`/`JSON.stringify` in hot paths

### 5.2 Promise Handling

```typescript
// BAD -- missing await (fire-and-forget rejection)
async function processUser(id: string) { sendEmail(id); }

// BAD -- Promise.all loses partial results
await Promise.all(users.map(riskyOp));

// GOOD -- handle partial failures
const results = await Promise.allSettled(users.map(riskyOp));
const failed = results.filter((r) => r.status === 'rejected');

// GOOD -- bounded concurrency
import pLimit from 'p-limit';
const limit = pLimit(10);
await Promise.all(urls.map((url) => limit(() => fetch(url))));
```

- [ ] All promises awaited (no fire-and-forget without explicit void)
- [ ] `Promise.allSettled` when partial failure is acceptable
- [ ] Concurrent operations bounded with p-limit or p-map

### 5.3 Memory Leaks

```typescript
// BAD -- listener never removed
client.on('message', (data) => this.process(data));

// GOOD -- cleanup on disconnect
const handler = (data: unknown) => this.process(data);
client.on('message', handler);
// later: client.off('message', handler);

// BAD -- unbounded cache
const cache: Record<string, unknown> = {};

// GOOD -- bounded with TTL
import { LRUCache } from 'lru-cache';
const cache = new LRUCache<string, unknown>({ max: 1000, ttl: 5 * 60_000 });
```

- [ ] Event listeners removed on cleanup (`.off()`, `AbortController`)
- [ ] Caches bounded with max size and TTL
- [ ] Streams used for large file/data processing
- [ ] No global arrays/objects that grow unbounded
- [ ] `setInterval`/`setTimeout` cleared on shutdown

---

## 6. DOCUMENTATION

### 6.1 JSDoc and Code Comments

```typescript
/**
 * Processes user data and returns a normalized profile.
 *
 * @param data - Raw user data from external API
 * @param opts - Processing options
 * @returns Normalized user profile ready for storage
 * @throws {AppError} When data fails validation (400)
 */
export async function processUserData(
  data: ExternalUserData, opts: ProcessOptions
): Promise<UserProfile> { /* ... */ }
```

- [ ] Public API functions have JSDoc with `@param`, `@returns`, `@throws`
- [ ] Comments explain "why", not "what"
- [ ] No commented-out code (use version control)

### 6.2 TypeScript Interfaces as Documentation

```typescript
interface AppConfig {
  /** Port the HTTP server listens on */
  port: number;
  /** PostgreSQL connection string */
  databaseUrl: string;
  /** JWT signing secret (min 32 chars) */
  jwtSecret: string;
}

const EnvSchema = z.object({
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
});
```

- [ ] Configuration objects have TypeScript interfaces
- [ ] Interface properties have doc comments for non-obvious fields
- [ ] Zod schemas serve as runtime documentation
- [ ] API request/response types defined and exported

---

## 7. SECURITY & PERFORMANCE

### 7.1 Security Quick Check

```typescript
// BAD -- SQL injection / command injection
await db.query(`SELECT * FROM users WHERE name = '${req.query.name}'`);
exec(`convert ${req.body.filename} output.png`);

// GOOD -- ORM + safe args
await prisma.user.findMany({ where: { name: req.query.name } });
execFile('convert', [validatedFilename, 'output.png']);

// GOOD -- security hardened setup
app.use(helmet());
app.use(cors({ origin: config.allowedOrigins }));
app.use(express.json({ limit: '10kb' }));
app.use('/api/', rateLimit({ windowMs: 15 * 60 * 1000, max: 100 }));
```

- [ ] No SQL injection (use Prisma/Drizzle/Knex, never concatenation)
- [ ] No command injection (`execFile`, never `exec` with user input)
- [ ] No XSS (avoid `dangerouslySetInnerHTML`)
- [ ] `helmet` middleware for HTTP security headers
- [ ] CORS with explicit allowed origins (not `*` in production)
- [ ] Rate limiting on public endpoints
- [ ] Request body size limited
- [ ] No secrets in source code
- [ ] Sensitive data not logged (passwords, tokens, PII)

### 7.2 Performance Quick Check

```typescript
// BAD -- N+1 query
const users = await prisma.user.findMany();
for (const u of users) { u.posts = await prisma.post.findMany({ where: { authorId: u.id } }); }

// GOOD -- eager loading + pagination
const users = await prisma.user.findMany({ include: { posts: true } });
const orders = await prisma.order.findMany({
  skip: (page - 1) * pageSize, take: pageSize, orderBy: { createdAt: 'desc' },
});
```

- [ ] No N+1 queries (use `include`, `join`, or DataLoader)
- [ ] Pagination for list endpoints
- [ ] Streaming for large data responses
- [ ] Database connection pooling configured
- [ ] Heavy computation offloaded (worker threads, job queue)
- [ ] `Cache-Control` headers for static/semi-static responses
- [ ] No redundant `await` in return statements (only needed in try/catch)

---

## 8. SELF-CHECK

**Before adding an issue to the report:**

| Question | If "no" -- do not include |
| -------- | ------------------------- |
| Does it affect **functionality** or **maintainability**? | Cosmetics are not critical |
| Will **fixing benefit** developers or users? | Refactoring for its own sake is a waste |
| Is it a **violation** of project conventions? | Check existing patterns |
| Is the **time worth** fixing? | 5 min fix vs 1 hour review |

**DO NOT include in report:**

| Seems like a problem | Why it may not be |
| ------------------- | --------------------- |
| "No comments" | Code is self-documenting with TypeScript types |
| "Long file" | If logically related -- OK |
| "Could be better" | Without specifics not actionable |
| "Uses callbacks" | Some Node.js APIs require them (streams, EventEmitter) |
| "Not using class" | Functional modules are idiomatic Node.js |
| "`return await`" | Needed inside try/catch for correct stack traces |

**Checklist:**

```text
[] This is a REAL problem, not a style preference
[] There is a CONCRETE suggestion for fix
[] The fix will NOT BREAK functionality
[] This is NOT an intentional design decision
```

---

## 9. REPORT FORMAT

```markdown
# Code Review Report -- [Project Name]
Date: [date]
Scope: [which files/commits reviewed]

## Summary

| Category | Issues | Critical |
|-----------|---------|-----------|
| Architecture | X | X |
| Code Quality | X | X |
| Type Safety | X | X |
| Error Handling | X | X |
| Async Patterns | X | X |
| Security | X | X |
| Performance | X | X |

## CRITICAL Issues

| # | File | Line | Issue | Solution |
|---|------|--------|----------|---------|
| 1 | user-service.ts | 45 | Unhandled promise | Add await or void |

## Code Suggestions

### 1. user-service.ts -- add proper error handling

```typescript
// Before (src/services/user-service.ts:45)
async function createUser(data: CreateUserInput): Promise<User> {
  const user = await prisma.user.create({ data });
  sendWelcomeEmail(user.email); // Unhandled!
  return user;
}

// After
async function createUser(data: CreateUserInput): Promise<User> {
  const user = await prisma.user.create({ data });
  await emailQueue.add('welcome', { email: user.email });
  return user;
}
```text

## Good Practices Found

- Consistent use of asyncHandler wrapper
- Well-structured error hierarchy with AppError
- TypeScript strict mode enabled

```text

---

## 10. ACTIONS

1. **Run Quick Check** -- 5 minutes (build, lint, tests, types)
2. **Define scope** -- which files and commits to review
3. **Go through categories** -- Architecture, Code Quality, Type Safety, Error Handling, Async, Security, Performance
4. **Self-check** -- filter out false positives and style preferences
5. **Prioritize** -- Critical then High then Medium
6. **Show fixes** -- specific TypeScript code before/after

Start code review. Show scope and summary first.
