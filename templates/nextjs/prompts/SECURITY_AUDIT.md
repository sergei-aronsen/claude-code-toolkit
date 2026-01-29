# Security Audit — Next.js Template

## Goal

Comprehensive security audit of a Next.js application. Act as a Senior Security Engineer.

> **Warning: Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for conducting audits — works better with code analysis.

---

## 0. QUICK CHECK (5 minutes)

| # | Check | Command | Expected |
| --- | ------- | --------- | ---------- |
| 1 | Auth on API | `find app/api -name "route.ts" -exec grep -L "getServerSession\|auth" {} \;` | Empty (or only public endpoints) |
| 2 | Secrets in code | `grep -rn "sk-\|password.*=.*['\"]" app/ lib/ --include="*.ts"` | Empty |
| 3 | SQL injection | `grep -rn "SELECT.*\${" lib/ app/ --include="*.ts"` | Empty |
| 4 | npm audit | `npm audit --production` | No critical/high |
| 5 | Env exposure | `grep -rn "NEXT_PUBLIC_.*KEY\|NEXT_PUBLIC_.*SECRET" .env*` | Empty |
| 6 | Secret key | `grep "NEXTAUTH_SECRET\|JWT_SECRET" .env*` | Strong, >= 32 chars |
| 7 | Open redirect | `grep -rn "redirect.*searchParams\|redirect.*req.query" app/ lib/ --include="*.ts"` | Check validation |
| 8 | .env public | `grep -rn "NEXT_PUBLIC_.*SECRET\|NEXT_PUBLIC_.*KEY\|NEXT_PUBLIC_.*PASSWORD" .env*` | Empty |

If all 8 = OK → Basic security level OK.

---

## 0.1 AUTO-CHECK SCRIPT

```bash
#!/bin/bash
# security-check.sh

echo "🔐 Security Quick Check — Next.js..."

# 1. Unprotected API routes
UNPROTECTED=$(find app/api -name "route.ts" -exec grep -L "getServerSession\|auth" {} \; 2>/dev/null | grep -v "health\|webhook")
[ -z "$UNPROTECTED" ] && echo "✅ Auth: All API routes protected" || echo "❌ Auth: Unprotected routes found"

# 2. Hardcoded secrets
SECRETS=$(grep -rn "sk-\|api_key.*=.*['\"][a-zA-Z0-9]" app/ lib/ components/ --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v "node_modules")
[ -z "$SECRETS" ] && echo "✅ Secrets: No hardcoded keys" || echo "❌ Secrets: Found hardcoded keys!"

# 3. SQL injection patterns
SQLI=$(grep -rn 'SELECT.*\${\|INSERT.*\${\|UPDATE.*\${' lib/ app/ --include="*.ts" 2>/dev/null)
[ -z "$SQLI" ] && echo "✅ SQL: No injection patterns" || echo "❌ SQL: Potential injection!"

# 4. npm audit
npm audit --production 2>/dev/null | grep -q "critical\|high" && echo "❌ NPM: Critical vulnerabilities" || echo "✅ NPM: No critical issues"

# 5. Env exposure
EXPOSED=$(grep -rn "NEXT_PUBLIC_.*KEY\|NEXT_PUBLIC_.*SECRET\|NEXT_PUBLIC_.*PASSWORD" .env* 2>/dev/null)
[ -z "$EXPOSED" ] && echo "✅ Env: No secrets exposed" || echo "❌ Env: Secrets in NEXT_PUBLIC_!"

# 6. dangerouslySetInnerHTML
DANGEROUS=$(grep -rn "dangerouslySetInnerHTML" app/ components/ --include="*.tsx" 2>/dev/null | wc -l)
[ "$DANGEROUS" -eq 0 ] && echo "✅ XSS: No dangerouslySetInnerHTML" || echo "🟡 XSS: $DANGEROUS uses (verify sanitization)"

# 7. NEXTAUTH_SECRET strength
SECRET=$(grep "NEXTAUTH_SECRET=" .env* 2>/dev/null | head -1 | cut -d'=' -f2)
[ ${#SECRET} -ge 32 ] && echo "✅ Secret: NEXTAUTH_SECRET is strong" || echo "❌ Secret: NEXTAUTH_SECRET too short (need >= 32 chars)"

# 8. Public env with secrets
PUB_SECRETS=$(grep -rn "NEXT_PUBLIC_.*SECRET\|NEXT_PUBLIC_.*KEY\|NEXT_PUBLIC_.*PASSWORD" .env* 2>/dev/null | grep -v "NEXT_PUBLIC_STRIPE_PUBLISHABLE\|NEXT_PUBLIC_.*_PUBLIC_KEY")
[ -z "$PUB_SECRETS" ] && echo "✅ Env: No secrets in NEXT_PUBLIC_*" || echo "❌ Env: Secrets exposed in NEXT_PUBLIC_*!"

# 9. Open redirect
REDIRECT=$(grep -rn "redirect.*searchParams\|redirect.*req.query\|redirect.*url" app/ lib/ --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v "node_modules\|test")
[ -z "$REDIRECT" ] && echo "✅ Redirect: No open redirect patterns" || echo "🟡 Redirect: Found redirect patterns (verify validation)"

# 10. Dangerous functions
DANGEROUS_FN=$(grep -rn "eval(\|new Function(\|setTimeout.*request\|import(" src/ app/ 2>/dev/null | grep -v "node_modules\|test\|spec\|\.next")
[ -z "$DANGEROUS_FN" ] && echo "✅ Functions: No dangerous patterns" || echo "🟡 Functions: Found eval/Function patterns (verify input)"

# 11. .env exposure
EXPOSED_ENV=$(grep -rn "NEXT_PUBLIC_" .env* 2>/dev/null | grep -iE "secret|password|key|token|private")
[ -z "$EXPOSED_ENV" ] && echo "✅ Env: No secrets in NEXT_PUBLIC_" || echo "❌ Env: Secrets exposed via NEXT_PUBLIC_!"

echo "Done!"
```

