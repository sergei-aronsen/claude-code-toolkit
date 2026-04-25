# Security Audit — Node.js Template

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

## Goal

Comprehensive security audit of a Node.js application (Express/Fastify). Act as a Senior Security Engineer.

> **Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for audits.

---

## 0. QUICK CHECK (5 minutes)

| # | Check | Command | Expected |
| --- | ------- | --------- | ---------- |
| 1 | Auth on API | `grep -rn "router\.\(get\|post\|put\|delete\)" src/ --include="*.ts" \| grep -v "auth\|middleware"` | Verify protection |
| 2 | Secrets in code | `grep -rn "sk-\|password.*=.*['\"]" src/ --include="*.ts"` | Empty |
| 3 | SQL injection | `grep -rn "SELECT.*\${\|query(.*\${" src/ --include="*.ts"` | Empty |
| 4 | npm audit | `npm audit --production` | No critical/high |
| 5 | Hardcoded keys | `grep -rn "API_KEY.*=.*['\"][a-zA-Z0-9]" src/ --include="*.ts"` | Empty |
| 6 | Secret key | `echo $JWT_SECRET \| wc -c` | >= 32 characters |
| 7 | Open redirect | `grep -rn "redirect.*req\.\|redirect.*query\." src/ --include="*.ts"` | Check validation |
| 8 | .env public | Verify `.env` not in public/ or dist/ | Not accessible |

If all 8 = OK → Basic security level OK.

---

## 0.1 AUTO-CHECK SCRIPT

```bash
#!/bin/bash
# security-check.sh

echo "Security Quick Check — Node.js..."

# 1. Unprotected routes (need manual review)
ROUTES=$(grep -rn "router\.\(get\|post\|put\|delete\)" src/ --include="*.ts" 2>/dev/null | wc -l)
echo "Found $ROUTES route definitions (verify auth middleware)"

# 2. Hardcoded secrets
SECRETS=$(grep -rn "sk-\|api_key.*=.*['\"][a-zA-Z0-9]" src/ --include="*.ts" 2>/dev/null | grep -v "process.env")
[ -z "$SECRETS" ] && echo "Secrets: No hardcoded keys" || echo "Secrets: Found hardcoded keys!"

# 3. SQL injection patterns
SQLI=$(grep -rn 'SELECT.*\${\|INSERT.*\${\|UPDATE.*\${' src/ --include="*.ts" 2>/dev/null)
[ -z "$SQLI" ] && echo "SQL: No injection patterns" || echo "SQL: Potential injection!"

# 4. npm audit
npm audit --production 2>/dev/null | grep -q "critical\|high" && echo "NPM: Critical vulnerabilities" || echo "NPM: No critical issues"

# 5. eval/exec usage
EXEC=$(grep -rn "eval(\|exec(\|execSync(" src/ --include="*.ts" 2>/dev/null)
[ -z "$EXEC" ] && echo "Exec: No dangerous exec/eval" || echo "Exec: Found dangerous patterns!"

# 6. Missing Zod validation
ZOD=$(grep -rn "req.body\|req.params\|req.query" src/ --include="*.ts" 2>/dev/null | grep -v "\.parse\|\.safeParse\|validate")
[ -z "$ZOD" ] && echo "Validation: All inputs validated" || echo "Validation: Unvalidated inputs found"

# 7. Secret key strength
SECRET_LEN=$(echo -n "$JWT_SECRET" | wc -c)
[ "$SECRET_LEN" -ge 32 ] && echo "✅ Secret: JWT_SECRET is strong (${SECRET_LEN} chars)" || echo "❌ Secret: JWT_SECRET too short (${SECRET_LEN} chars, need >= 32)"

# 8. Open redirect
REDIRECT=$(grep -rn "res.redirect.*req\.\|redirect.*req.query\|redirect.*req.params" src/ --include="*.ts" 2>/dev/null)
[ -z "$REDIRECT" ] && echo "✅ Redirect: No open redirect patterns" || echo "🟡 Redirect: Found redirect patterns (verify validation)"

# 9. Dangerous functions
DANGEROUS=$(grep -rn "eval(\|new Function(\|child_process\.exec(\|require(.*req\.\|vm\.run" src/ 2>/dev/null | grep -v "node_modules\|test\|spec")
[ -z "$DANGEROUS" ] && echo "✅ Functions: No dangerous patterns" || echo "🟡 Functions: Found dangerous function patterns (verify input)"

# 10. Unsafe deserialization
DESER=$(grep -rn "node-serialize\|unserialize\|yaml\.load" src/ 2>/dev/null | grep -v "node_modules\|test\|spec")
[ -z "$DESER" ] && echo "✅ Deserialization: No unsafe patterns" || echo "🟡 Deserialization: Found patterns (verify safety)"

echo "Done!"
```

