# Security Audit — Node.js Template

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

1. **Quick Check** — go through 8 points
2. **Scan** — go through all sections
3. **Classify** — Critical → Low
4. **Document** — file, line, code
5. **Fix** — propose concrete fix

Start the audit. Quick Check first, then Executive Summary.