---

## 0.2 PROJECT SPECIFICS — [Project Name]

**Fill out before audit:**

**What's already implemented:**

- [ ] Authentication: [NextAuth / custom / none]
- [ ] Authorization: [middleware / API checks]
- [ ] Input validation: [Zod / yup / other]
- [ ] Database: [Prisma / Drizzle / raw SQL / MySQL]

**Public endpoints (by design):**

- `/api/health` — health check
- `/api/auth/*` — NextAuth endpoints (if used)
- `/api/webhooks/*` — webhooks (verify signature!)

---

## 0.3 SEVERITY LEVELS

| Level | Description | Action |
| ------- | ---------- | ---------- |
| 🔴 CRITICAL | Exploitable vulnerability, RCE, SQLi, auth bypass | **BLOCKER** — fix immediately |
| 🟠 HIGH | Serious vulnerability, requires auth or complex exploitation | Fix before deploy |
| 🟡 MEDIUM | Potential vulnerability, low risk | Fix in upcoming sprint |
| 🔵 LOW | Best practice, defense in depth | Backlog |
| ⚪ INFO | Information, no action required | — |

---

## 1. API ROUTES SECURITY

### 1.1 Authentication on API Routes

```typescript
// ❌ CRITICAL — API without authentication
// app/api/projects/route.ts
export async function GET(request: Request) {
  const projects = await db.query('SELECT * FROM projects');
  return Response.json(projects);  // Anyone can access!
}

// ✅ Good — full verification
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/auth';

export async function POST(request: Request) {
  const session = await getServerSession(authOptions);

  if (!session?.user?.id) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const body = await request.json();

  // Ownership verification
  const project = await getProject(body.projectId);
  if (project.userId !== session.user.id) {
    return Response.json({ error: 'Forbidden' }, { status: 403 });
  }

  // ... rest of logic
}
```

- [ ] All protected API routes check session
- [ ] Resource ownership is verified
- [ ] Public routes explicitly documented

### 1.2 Rate Limiting