---

## 0.2 PROJECT SPECIFICS

**Fill out before audit:**

**What is already implemented:**

- [ ] Authentication: [JWT / Session / OAuth]
- [ ] Authorization: [Middleware / RBAC / ABAC]
- [ ] Input validation: [Zod / Joi / class-validator]
- [ ] ORM: [Prisma / Drizzle / Knex / raw SQL]

**Public endpoints (by design):**

- `/health` — health check
- `/api/webhooks/*` — webhooks (verify signature!)

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

### 1.1 Zod Validation

```typescript
// CRITICAL — no validation
app.post('/users', async (req, res) => {
  const user = await db.createUser(req.body);  // Anything goes!
});

// Good — Zod validation
import { z } from 'zod';

const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(2).max(100),
  age: z.number().int().positive().optional(),
});

app.post('/users', async (req, res) => {
  const parsed = CreateUserSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ errors: parsed.error.flatten() });
  }
  const user = await db.createUser(parsed.data);
});
```

- [ ] All endpoints validate input via Zod
- [ ] String fields have max length
- [ ] Number fields have boundaries

### 1.2 Params/Query Validation

```typescript
// CRITICAL — SQL injection via params
app.get('/users/:id', async (req, res) => {
  const user = await db.query(`SELECT * FROM users WHERE id = ${req.params.id}`);
});

// Good — validation + prepared statements
const IdSchema = z.object({ id: z.string().uuid() });

app.get('/users/:id', async (req, res) => {
  const { id } = IdSchema.parse(req.params);
  const user = await prisma.user.findUnique({ where: { id } });
});
```

- [ ] URL params are validated
- [ ] Query strings are validated
- [ ] UUID/ID format is checked

---

## 2. SQL INJECTION

### 2.1 Raw Queries

```typescript
// CRITICAL — SQL Injection
const users = await db.query(
  `SELECT * FROM users WHERE email = '${email}'`
);

// CRITICAL — template literals
const result = await db.query(`SELECT * FROM users WHERE name LIKE '%${search}%'`);

// Good — parameterized queries
const users = await db.query(
  'SELECT * FROM users WHERE email = $1',
  [email]
);

// Better — use ORM
const users = await prisma.user.findMany({
  where: { email },
});
```

- [ ] No string concatenation in SQL
- [ ] No template literals with user input in SQL
- [ ] ORM is used (Prisma/Drizzle)

### 2.2 Dynamic Queries

```typescript
// CRITICAL — user controls ORDER BY
const sortBy = req.query.sort;
const users = await db.query(`SELECT * FROM users ORDER BY ${sortBy}`);

// Good — whitelist
const ALLOWED_SORT = ['created_at', 'name', 'email'] as const;
const sortBy = ALLOWED_SORT.includes(req.query.sort) ? req.query.sort : 'created_at';
```

- [ ] Column names from whitelist
- [ ] Table names never from user input

---

## 3. COMMAND INJECTION

### 3.1 exec/spawn

```typescript
// CRITICAL — Command Injection
import { exec } from 'child_process';

app.post('/convert', async (req, res) => {
  const { filename } = req.body;
  exec(`convert ${filename} output.pdf`);  // Full control!
});

// Good — whitelist + escaping
import { execFile } from 'child_process';

const ALLOWED_EXTENSIONS = ['.jpg', '.png', '.gif'];

app.post('/convert', async (req, res) => {
  const filename = path.basename(req.body.filename);  // Sanitize
  const ext = path.extname(filename);

  if (!ALLOWED_EXTENSIONS.includes(ext)) {
    return res.status(400).json({ error: 'Invalid file type' });
  }

  execFile('convert', [filename, 'output.pdf']);  // Safer
});
```

- [ ] No exec() with user input
- [ ] execFile() used instead of exec()
- [ ] Filenames sanitized via path.basename()

### 3.2 Unsafe Deserialization

Deserializing untrusted data in Node.js can lead to remote code execution.

```javascript
// ❌ Dangerous — node-serialize, js-yaml with unsafe loader
const serialize = require('node-serialize');
serialize.unserialize(userInput);  // RCE!

const yaml = require('js-yaml');
yaml.load(userInput);  // Unsafe by default in older versions

// ✅ Safe
JSON.parse(userInput);                    // Data-only
yaml.load(userInput, { schema: yaml.JSON_SCHEMA });  // Safe schema
```

