---
name: Docker
description: Docker and container best practices — Dockerfile patterns, multi-stage builds, compose, security. Triggers on docker/container/dockerfile/compose keywords.
---

# Docker Skill

> Load this skill when working with containers, Dockerfiles, or docker-compose.

---

## Rule

**ALWAYS FOLLOW DOCKER BEST PRACTICES!**

When creating Dockerfiles or compose files:

- Use multi-stage builds
- Run as non-root user
- Minimize image size
- Leverage layer caching

---

## Dockerfile Best Practices

### Multi-Stage Build

```dockerfile
# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Production stage
FROM node:20-alpine AS production
WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy only necessary files
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=nodejs:nodejs . .

USER nodejs
EXPOSE 3000
CMD ["node", "dist/index.js"]
```

### Layer Caching Order

```dockerfile
# GOOD: Dependencies first (rarely change)
COPY package*.json ./
RUN npm ci
COPY . .

# BAD: Everything together (breaks cache)
COPY . .
RUN npm ci
```

### Security Hardening

```dockerfile
# Non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001
USER appuser

# Read-only filesystem
# Use in docker-compose: read_only: true

# No new privileges
# Use in docker-compose: security_opt: - no-new-privileges:true

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1
```

---

## Docker Compose Patterns

### Development Setup

```yaml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.dev
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
      test: ["CMD-SHELL", "pg_isready -U dev -d app_dev"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
```

### Production Setup

```yaml
version: '3.8'

services:
  app:
    image: myapp:${VERSION:-latest}
    restart: unless-stopped
    read_only: true
    security_opt:
      - no-new-privileges:true
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 128M
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

---

## .dockerignore

```text
# Git
.git
.gitignore

# Dependencies
node_modules
vendor

# Build artifacts
dist
build
*.log

# IDE
.idea
.vscode
*.swp

# Environment
.env
.env.*
!.env.example

# Tests
coverage
__tests__
*.test.js
*.spec.js

# Docs
README.md
docs/

# Docker
Dockerfile*
docker-compose*
.dockerignore
```

---

## Common Commands

```bash
# Build
docker build -t myapp:latest .
docker build -t myapp:latest --target production .  # Multi-stage

# Run
docker run -d -p 3000:3000 --name myapp myapp:latest
docker run --rm -it myapp:latest sh  # Debug shell

# Compose
docker compose up -d
docker compose up -d --build  # Rebuild
docker compose down -v  # Remove volumes
docker compose logs -f app

# Debug
docker exec -it myapp sh
docker logs -f myapp
docker stats

# Cleanup
docker system prune -a  # Remove all unused
docker volume prune  # Remove unused volumes
docker image prune  # Remove dangling images
```

---

## Image Size Optimization

| Base Image | Size | Use Case |
|------------|------|----------|
| `node:20` | ~1GB | Full features |
| `node:20-slim` | ~200MB | Most apps |
| `node:20-alpine` | ~130MB | Smallest |
| `distroless/nodejs20` | ~120MB | Security-focused |

### Size Reduction Tips

1. Use Alpine-based images
2. Multi-stage builds
3. Clean package manager cache
4. Combine RUN commands
5. Remove dev dependencies

```dockerfile
# Clean in same layer
RUN npm ci --only=production && \
    npm cache clean --force
```

---

## Health Checks

### HTTP Health Check

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1
```

### TCP Health Check

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s \
  CMD nc -z localhost 3000 || exit 1
```

### Custom Script

```dockerfile
COPY healthcheck.sh /usr/local/bin/
HEALTHCHECK --interval=30s CMD healthcheck.sh
```

---

## When to Use This Skill

- Creating new Dockerfile
- Setting up docker-compose
- Optimizing image size
- Adding health checks
- Securing containers
- Debugging container issues