```typescript
// ❌ Bad — no rate limiting on expensive endpoints
export async function POST(request: Request) {
  const { prompt } = await request.json();
  // Immediately call AI — can be DDoSed!
}

// ✅ Good — rate limiting
import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis';

const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(10, '1 m'),
});

export async function POST(request: Request) {
  const session = await getServerSession(authOptions);
  if (!session?.user?.id) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const { success, reset } = await ratelimit.limit(`api_${session.user.id}`);

  if (!success) {
    return Response.json({ error: 'Rate limit exceeded', reset }, { status: 429 });
  }

  // ... logic
}
```

- [ ] Expensive endpoints have rate limiting
- [ ] Rate limit by user ID, not by IP
- [ ] 429 response with reset information

### 1.3 Request Validation

```typescript
// ❌ Bad — no validation
export async function POST(request: Request) {
  const body = await request.json();
  const result = await processData(body.data);  // Anything goes!
}

// ✅ Good — Zod validation
import { z } from 'zod';

const RequestSchema = z.object({
  prompt: z.string().min(1).max(10000),
  projectId: z.string().uuid(),
  options: z.object({
    model: z.enum(['gpt-4', 'claude-sonnet-4-5-20250929']).optional(),
  }).optional(),
});

export async function POST(request: Request) {
  const body = await request.json();

  const parsed = RequestSchema.safeParse(body);
  if (!parsed.success) {
    return Response.json(
      { error: 'Invalid request', details: parsed.error.flatten() },
      { status: 400 }
    );
  }

  const { prompt, projectId, options } = parsed.data;
  // ... safe to use
}
```

- [ ] All API routes validate input via Zod
- [ ] String fields have max length
- [ ] UUID/ID fields are validated

---

## 2. INJECTION ATTACKS

### 2.1 SQL Injection

```typescript
// ❌ CRITICAL — SQL Injection
const projects = await query(
  `SELECT * FROM projects WHERE user_id = '${userId}'`
);

// ❌ Bad — concatenation
const sql = `SELECT * FROM projects WHERE name LIKE '%${search}%'`;

// ✅ Good — parameterized queries
const projects = await query(
  'SELECT * FROM projects WHERE user_id = ?',
  [userId]
);

// ✅ For LIKE
const projects = await query(
  'SELECT * FROM projects WHERE name LIKE ?',
  [`%${search}%`]
);
```

- [ ] All SQL uses parameterized queries
- [ ] No user input concatenation in SQL
- [ ] LIKE queries use parameters

### 2.2 NoSQL/Object Injection

```typescript
// ❌ Dangerous — spread user input
const updateData = { ...await request.json() };
await db.update(updateData);

// ✅ Good — explicit whitelist
const body = await request.json();
const updateData = {
  name: body.name,
  email: body.email,
  // Only allowed fields
};
```

- [ ] User input not spread directly
- [ ] Whitelist for allowed fields

### 2.3 Command Injection

```typescript
// ❌ CRITICAL — Command Injection
import { exec } from 'child_process';

export async function POST(request: Request) {
  const { command } = await request.json();
  exec(command);  // Full control over server!
}

// ✅ Good — command whitelist
const ALLOWED_COMMANDS = {
  'install': ['npm', 'install'],
  'build': ['npm', 'run', 'build'],
} as const;

export async function POST(request: Request) {
  const { commandType } = await request.json();

  const baseCommand = ALLOWED_COMMANDS[commandType];
  if (!baseCommand) {
    return Response.json({ error: 'Command not allowed' }, { status: 400 });
  }

  spawn(baseCommand[0], baseCommand.slice(1));
}
```

- [ ] No direct execution of user commands
- [ ] Whitelist of allowed commands

### 2.4 Dangerous Functions

Some JavaScript constructs allow arbitrary code execution.

```javascript
// ❌ Dangerous — never use with user input
eval(userInput)
new Function(userInput)
setTimeout(userInput, 0)  // string form
import(userInput)          // dynamic import from user
```

- [ ] No `eval()` with user-controlled input
- [ ] No `new Function()` with user input
- [ ] No `setTimeout`/`setInterval` with string arguments from user
- [ ] No dynamic `import()` with user-controlled paths
- [ ] Server Actions do not expose internal logic through user-controlled function names