- [ ] No `node-serialize` package (known RCE vulnerability)
- [ ] `js-yaml` uses safe schema (`JSON_SCHEMA` or `FAILSAFE_SCHEMA`)
- [ ] No `eval()` or `vm.runInContext()` with user data
- [ ] Cookie data is not deserialized without signature verification

### 3.3 Dangerous Functions

Some Node.js functions allow arbitrary code execution.

```javascript
// ❌ Never use with user input
eval(userInput)
new Function(userInput)
child_process.exec(userInput)        // Shell injection!
setTimeout(userInput, 0)             // String form executes code
require(userInput)                   // Arbitrary module load
vm.runInContext(userInput, context)   // Sandbox escape possible

// ✅ Safe alternatives
child_process.execFile('cmd', [arg1, arg2])  // No shell
child_process.spawn('cmd', [arg1], { shell: false })
```

- [ ] No `eval()` with user-controlled input
- [ ] No `new Function()` with user input
- [ ] No `child_process.exec()` with user input (use `execFile` or `spawn`)
- [ ] No `require()` with dynamic user-controlled paths
- [ ] No `vm` module with user-controlled code

---

## 4. AUTHENTICATION

### 4.1 JWT Security

```typescript
// CRITICAL — weak secret
const token = jwt.sign(payload, 'secret123');

// CRITICAL — algorithm none
jwt.verify(token, secret, { algorithms: ['none', 'HS256'] });

// Good
const token = jwt.sign(payload, process.env.JWT_SECRET!, {
  algorithm: 'HS256',
  expiresIn: '1h',
});

jwt.verify(token, process.env.JWT_SECRET!, {
  algorithms: ['HS256'],  // Only allowed algorithms
});
```

- [ ] JWT secret minimum 32 characters
- [ ] Algorithm explicitly specified (not 'none')
- [ ] Token has expiresIn

### 4.2 Password Hashing

```typescript
// CRITICAL — plain text
await db.createUser({ password: req.body.password });

// CRITICAL — weak hash
const hash = crypto.createHash('md5').update(password).digest('hex');

// ✅ BEST — Argon2id (OWASP recommended)
import argon2 from 'argon2';

const hash = await argon2.hash(password, {
  type: argon2.argon2id,
  memoryCost: 65536,  // 64MB
  timeCost: 3,
  parallelism: 4,
});
const isValid = await argon2.verify(hash, password);

// ✅ Good — bcrypt (acceptable alternative)
import bcrypt from 'bcrypt';

const hash = await bcrypt.hash(password, 12);  // Min 12 rounds
const isValid = await bcrypt.compare(password, hash);
```

- [ ] Passwords hashed with Argon2id (preferred) or bcrypt (rounds >= 12)
- [ ] No MD5/SHA1/SHA256 for passwords
- [ ] Use timing-safe comparison for tokens

---

## 5. AUTHORIZATION

### 5.1 Resource Access

```typescript
// CRITICAL — no ownership check
app.get('/documents/:id', async (req, res) => {
  const doc = await prisma.document.findUnique({ where: { id: req.params.id } });
  res.json(doc);  // Anyone can get any document!
});

// Good — ownership check
app.get('/documents/:id', auth, async (req, res) => {
  const doc = await prisma.document.findFirst({
    where: {
      id: req.params.id,
      userId: req.user.id,  // Only own documents
    },
  });

  if (!doc) {
    return res.status(404).json({ error: 'Not found' });
  }

  res.json(doc);
});
```

- [ ] All protected routes check auth
- [ ] Resource ownership is verified
- [ ] No access to other users' data

---

## 6. XSS PROTECTION

### 6.1 HTML Output

```typescript
// CRITICAL — XSS
app.get('/user/:name', (req, res) => {
  res.send(`<h1>Hello, ${req.params.name}</h1>`);
  // name: <script>alert('XSS')</script>
});

// Good — escaping
import escape from 'escape-html';

app.get('/user/:name', (req, res) => {
  res.send(`<h1>Hello, ${escape(req.params.name)}</h1>`);
});

// Better — use template engine with auto-escaping
```

- [ ] No direct output of user input in HTML
- [ ] Template engine with auto-escaping is used

### 6.2 Security Headers (helmet.js)

