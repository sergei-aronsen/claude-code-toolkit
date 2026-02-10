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

### Dockerfile (Key Patterns)

```dockerfile
# Multi-stage: build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Multi-stage: production stage (minimal image)
FROM node:20-alpine AS production
WORKDIR /app
RUN addgroup -S nodejs && adduser -S nodejs  # Non-root user
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
USER nodejs
HEALTHCHECK CMD wget --spider http://localhost:3000/health || exit 1
CMD ["node", "dist/index.js"]
```

### docker-compose.yml (Key Patterns)

```yaml
services:
  app:
    build: { context: ., target: builder }
    volumes: [".:/app", "/app/node_modules"]
    ports: ["3000:3000"]
    depends_on:
      db: { condition: service_healthy }
  db:
    image: postgres:16-alpine
    volumes: ["postgres_data:/var/lib/postgresql/data"]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U dev"]
volumes:
  postgres_data:
```

### .dockerignore

Exclude: `.git`, `node_modules`, `.env`, `docs/`, `coverage`, `__tests__`, `*.test.js`, IDE files (`.vscode`, `.idea`)

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
Dockerfile, docker-compose.yml, .dockerignore

### Security
Non-root user, health check, minimal base image, no secrets in image

### Commands
Build, run, and logs commands for the project
```

---

## Actions

1. Detect project stack (package.json, requirements.txt, go.mod, composer.json)
2. Generate appropriate Dockerfile with best practices
3. Create docker-compose.yml for development
4. Generate .dockerignore
5. Run security and optimization checks

---

## Related Commands

- `/deploy` — safe deployment workflow (including Docker-based deploys)
- `/verify` — run verification checks before building images
- `/audit security` — audit Dockerfile and compose for security issues