---

## 3. CROSS-SITE SCRIPTING (XSS)

### 3.1 React/Next.js XSS

```tsx
// ❌ CRITICAL — XSS
<div dangerouslySetInnerHTML={{ __html: userContent }} />

// ✅ Safe — React automatically escapes
<div>{userContent}</div>

// ✅ If HTML is necessary — sanitization
import DOMPurify from 'dompurify';

<div dangerouslySetInnerHTML={{
  __html: DOMPurify.sanitize(htmlContent, {
    ALLOWED_TAGS: ['p', 'br', 'strong', 'em', 'ul', 'li', 'a'],
    ALLOWED_ATTR: ['href', 'target']
  })
}} />
```

- [ ] No `dangerouslySetInnerHTML` with user content without DOMPurify
- [ ] Minimal whitelist of tags in DOMPurify

### 3.2 URL Injection

```tsx
// ❌ Dangerous — user-controlled href
<a href={userProvidedUrl}>Link</a>
// javascript:alert('XSS')

// ✅ Good — URL validation
function SafeLink({ href, children }) {
  const isValid = href.startsWith('https://') || href.startsWith('/');

  if (!isValid) {
    return <span>{children}</span>;
  }

  return (
    <a href={href} rel="noopener noreferrer" target="_blank">
      {children}
    </a>
  );
}
```

- [ ] User-provided URLs are validated
- [ ] No `javascript:` URLs
- [ ] External links have `rel="noopener noreferrer"`

---

## 4. AUTHENTICATION (next-auth)

### 4.1 Configuration

```typescript
// ✅ Secure configuration
import { compare } from 'bcryptjs';

export const authOptions: NextAuthOptions = {
  secret: process.env.NEXTAUTH_SECRET,  // Required!

  providers: [
    CredentialsProvider({
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) {
          return null;
        }

        const user = await db.query(
          'SELECT * FROM users WHERE email = ?',
          [credentials.email]
        );

        if (!user) return null;

        const isValid = await compare(credentials.password, user.password);
        if (!isValid) return null;

        return { id: user.id, email: user.email };
      }
    })
  ],

  session: {
    strategy: 'jwt',
    maxAge: 30 * 24 * 60 * 60,
  },
};
```

- [ ] `NEXTAUTH_SECRET` set and strong (min 32 chars)
- [ ] `NEXTAUTH_URL` correct for production
- [ ] Passwords hashed (bcryptjs)
- [ ] Parameterized SQL queries

### 4.2 Middleware Protection

```typescript
// middleware.ts
import { withAuth } from 'next-auth/middleware';

export default withAuth({
  pages: { signIn: '/auth/signin' },
});

export const config = {
  matcher: [
    '/dashboard/:path*',
    '/api/projects/:path*',
    '/api/generate-:path*',
  ],
};
```

- [ ] middleware.ts protects needed routes
- [ ] No access to others' data

### 4.3 Secret Key Validation

```typescript
// ❌ Weak or missing secret
// .env
NEXTAUTH_SECRET=secret

// ✅ Strong secret
// Generate: openssl rand -base64 32
NEXTAUTH_SECRET=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0
```

- [ ] `NEXTAUTH_SECRET` is at least 32 characters
- [ ] `NEXTAUTH_SECRET` is not a default value (`secret`, `changeme`)
- [ ] JWT secrets are loaded from env, not hardcoded
- [ ] Different secrets per environment (dev/staging/production)

### 4.4 Session Timeout

```typescript
// next-auth options
export const authOptions: NextAuthOptions = {
  session: {
    strategy: 'jwt',
    maxAge: 30 * 60,        // ✅ 30 minutes
    updateAge: 5 * 60,      // ✅ Refresh every 5 min
  },
};
```

- [ ] Session `maxAge` is configured (not infinite)
- [ ] Recommended: 15-30 minutes for sensitive apps
- [ ] Session is invalidated on logout

### 4.5 .env Public Access