```typescript
import helmet from 'helmet';

app.use(helmet());
app.use(helmet.contentSecurityPolicy({
  directives: {
    defaultSrc: ["'self'"],
    scriptSrc: ["'self'"],
  },
}));
```

- [ ] helmet.js installed and configured
- [ ] CSP configured

### 6.3 HSTS (HTTP Strict Transport Security)

helmet.js enables HSTS by default, but verify configuration.

```typescript
// ✅ Verify helmet HSTS settings
app.use(helmet({
  hsts: {
    maxAge: 31536000,        // 1 year
    includeSubDomains: true,
    preload: true,
  },
}));

// Or manually
app.use((req, res, next) => {
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');
  next();
});
```

- [ ] HSTS enabled (helmet enables by default)
- [ ] `max-age` >= 31536000
- [ ] `includeSubDomains` set if applicable

---

## 7. RATE LIMITING

```typescript
// CRITICAL — no rate limiting
app.post('/login', async (req, res) => {
  // Brute force possible
});

// Good — rate limiting
import rateLimit from 'express-rate-limit';

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 minutes
  max: 5,  // 5 attempts
  message: { error: 'Too many attempts' },
});

app.post('/login', loginLimiter, async (req, res) => {
  // ...
});
```

- [ ] Login endpoint has rate limiting
- [ ] Sensitive endpoints protected
- [ ] Rate limit by IP + user ID

---

## 8. SECRETS MANAGEMENT

```typescript
// CRITICAL — hardcoded
const stripe = new Stripe('sk_live_xxxxx');

// CRITICAL — in code
const API_KEY = 'sk-ant-xxxxx';

// Good — env variables
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);
```

- [ ] No hardcoded secrets
- [ ] All keys through process.env
- [ ] .env in .gitignore

### 8.2 Secret Key Validation

```typescript
// ❌ Weak secret
const JWT_SECRET = 'secret';
const JWT_SECRET = process.env.JWT_SECRET || 'fallback'; // Fallback is weak!

// ✅ Strong secret with validation
const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET || JWT_SECRET.length < 32) {
  throw new Error('JWT_SECRET must be at least 32 characters');
}
```

- [ ] JWT/session secret is at least 32 characters
- [ ] No weak fallback values
- [ ] Secret validation on application startup
- [ ] Different secrets per environment

### 8.3 Session Timeout

```typescript
// express-session
app.use(session({
  cookie: {
    maxAge: 30 * 60 * 1000,  // ✅ 30 minutes
    secure: true,
    httpOnly: true,
    sameSite: 'lax',
  },
  rolling: true,  // ✅ Reset timeout on activity
}));

// JWT — set short expiration
const token = jwt.sign(payload, secret, {
  expiresIn: '30m',  // ✅ 30 minutes
});
```

- [ ] Session/cookie `maxAge` is configured (not infinite)
- [ ] JWT `expiresIn` is set (recommended: 15-60 minutes)
- [ ] Refresh token mechanism for longer sessions

---

## 9. DEPENDENCY SECURITY

```bash
npm audit
npm audit --production
```

- [ ] `npm audit` without critical/high
- [ ] Dependencies updated
- [ ] No deprecated packages

---

## 10. FILE UPLOAD

```typescript
// CRITICAL — no validation
app.post('/upload', upload.single('file'), async (req, res) => {
  // Any file accepted
});

// Good — validation
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'application/pdf'];
const MAX_SIZE = 10 * 1024 * 1024;  // 10MB

const upload = multer({
  limits: { fileSize: MAX_SIZE },
  fileFilter: (req, file, cb) => {
    if (!ALLOWED_TYPES.includes(file.mimetype)) {
      cb(new Error('Invalid file type'));
      return;
    }
    cb(null, true);
  },
});
```

- [ ] File type is validated
- [ ] File size is limited
- [ ] Filename is generated (not user input)

### 10.1 Open Redirection

```typescript
// ❌ Dangerous — redirect to user-supplied URL
app.get('/callback', (req, res) => {
  res.redirect(req.query.returnUrl as string); // Open redirect!
});

// ✅ Safe — validate URL
const ALLOWED_HOSTS = ['myapp.com', 'www.myapp.com'];

app.get('/callback', (req, res) => {
  const returnUrl = req.query.returnUrl as string;
  try {
    const url = new URL(returnUrl, 'https://myapp.com');
    if (!ALLOWED_HOSTS.includes(url.hostname)) {
      return res.redirect('/');
    }
    res.redirect(returnUrl);
  } catch {
    res.redirect('/');
  }
});
```

