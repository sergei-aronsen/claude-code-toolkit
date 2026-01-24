---
name: Node.js Expert
description: Deep expertise in Node.js - Express/Fastify, async patterns, middleware, validation
---

# Node.js Expert Skill

This skill provides deep Node.js expertise including Express/Fastify patterns, async handling, middleware, validation with Zod, and security best practices.

---

## Async Patterns

### Always Use async/await

```typescript
// ✅ Correct - async/await
async function getUsers(): Promise<User[]> {
  const users = await prisma.user.findMany();
  return users;
}

// ❌ Wrong - callback style
function getUsers(callback: (err: Error, users: User[]) => void) {
  prisma.user.findMany().then(users => callback(null, users));
}
```

### Error Handling Wrapper

```typescript
// Express async handler wrapper
type AsyncHandler = (req: Request, res: Response, next: NextFunction) => Promise<any>;

export const asyncHandler = (fn: AsyncHandler): RequestHandler =>
  (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

// Usage
router.get('/users', asyncHandler(async (req, res) => {
  const users = await userService.findAll();
  res.json(users);
}));
```

### Parallel vs Sequential

```typescript
// ✅ Parallel - when operations are independent
const [users, posts, comments] = await Promise.all([
  getUsers(),
  getPosts(),
  getComments(),
]);

// ✅ Sequential - when operations depend on each other
const user = await getUser(id);
const posts = await getPostsByUser(user.id);

// ❌ Wrong - sequential when could be parallel
const users = await getUsers();
const posts = await getPosts();  // Doesn't depend on users
```

---

## Validation with Zod

### Schema Definition

```typescript
import { z } from 'zod';

// Basic schema
const CreateUserSchema = z.object({
  email: z.string().email('Invalid email format'),
  name: z.string().min(2, 'Name too short').max(100, 'Name too long'),
  password: z.string()
    .min(8, 'Password must be at least 8 characters')
    .regex(/[A-Z]/, 'Must contain uppercase letter')
    .regex(/[0-9]/, 'Must contain number'),
  age: z.number().int().positive().optional(),
});

// Infer TypeScript type
type CreateUserInput = z.infer<typeof CreateUserSchema>;

// With transform
const QuerySchema = z.object({
  page: z.string().transform(Number).default('1'),
  limit: z.string().transform(Number).default('10'),
});
```

### Validation Middleware

```typescript
import { z, ZodSchema } from 'zod';

export const validate = <T extends ZodSchema>(schema: T) =>
  (req: Request, res: Response, next: NextFunction) => {
    const result = schema.safeParse(req.body);

    if (!result.success) {
      return res.status(400).json({
        error: 'Validation failed',
        details: result.error.flatten(),
      });
    }

    req.body = result.data;
    next();
  };

// Usage
router.post('/users', validate(CreateUserSchema), asyncHandler(createUser));
```

---

## N+1 Query Prevention

### Prisma Eager Loading

```typescript
// ❌ N+1 problem
const users = await prisma.user.findMany();
for (const user of users) {
  user.posts = await prisma.post.findMany({ where: { authorId: user.id } });
}

// ✅ Include (eager loading)
const users = await prisma.user.findMany({
  include: {
    posts: true,
    profile: true,
  },
});

// ✅ Select specific fields only
const users = await prisma.user.findMany({
  select: {
    id: true,
    email: true,
    posts: {
      select: { id: true, title: true },
      take: 5,
    },
  },
});
```

### DataLoader Pattern

```typescript
import DataLoader from 'dataloader';

// Create loader
const postsByUserLoader = new DataLoader<string, Post[]>(async (userIds) => {
  const posts = await prisma.post.findMany({
    where: { authorId: { in: [...userIds] } },
  });

  // Group by user ID
  const postsByUser = new Map<string, Post[]>();
  for (const post of posts) {
    const userPosts = postsByUser.get(post.authorId) || [];
    userPosts.push(post);
    postsByUser.set(post.authorId, userPosts);
  }

  return userIds.map(id => postsByUser.get(id) || []);
});

// Usage - batches multiple calls
const [user1Posts, user2Posts] = await Promise.all([
  postsByUserLoader.load('user1'),
  postsByUserLoader.load('user2'),
]);
```