`.env` files accessible via web expose all secrets. Next.js serves from `public/` directory.

- [ ] `.env` files are not in `public/` directory
- [ ] `.env` is in `.gitignore`
- [ ] Only `NEXT_PUBLIC_*` variables are exposed to the client
- [ ] Sensitive variables (API keys, DB credentials) do NOT have `NEXT_PUBLIC_` prefix
- [ ] Verify: `curl -s https://yoursite.com/.env` returns 403/404

**Next.js-specific:**

```bash
# Check for exposed secrets in client bundle
grep -rn "NEXT_PUBLIC_" .env* | grep -iE "secret|password|key|token"
```

---

## 5. CSRF (Cross-Site Request Forgery)

### 5.1 API Routes with Cookies

```typescript
// ❌ CRITICAL — CSRF vulnerable (cookie-based auth without CSRF token)
export async function POST(request: Request) {
  const session = await getServerSession(authOptions);
  if (!session) return Response.json({ error: 'Unauthorized' }, { status: 401 });

  // Attacker can trigger this via <form action="..." method="POST">
  await updateUserData(request);
}

// ✅ Good — Use SameSite cookies
// In your auth config:
cookies: {
  sessionToken: {
    name: 'session-token',
    options: {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',  // CSRF protection
    },
  },
}

// ✅ Good — Or use CSRF token for sensitive mutations
import { csrf } from '@/lib/csrf';

export async function POST(request: Request) {
  const token = request.headers.get('X-CSRF-Token');
  if (!await csrf.verify(token)) {
    return Response.json({ error: 'Invalid CSRF token' }, { status: 403 });
  }
  // Process request
}
```

- [ ] Session cookies use `SameSite: 'strict'` or `'lax'`
- [ ] Sensitive mutations validate CSRF token or use SameSite cookies
- [ ] Server Actions are CSRF-protected by default (Next.js 14+)

### 5.2 Server Actions

```typescript
// ✅ Server Actions have built-in CSRF protection
'use server';

export async function updateProfile(formData: FormData) {
  // Next.js automatically validates the action origin
  const session = await getServerSession(authOptions);
  if (!session) throw new Error('Unauthorized');

  await db.update(...)
}
```

- [ ] Use Server Actions for mutations when possible
- [ ] API routes with cookie auth have CSRF protection

---

## 6. SSRF (Server-Side Request Forgery)

### 6.1 URL Validation

```typescript
// ❌ CRITICAL — SSRF
export async function POST(request: Request) {
  const { url } = await request.json();
  const response = await fetch(url);  // Can request internal URLs!
  // http://169.254.169.254/latest/meta-data/
}

// ✅ Good — URL validation
const BLOCKED_HOSTS = [
  // Localhost variations
  'localhost', 'localhost.',
  '127.0.0.1', '127.0.0.2', '[::1]',  // IPv6 localhost
  '0.0.0.0', '0000', '0x7f.0.0.1',    // Obfuscated
  // Cloud metadata
  '169.254.169.254', '[fd00:ec2::254]',  // AWS metadata (IPv4 & IPv6)
  // Private ranges
  '10.', '172.16.', '172.17.', '172.18.', '172.19.',
  '172.20.', '172.21.', '172.22.', '172.23.',
  '172.24.', '172.25.', '172.26.', '172.27.',
  '172.28.', '172.29.', '172.30.', '172.31.',
  '192.168.',
  // IPv6 private
  'fc00:', 'fe80:',
];

function isUrlAllowed(urlString: string): boolean {
  try {
    const url = new URL(urlString);

    if (!['http:', 'https:'].includes(url.protocol)) {
      return false;
    }

    const host = url.hostname.toLowerCase();
    for (const blocked of BLOCKED_HOSTS) {
      if (host === blocked || host.startsWith(blocked)) {
        return false;
      }
    }

    return true;
  } catch {
    return false;
  }
}

export async function POST(request: Request) {
  const { url } = await request.json();

  if (!isUrlAllowed(url)) {
    return Response.json({ error: 'URL not allowed' }, { status: 400 });
  }

  const response = await fetch(url, {
    signal: AbortSignal.timeout(10000),
  });
}
```

