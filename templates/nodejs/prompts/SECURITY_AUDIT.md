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

If all 5 = OK → Basic security level OK.

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

---

## 11. REPORT FORMAT

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

## 12. ACTIONS

1. **Quick Check** — go through 5 points
2. **Scan** — go through all sections
3. **Classify** — Critical → Low
4. **Document** — file, line, code
5. **Fix** — propose concrete fix

Start the audit. Quick Check first, then Executive Summary.
