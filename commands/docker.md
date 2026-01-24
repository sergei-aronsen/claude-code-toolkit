# /docker — Docker Configuration

## Purpose

Generate or analyze Docker configurations for your project.

---

## Usage

```text
/docker [action] [options]
```

**Actions:**

- `/docker init` — Generate Dockerfile and docker-compose.yml
- `/docker analyze` — Analyze existing Dockerfile
- `/docker optimize` — Suggest optimizations
- `/docker multi-stage` — Convert to multi-stage build

---

## Examples

```text
/docker init                    # Generate Docker config for detected stack
/docker init --stack=node       # Force Node.js stack
/docker analyze Dockerfile      # Review existing Dockerfile
/docker optimize                # Suggest image size and security improvements
```

---

## Generated Files

### Dockerfile (Node.js Example)

```dockerfile
# Build stage
FROM node:20-alpine AS builder
WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# Production stage
FROM node:20-alpine AS production
WORKDIR /app

# Security: non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/package.json ./

USER nodejs
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "dist/index.js"]
```

### docker-compose.yml (Development)

```yaml
version: '3.8'

services:
  app:
    build:
      context: .
      target: builder
    volumes:
      - .:/app
      - /app/node_modules
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev
      POSTGRES_DB: app_dev
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U dev"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
```

### .dockerignore

```text
.git
.gitignore
node_modules
npm-debug.log
Dockerfile*
docker-compose*
.dockerignore
.env
.env.*
!.env.example
coverage
__tests__
*.test.js
*.spec.js
README.md
docs/
.vscode
.idea
```

---

## Best Practices Check

| Check | Description |
|-------|-------------|
| Multi-stage build | Separate build and runtime |
| Non-root user | Security hardening |
| Layer caching | Dependencies before code |
| .dockerignore | Minimize context size |
| Health check | Container health monitoring |
| Pinned versions | Reproducible builds |

---

## Stack Templates

| Stack | Base Image | Features |
|-------|------------|----------|
| Node.js | `node:20-alpine` | Multi-stage, npm ci |
| Python | `python:3.11-slim` | pip, gunicorn |
| Go | `golang:1.21-alpine` | Static binary |
| PHP/Laravel | `php:8.3-fpm-alpine` | Composer, nginx |

---

## Output Format

```markdown
## Docker Configuration

### Files Generated

1. `Dockerfile` — Multi-stage production build
2. `docker-compose.yml` — Development environment
3. `.dockerignore` — Build context exclusions

### Security Features

- [x] Non-root user
- [x] Health check
- [x] Minimal base image
- [x] No secrets in image

### Commands

\`\`\`bash
# Build
docker build -t myapp:latest .

# Run
docker compose up -d

# Logs
docker compose logs -f app
\`\`\`
```

---

## Actions

1. Detect project stack (package.json, requirements.txt, go.mod, composer.json)
2. Generate appropriate Dockerfile with best practices
3. Create docker-compose.yml for development
4. Generate .dockerignore
5. Run security and optimization checks