- [ ] URL scraping endpoints validate URLs
- [ ] Blocked: localhost, internal IPs, cloud metadata
- [ ] Timeout set

---

## 7. API KEYS & SECRETS

### 6.1 Environment Variables

```typescript
// ❌ CRITICAL — hardcoded keys
const anthropic = new Anthropic({
  apiKey: 'sk-ant-api03-xxxxx',
});

// ❌ Bad — key in client-side code
// components/Generator.tsx
const apiKey = process.env.NEXT_PUBLIC_ANTHROPIC_KEY;  // Visible in browser!

// ✅ Good — server-side only
// app/api/generate/route.ts (server-side)
const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,  // Without NEXT_PUBLIC_
});
```

- [ ] No hardcoded API keys
- [ ] AI/DB keys without `NEXT_PUBLIC_` prefix
- [ ] All secrets in `.env.local`, not in code
- [ ] `.env.local` in `.gitignore`

### 6.2 Client-Side Exposure

```ini
# ✅ OK for NEXT_PUBLIC_
NEXT_PUBLIC_APP_URL=https://your-app.com
NEXT_PUBLIC_ANALYTICS_ID=GA-xxxxx

# ❌ SHOULD NOT be NEXT_PUBLIC_
# NEXT_PUBLIC_API_KEY=sk-...
# NEXT_PUBLIC_DATABASE_URL=...
```

- [ ] Only safe variables have `NEXT_PUBLIC_`
- [ ] API keys, database URLs — without `NEXT_PUBLIC_`

### 6.3 Environment Variable Exposure

Variables prefixed with `NEXT_PUBLIC_` are exposed to the browser. Secrets must NOT use this prefix.

```bash
# Find potentially exposed secrets
grep -rn "NEXT_PUBLIC_.*SECRET\|NEXT_PUBLIC_.*KEY\|NEXT_PUBLIC_.*PASSWORD" .env*
```

- [ ] No secrets in `NEXT_PUBLIC_*` variables
- [ ] API keys that must be public use `NEXT_PUBLIC_` prefix (e.g., Stripe publishable key)
- [ ] Server-side secrets are only in `process.env` (no `NEXT_PUBLIC_` prefix)

---

## 8. FILE HANDLING

### 7.1 File Upload Security

```typescript
// ❌ Bad — no validation
export async function POST(request: Request) {
  const formData = await request.formData();
  const file = formData.get('file') as File;
  // Save as is
}

// ✅ Good — validation
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_SIZE = 10 * 1024 * 1024; // 10MB

export async function POST(request: Request) {
  const formData = await request.formData();
  const file = formData.get('file') as File;

  if (!file) {
    return Response.json({ error: 'No file' }, { status: 400 });
  }

  if (!ALLOWED_TYPES.includes(file.type)) {
    return Response.json({ error: 'Invalid file type' }, { status: 400 });
  }

  if (file.size > MAX_SIZE) {
    return Response.json({ error: 'File too large' }, { status: 400 });
  }

  // Generate safe filename
  const safeName = `${nanoid()}.${file.name.split('.').pop()}`;
}
```

- [ ] File type validated
- [ ] File size limited
- [ ] Filename generated

### 7.2 Path Traversal

```typescript
// ❌ CRITICAL — Path Traversal
const filePath = `./uploads/${req.query.filename}`;
// filename: "../../../etc/passwd"

// ✅ Good — path sanitization
import path from 'path';

const filename = path.basename(req.query.filename);
const filePath = path.join('./uploads', filename);

if (!filePath.startsWith(path.resolve('./uploads'))) {
  throw new Error('Invalid path');
}
```

- [ ] All file paths sanitized
- [ ] `path.basename()` for user-provided filenames

---

## 9. SECURITY HEADERS

### 8.1 Next.js Config

```typescript
// next.config.ts
const nextConfig = {
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          { key: 'X-DNS-Prefetch-Control', value: 'on' },
          { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'X-XSS-Protection', value: '1; mode=block' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
          { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
        ],
      },
    ];
  },
};
```

