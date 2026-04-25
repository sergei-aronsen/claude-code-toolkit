# Security Audit — Next.js Template

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

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

## 11. SELF-CHECK (FP Recheck — 6-Step Procedure)
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

## 12. OUTPUT FORMAT (Structured Report Schema — Phase 14)
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
4. **Self-check** — filter false positives
5. **Document** — file, line, code
6. **Fix** — suggest specific fix

Start audit. Quick Check first, then Executive Summary.

## Council Handoff
<!-- v42-splice: council-handoff -->

When the structured report is complete, hand it off to the Supreme Council for
peer review. See `commands/audit.md` Phase 5 (Council Pass — mandatory) for the
invocation: `/council audit-review --report <path>`. The Council runs in
audit-review mode (see `commands/council.md` `## Modes`). The Council verdict
slot in the report is pre-populated with the byte-exact placeholder
`_pending — run /council audit-review_` (U+2014 em-dash) and is overwritten by
the Council pass.