- [ ] No `res.redirect()` with raw user input
- [ ] Redirect URLs validated against whitelist or restricted to relative paths

### 10.2 Host Injection

```typescript
// ❌ Dangerous — trusting Host header
app.post('/forgot-password', (req, res) => {
  const host = req.headers.host;
  const resetLink = `https://${host}/reset?token=${token}`; // Spoofable!
  sendEmail(user.email, resetLink);
});

// ✅ Safe — use configured base URL
const BASE_URL = process.env.APP_URL;

app.post('/forgot-password', (req, res) => {
  const resetLink = `${BASE_URL}/reset?token=${token}`;
  sendEmail(user.email, resetLink);
});
```

- [ ] Password reset links use configured `APP_URL`, not `req.headers.host`
- [ ] Email links use configured base URL
- [ ] Consider using a host validation middleware

### 10.3 .env Public Access

```typescript
// ❌ Bad — serving static files from root
app.use(express.static('.'));  // Exposes .env!

// ✅ Good — serve only public/ directory
app.use(express.static('public'));
```

- [ ] `.env` is not served by static file middleware
- [ ] Static file serving restricted to specific directory (public/, dist/, static/)
- [ ] `.env` in `.gitignore`

### 10.4 File Permissions

- [ ] `.env` file permissions: `600` or `640`
- [ ] Log directory is not world-writable
- [ ] Upload directory does not allow script execution
- [ ] Node.js process runs as non-root user

---

## 11. SSRF (Server-Side Request Forgery)

If the application fetches URLs provided by users, attackers can target internal services or cloud metadata endpoints.

```javascript
// ❌ Dangerous — SSRF
app.post('/fetch', async (req, res) => {
  const response = await fetch(req.body.url); // Can access internal services!
  res.json(await response.json());
});

// ✅ Safe — validate URL
const BLOCKED_HOSTS = [
  'localhost', '127.0.0.1', '[::1]', '0.0.0.0',
  '169.254.169.254', // AWS/GCP metadata
];
const BLOCKED_PREFIXES = ['10.', '172.16.', '172.17.', '172.18.', '172.19.',
  '172.20.', '172.21.', '172.22.', '172.23.', '172.24.', '172.25.',
  '172.26.', '172.27.', '172.28.', '172.29.', '172.30.', '172.31.',
  '192.168.', 'fc00:', 'fe80:'];

function isUrlSafe(urlString) {
  try {
    const url = new URL(urlString);
    if (!['http:', 'https:'].includes(url.protocol)) return false;
    const host = url.hostname.toLowerCase();
    if (BLOCKED_HOSTS.includes(host)) return false;
    if (BLOCKED_PREFIXES.some(p => host.startsWith(p))) return false;
    return true;
  } catch {
    return false;
  }
}

app.post('/fetch', async (req, res) => {
  if (!isUrlSafe(req.body.url)) {
    return res.status(400).json({ error: 'URL not allowed' });
  }
  const response = await fetch(req.body.url, { signal: AbortSignal.timeout(10000) });
  res.json(await response.json());
});
```

- [ ] URLs from user input are validated before `fetch()` / `axios` / `got` calls
- [ ] Internal/private IP ranges are blocked
- [ ] Only http/https protocols allowed
- [ ] Cloud metadata endpoints blocked (169.254.169.254)
- [ ] Request timeouts are set

---

## 14. SELF-CHECK (FP Recheck — 6-Step Procedure)
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
**Location**: `src/routes/xxx.ts:XX`
**Description**: ...
**Impact**: ...
**Remediation**: ...

## Security Controls in Place
- [x] JWT authentication
- [x] Zod validation
- [ ] Rate limiting on all endpoints
```

---

## 13. ACTIONS

## 15. OUTPUT FORMAT (Structured Report Schema — Phase 14)
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

1. **Quick Check** — go through 8 points
2. **Scan** — go through all sections
3. **Classify** — Critical → Low
4. **Document** — file, line, code
5. **Fix** — propose concrete fix

Start the audit. Quick Check first, then Executive Summary.

## Council Handoff
<!-- v42-splice: council-handoff -->

When the structured report is complete, hand it off to the Supreme Council for
peer review. See `commands/audit.md` Phase 5 (Council Pass — mandatory) for the
invocation: `/council audit-review --report <path>`. The Council runs in
audit-review mode (see `commands/council.md` `## Modes`). The Council verdict
slot in the report is pre-populated with the byte-exact placeholder
`_pending — run /council audit-review_` (U+2014 em-dash) and is overwritten by
the Council pass.