- [ ] Security headers in next.config.ts
- [ ] HSTS enabled for production
- [ ] X-Frame-Options = DENY

### 8.2 CORS

```typescript
// ❌ Bad
headers.set('Access-Control-Allow-Origin', '*');

// ✅ Good — specific origins
const allowedOrigins = [
  'https://your-app.com',
  process.env.NODE_ENV === 'development' ? 'http://localhost:3000' : '',
].filter(Boolean);
```

- [ ] CORS not `*` for sensitive API

### 8.3 HSTS (HTTP Strict Transport Security)

```typescript
// next.config.ts
const nextConfig = {
  async headers() {
    return [{
      source: '/(.*)',
      headers: [
        {
          key: 'Strict-Transport-Security',
          value: 'max-age=31536000; includeSubDomains; preload',
        },
      ],
    }];
  },
};
```

- [ ] HSTS header configured in `next.config.ts` or web server
- [ ] `max-age` >= 31536000 (1 year)

### 8.4 Open Redirection

```typescript
// ❌ Dangerous — redirect to user-supplied URL
import { redirect } from 'next/navigation';

export async function GET(request: Request) {
  const url = new URL(request.url);
  const returnUrl = url.searchParams.get('returnUrl');
  redirect(returnUrl!); // Open redirect!
}

// ✅ Safe — validate URL
const ALLOWED_HOSTS = ['myapp.com', 'www.myapp.com'];

function isSafeRedirect(url: string): boolean {
  try {
    const parsed = new URL(url, 'https://myapp.com');
    return ALLOWED_HOSTS.includes(parsed.hostname) || url.startsWith('/');
  } catch {
    return false;
  }
}
```

- [ ] No redirects using raw `searchParams` or query values
- [ ] Redirect URLs validated against whitelist or restricted to relative paths
- [ ] `callbackUrl` in NextAuth is validated

### 8.5 Host Injection

```typescript
// ❌ Dangerous — trusting Host header
export async function GET(request: Request) {
  const host = request.headers.get('host');
  const resetLink = `https://${host}/reset?token=${token}`; // Spoofable!
}

// ✅ Safe — use configured base URL
const BASE_URL = process.env.NEXT_PUBLIC_APP_URL;
const resetLink = `${BASE_URL}/reset?token=${token}`;
```

- [ ] Password reset and email links use configured `NEXT_PUBLIC_APP_URL`, not Host header
- [ ] `next.config` has `allowedDevOrigins` or host validation configured

---

## 10. DEPENDENCY SECURITY

```bash
npm audit
npm audit --json
```

- [ ] `npm audit` without critical/high
- [ ] Dependencies updated

---

## 11. SELF-CHECK

**Before adding a vulnerability to the report:**

| Question | If "no" → reconsider severity |
| -------- | ---------------------------------- |
| Is it **exploitable** in real conditions? | Theoretical ≠ real threat |
| Is there an **attack path** for an attacker? | Internal-only ≠ CRITICAL |
| **What damage** from successful attack? | Leak of public data ≠ leak of passwords |
| Is **auth** required for exploitation? | Auth-required reduces severity |

**Common false positives:**

| Seems like vulnerability | Why it might not be an issue |
| --------------------- | -------------------------------- |
| "No auth on endpoint" | May be intentionally public |
| "CORS: *" | If endpoint is auth-protected — not critical |
| "Old package version" | If no CVE — not a security issue |

---

## 12. REPORT FORMAT

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
**Location**: `app/api/xxx/route.ts:XX`
**Description**: ...
**Impact**: ...
**Remediation**: ...

## ✅ Security Controls in Place
- [x] NextAuth authentication
- [x] Zod validation
- [ ] Rate limiting on all endpoints
```

---

## 13. ACTIONS

1. **Quick Check** — go through 5 points
2. **Scan** — go through all sections
3. **Classify** — Critical → Low
4. **Self-check** — filter false positives
5. **Document** — file, line, code
6. **Fix** — suggest specific fix

Start audit. Quick Check first, then Executive Summary.