---

## Security Checklist

### Input Validation

```typescript
// ✅ Validate all inputs with Zod
const input = CreateUserSchema.parse(req.body);

// ✅ Sanitize HTML if needed
import sanitizeHtml from 'sanitize-html';
const clean = sanitizeHtml(userInput);
```

### SQL Injection Prevention

```typescript
// ✅ Use Prisma (parameterized by default)
const user = await prisma.user.findUnique({
  where: { email: userInput },
});

// ✅ If raw query needed, use parameters
const users = await prisma.$queryRaw`
  SELECT * FROM users WHERE email = ${userInput}
`;

// ❌ NEVER concatenate user input
const users = await prisma.$queryRawUnsafe(
  `SELECT * FROM users WHERE email = '${userInput}'`  // SQL INJECTION!
);
```

### Security Headers (helmet.js)

```typescript
import helmet from 'helmet';

app.use(helmet());  // Adds many security headers

// Custom CSP
app.use(helmet.contentSecurityPolicy({
  directives: {
    defaultSrc: ["'self'"],
    scriptSrc: ["'self'", "'unsafe-inline'"],
    styleSrc: ["'self'", "'unsafe-inline'"],
  },
}));
```

### Rate Limiting

```typescript
import rateLimit from 'express-rate-limit';

// General API limit
app.use('/api/', rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 minutes
  max: 100,
  standardHeaders: true,
}));

// Strict auth limit
app.use('/api/auth/', rateLimit({
  windowMs: 60 * 60 * 1000,  // 1 hour
  max: 5,
  message: { error: 'Too many attempts, try again later' },
}));
```

---

## Testing Patterns (Vitest)

### Unit Test Structure

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';

describe('UserService', () => {
  let service: UserService;
  let mockRepo: { findById: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    mockRepo = { findById: vi.fn() };
    service = new UserService(mockRepo);
  });

  it('returns user when found', async () => {
    mockRepo.findById.mockResolvedValue({ id: '1', email: 'test@example.com' });

    const user = await service.findById('1');

    expect(user.email).toBe('test@example.com');
  });

  it('throws when not found', async () => {
    mockRepo.findById.mockResolvedValue(null);

    await expect(service.findById('999')).rejects.toThrow('not found');
  });
});
```

### API Test with Supertest

```typescript
import request from 'supertest';
import { app } from '../src/app';

describe('POST /api/users', () => {
  it('creates user with valid data', async () => {
    const response = await request(app)
      .post('/api/users')
      .send({ email: 'test@example.com', name: 'Test' })
      .expect(201);

    expect(response.body).toHaveProperty('id');
  });

  it('validates email format', async () => {
    await request(app)
      .post('/api/users')
      .send({ email: 'invalid', name: 'Test' })
      .expect(400);
  });
});
```

---

## Logging with Pino

```typescript
import pino from 'pino';
import pinoHttp from 'pino-http';

export const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  transport: process.env.NODE_ENV === 'development'
    ? { target: 'pino-pretty' }
    : undefined,
});

// Request logging
app.use(pinoHttp({ logger }));

// Structured logging
logger.info({ userId: user.id, action: 'login' }, 'User logged in');
logger.error({ err, userId }, 'Failed to process payment');
```

---

## Common Commands

```bash
# Development
pnpm dev                    # Start dev server
pnpm dev:debug              # With inspector

# Testing
pnpm test                   # Run tests
pnpm test:watch             # Watch mode
pnpm test:coverage          # Coverage report

# Code Quality
pnpm lint                   # ESLint
pnpm lint:fix               # Auto-fix
pnpm format                 # Prettier
pnpm type-check             # TypeScript

# Build
pnpm build                  # Production build
```
