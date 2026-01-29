# Deploy Checklist — Go Template

## Goal

Comprehensive pre-deploy verification for a Go application. Act as a Senior DevOps Engineer.

> **Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for pre-deploy verification — works better with code analysis.

---

## 0. QUICK CHECK (5 minutes)

| # | Check | Command | Expected |
| --- | ------- | --------- | ---------- |
| 1 | Build | `go build ./...` | Success |
| 2 | Vet | `go vet ./...` | No issues |
| 3 | Lint | `golangci-lint run` | No errors |
| 4 | Tests | `go test -race ./...` | Pass |
| 5 | Vuln check | `govulncheck ./...` | No vulnerabilities |
| 6 | Mod verify | `go mod verify` | All verified |

**If all 6 = OK -> Ready to deploy!**

---

## 0.1 AUTO-CHECK SCRIPT

```bash
#!/bin/bash
# deploy-check.sh — run before deployment

set -e

echo "Pre-deploy Check for Go..."

# 1. Build
go build ./... > /dev/null 2>&1 && echo "OK Build" || { echo "FAIL Build"; exit 1; }

# 2. Vet
go vet ./... > /dev/null 2>&1 && echo "OK Vet" || echo "WARN Vet has issues"

# 3. Lint
if command -v golangci-lint &> /dev/null; then
    golangci-lint run > /dev/null 2>&1 && echo "OK Lint" || echo "WARN Lint has issues"
else
    echo "SKIP golangci-lint not installed"
fi

# 4. Tests with race detection
go test -race ./... > /dev/null 2>&1 && echo "OK Tests" || { echo "FAIL Tests"; exit 1; }

# 5. Vulnerability check
if command -v govulncheck &> /dev/null; then
    govulncheck ./... > /dev/null 2>&1 && echo "OK Vulnerabilities" || echo "WARN Vulnerabilities found"
else
    echo "SKIP govulncheck not installed"
fi

# 6. Module verification
go mod verify > /dev/null 2>&1 && echo "OK Modules verified" || echo "WARN Module verification failed"

# 7. Debug code check
DEBUG_COUNT=$(grep -rn "fmt.Println\|fmt.Printf" --include="*.go" . 2>/dev/null | grep -v "_test.go" | grep -v "vendor/" | wc -l | tr -d ' ')
[ "$DEBUG_COUNT" -lt 5 ] && echo "OK fmt.Print: $DEBUG_COUNT" || echo "WARN fmt.Print found: $DEBUG_COUNT (review needed)"

TODO_COUNT=$(grep -rn "TODO\|FIXME" --include="*.go" . 2>/dev/null | grep -v "vendor/" | wc -l | tr -d ' ')
[ "$TODO_COUNT" -lt 10 ] && echo "OK TODO/FIXME: $TODO_COUNT" || echo "WARN TODO/FIXME: $TODO_COUNT (review needed)"

echo ""
echo "Pre-deploy check complete!"
```

---

## 0.2 PROJECT SPECIFICS — [Project Name]

**Deployment target:**

- **Server**: [IP/hostname]
- **Path**: [/opt/app or /usr/local/bin/app]
- **URL**: [https://...]
- **Process manager**: [systemd/Docker/Kubernetes]

**Database:**

- **Type**: [PostgreSQL / MySQL / MongoDB]
- **Host**: [host]
- **Name**: [db_name]
- **Connection**: see `DATABASE_URL` in env

**Important files:**

- `.env` or environment variables — configuration
- `config.yaml` / `config.toml` — application config (if applicable)
- `/etc/systemd/system/app.service` — systemd unit (if applicable)
- `docker-compose.yaml` — Docker config (if applicable)

---

## 0.3 DEPLOY TYPES

| Type | When | Checklist |
| ----- | ------- | --------- |
| Hotfix | Critical bug | Quick Check only |
| Minor | Small changes | Quick Check + section 1 |
| Feature | New functionality | Sections 0-8 |
| Major | Architectural changes | Full checklist |

---

## 1. PRE-DEPLOYMENT CODE CLEANUP

### 1.1 Debug Code Removal

```bash
# Find debug print statements (excluding tests and vendor)
grep -rn "fmt.Println\|fmt.Printf" --include="*.go" . | grep -v "_test.go" | grep -v "vendor/"

# Find debug log statements
grep -rn 'log.Print\|log.Printf\|log.Println' --include="*.go" . | grep -v "_test.go" | grep -v "vendor/" | grep -i "debug"

# Find TODO/FIXME in critical code
grep -rn "TODO\|FIXME\|HACK\|XXX" --include="*.go" . | grep -v "vendor/"

# Find panic calls (should not be in production handlers)
grep -rn "panic(" --include="*.go" . | grep -v "_test.go" | grep -v "vendor/"
```

- [ ] No unnecessary `fmt.Println()` / `fmt.Printf()` outside logging
- [ ] No debug-level log statements with sensitive data
- [ ] Critical `TODO`/`FIXME` items resolved
- [ ] No `panic()` in HTTP handlers or service layer

### 1.2 Commented Code

- [ ] No commented out code blocks
- [ ] No old function versions left as comments
- [ ] No `// TODO: remove` blocks

### 1.3 Temporary Files

```bash
# Find temporary and backup files
find . -name "*.bak" -o -name "*.tmp" -o -name "*.old" -o -name "*.orig" | grep -v vendor/
find . -name "*.test" -not -name "*_test.go" | grep -v vendor/
```

- [ ] No `.bak`, `.tmp`, `.old`, `.orig` files
- [ ] No stale generated files

---

## 2. CODE QUALITY CHECKS

### 2.1 Build

```bash
# Verify clean build
go build ./...

# Verify no compilation warnings with all tags
go build -tags integration ./...
```

- [ ] `go build ./...` passes without errors
- [ ] All build tags compile cleanly

### 2.2 Static Analysis

```bash
# Built-in vet
go vet ./...

# golangci-lint (runs 100+ linters)
golangci-lint run

# golangci-lint with auto-fix
golangci-lint run --fix

# staticcheck (if installed separately)
staticcheck ./...
```

- [ ] `go vet` passes without issues
- [ ] `golangci-lint run` passes without errors
- [ ] No `staticcheck` findings in critical paths
- [ ] Code formatted with `gofmt` / `goimports`

### 2.3 Tests

```bash
# Run all tests with race detector
go test -race ./...

# Run tests with coverage
go test -cover ./...

# Generate coverage report
go test -coverprofile=coverage.out ./...
go tool cover -func=coverage.out

# Run integration tests (if tagged)
go test -race -tags integration ./...

# Run benchmarks to check for regressions
go test -bench=. -benchmem ./...
```

- [ ] All tests pass
- [ ] Race detector finds no issues
- [ ] Coverage is acceptable (target: > 60% for critical packages)
- [ ] No skipped tests without reason
- [ ] Benchmark results are within expected range

---

## 3. DATABASE PREPARATION

### 3.1 Migrations

```bash
# golang-migrate
migrate -path ./migrations -database "$DATABASE_URL" status
migrate -path ./migrations -database "$DATABASE_URL" up

# goose
goose -dir ./migrations status
goose -dir ./migrations up

# atlas
atlas migrate status --dir "file://migrations" --url "$DATABASE_URL"
atlas migrate apply --dir "file://migrations" --url "$DATABASE_URL"
```

```go
// Good — nullable column for existing records
// ALTER TABLE users ADD COLUMN avatar_url TEXT;

// Dangerous — NOT NULL without default on existing table
// ALTER TABLE users ADD COLUMN role VARCHAR(50) NOT NULL;
// Fix: ADD COLUMN role VARCHAR(50) NOT NULL DEFAULT 'user';
```

- [ ] All migrations have corresponding rollback (down) files
- [ ] New NOT NULL columns have default values
- [ ] Indexes added for new foreign keys and frequently queried columns
- [ ] Migration dry run verified on staging
- [ ] Rollback tested

### 3.2 Backup

```bash
# PostgreSQL
pg_dump -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" \
  -F c -f "backup_$(date +%Y%m%d_%H%M%S).dump"

# MySQL
mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
  > "backup_$(date +%Y%m%d_%H%M%S).sql"

# Verify backup
pg_restore --list "backup_*.dump" | head -20
```

- [ ] Database backup created before migrations
- [ ] Backup verified for restorability
- [ ] Backup stored in a safe location (not on the same server)

---

## 4. ENVIRONMENT CONFIGURATION

### 4.1 Production Environment

```bash
# Required environment variables
APP_ENV=production
PORT=8080
LOG_LEVEL=info
GIN_MODE=release

# Database
DATABASE_URL=postgres://user:password@host:5432/dbname?sslmode=require

# Timeouts
READ_TIMEOUT=5s
WRITE_TIMEOUT=10s
IDLE_TIMEOUT=120s
SHUTDOWN_TIMEOUT=30s

# TLS (if terminating at app level)
TLS_CERT_FILE=/etc/ssl/certs/app.crt
TLS_KEY_FILE=/etc/ssl/private/app.key
```

- [ ] `APP_ENV=production` (not `development` or `local`)
- [ ] `GIN_MODE=release` (or equivalent for your framework)
- [ ] `LOG_LEVEL` is `info` or `warn` (not `debug`)
- [ ] `DATABASE_URL` points to production database with `sslmode=require`
- [ ] `PORT` is set correctly
- [ ] Timeout values are configured (read, write, idle, shutdown)
- [ ] TLS certificates are valid and not expiring soon

### 4.2 Secrets Check

```bash
# Check for hardcoded credentials in source code
grep -rn "password\|secret\|api_key\|apikey\|token" --include="*.go" . \
  | grep -v "_test.go" | grep -v "vendor/" | grep -v "\.example" \
  | grep -i "=\s*\"[a-zA-Z0-9]"

# Check for hardcoded connection strings
grep -rn "postgres://\|mysql://\|mongodb://" --include="*.go" . \
  | grep -v "_test.go" | grep -v "vendor/"

# Verify .env is in .gitignore
grep -q "\.env" .gitignore && echo "OK .env in .gitignore" || echo "WARN .env NOT in .gitignore"
```

- [ ] No hardcoded passwords or API keys
- [ ] No hardcoded connection strings
- [ ] `.env` file is in `.gitignore`
- [ ] All secrets are loaded from environment variables or a secret manager

---

## 5. BUILD PROCESS

### 5.1 Production Build

```bash
# Standard production build (static binary, stripped symbols)
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
  go build -ldflags="-s -w" -o bin/app cmd/api/main.go

# Build with version info embedded
VERSION=$(git describe --tags --always --dirty)
BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
COMMIT=$(git rev-parse --short HEAD)

CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
  go build -ldflags="-s -w \
    -X main.version=$VERSION \
    -X main.buildTime=$BUILD_TIME \
    -X main.commit=$COMMIT" \
  -o bin/app cmd/api/main.go

# Clean module cache and rebuild
go clean -cache
go mod download
go build -ldflags="-s -w" -o bin/app cmd/api/main.go
```

- [ ] `CGO_ENABLED=0` for static binary (no C dependencies)
- [ ] `-ldflags="-s -w"` to strip debug info and reduce binary size
- [ ] `GOOS` and `GOARCH` set for target platform
- [ ] Version info embedded via `-ldflags -X`
- [ ] Build succeeds without errors

### 5.2 Build Verification

```bash
# Check binary size (typical Go binary: 5-30MB)
ls -lh bin/app

# Verify it is statically linked (Linux)
ldd bin/app 2>&1 | grep -q "not a dynamic executable" && \
  echo "OK Static binary" || echo "WARN Dynamic binary"

# Or use file command
file bin/app

# Check embedded version
./bin/app --version

# Quick smoke test
timeout 5 ./bin/app &
sleep 2
curl -s http://localhost:8080/health
kill %1 2>/dev/null
```

- [ ] Binary size is reasonable (typically 5-30MB for a Go service)
- [ ] Binary is statically linked (no dynamic library dependencies)
- [ ] Version info is correctly embedded
- [ ] Binary starts and responds to health check

---

## 6. SECURITY PRE-CHECK

### 6.1 Dependencies Audit

```bash
# govulncheck (official Go vulnerability scanner)
govulncheck ./...

# nancy (Sonatype vulnerability scanner)
go list -json -deps ./... | nancy sleuth

# Check for outdated dependencies
go list -u -m all

# Ensure go.sum is up to date
go mod tidy
git diff go.sum
```

- [ ] `govulncheck` reports no critical vulnerabilities
- [ ] No known vulnerable dependencies
- [ ] Dependencies are reasonably up to date
- [ ] `go.sum` has not changed unexpectedly

### 6.2 go.sum Verification

```bash
# Verify all downloaded modules match go.sum checksums
go mod verify

# Ensure no unexpected changes to go.mod or go.sum
git diff go.mod go.sum
```

- [ ] `go mod verify` passes (all modules match checksums)
- [ ] No unexpected changes to `go.mod` or `go.sum`
- [ ] No `replace` directives pointing to local paths

### 6.3 Sensitive Files

```bash
# Ensure sensitive files are not included in the repository
git ls-files | grep -E "\.env$|\.pem$|\.key$|\.p12$|\.pfx$|credentials"

# Check .gitignore covers sensitive patterns
grep -E "\.env|\.pem|\.key|\.p12" .gitignore
```

- [ ] `.env` files not in repository
- [ ] No `.pem`, `.key`, `.p12` private keys committed
- [ ] No credentials or tokens in source code
- [ ] `.gitignore` covers all sensitive file patterns

---

## 7. DEPLOYMENT

### 7.1 Systemd Deployment

```ini
# /etc/systemd/system/app.service
[Unit]
Description=Go Application
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=appuser
Group=appuser
WorkingDirectory=/opt/app
ExecStart=/opt/app/bin/app
Restart=always
RestartSec=5
LimitNOFILE=65535

# Environment
EnvironmentFile=/opt/app/.env

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/app/data /var/log/app

# Resource limits
MemoryMax=512M
CPUQuota=200%

[Install]
WantedBy=multi-user.target
```

```bash
#!/bin/bash
# deploy-systemd.sh — deploy Go binary via systemd

set -e

APP_NAME="app"
APP_DIR="/opt/app"
BINARY="bin/app"
BACKUP_DIR="/opt/app/backups"
DATE=$(date +%Y%m%d_%H%M%S)

echo "Deploying $APP_NAME..."

# 1. Backup current binary
if [ -f "$APP_DIR/$BINARY" ]; then
    mkdir -p "$BACKUP_DIR"
    cp "$APP_DIR/$BINARY" "$BACKUP_DIR/app_$DATE"
    echo "Backed up current binary"
fi

# 2. Stop service gracefully
sudo systemctl stop "$APP_NAME"
echo "Service stopped"

# 3. Copy new binary
cp "./bin/app" "$APP_DIR/$BINARY"
chmod +x "$APP_DIR/$BINARY"
echo "New binary deployed"

# 4. Run database migrations (if needed)
# migrate -path ./migrations -database "$DATABASE_URL" up

# 5. Start service
sudo systemctl start "$APP_NAME"
echo "Service started"

# 6. Verify service is running
sleep 3
if systemctl is-active --quiet "$APP_NAME"; then
    echo "OK Service is running"
else
    echo "FAIL Service failed to start"
    sudo journalctl -u "$APP_NAME" --no-pager -n 20
    exit 1
fi

# 7. Health check
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)
if [ "$HTTP_CODE" -eq 200 ]; then
    echo "OK Health check passed"
else
    echo "FAIL Health check failed (HTTP $HTTP_CODE)"
    exit 1
fi

echo "Deployment complete!"
```

- [ ] Systemd unit file is up to date
- [ ] Service user has correct permissions
- [ ] `EnvironmentFile` path is correct
- [ ] Resource limits are set (memory, CPU, file descriptors)
- [ ] Security hardening directives applied

### 7.2 Docker Deployment

```yaml
# docker-compose.yaml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
    environment:
      - APP_ENV=production
      - GIN_MODE=release
      - DATABASE_URL=postgres://user:password@db:5432/appdb?sslmode=disable
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: "1.0"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
      POSTGRES_DB: appdb
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d appdb"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
```

```bash
# Dockerfile — multi-stage build
# Stage 1: Build
FROM golang:1.22-alpine AS builder

WORKDIR /build

# Cache dependencies
COPY go.mod go.sum ./
RUN go mod download

# Build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w" -o app cmd/api/main.go

# Stage 2: Runtime
FROM alpine:3.19

RUN apk --no-cache add ca-certificates tzdata curl

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

COPY --from=builder /build/app .
COPY --from=builder /build/migrations ./migrations

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["./app"]
```

```bash
#!/bin/bash
# deploy-docker.sh — deploy via Docker

set -e

IMAGE_NAME="app"
IMAGE_TAG=$(git describe --tags --always --dirty)
REGISTRY="registry.example.com"

echo "Building Docker image..."

# 1. Build image
docker build -t "$REGISTRY/$IMAGE_NAME:$IMAGE_TAG" .
docker tag "$REGISTRY/$IMAGE_NAME:$IMAGE_TAG" "$REGISTRY/$IMAGE_NAME:latest"

# 2. Push to registry
docker push "$REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
docker push "$REGISTRY/$IMAGE_NAME:latest"

# 3. Deploy
docker compose pull
docker compose up -d --force-recreate app

# 4. Health check
echo "Waiting for application to start..."
sleep 5

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)
if [ "$HTTP_CODE" -eq 200 ]; then
    echo "OK Health check passed"
else
    echo "FAIL Health check failed (HTTP $HTTP_CODE)"
    docker compose logs app --tail 50
    exit 1
fi

# 5. Clean up old images
docker image prune -f

echo "Docker deployment complete!"
```

- [ ] Multi-stage Dockerfile used (build + runtime)
- [ ] Final image uses minimal base (Alpine or scratch)
- [ ] Non-root user in container
- [ ] Health check configured
- [ ] Resource limits set in compose/orchestrator
- [ ] Image tagged with version (not just `latest`)

---

## 8. POST-DEPLOYMENT VERIFICATION

### 8.1 Smoke Tests

```bash
# Health check endpoint
curl -s http://localhost:8080/health | jq .

# API version check
curl -s http://localhost:8080/api/version | jq .

# Check HTTP status codes for key endpoints
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/health
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/v1/status

# Check response time
curl -w "DNS: %{time_namelookup}s | Connect: %{time_connect}s | TTFB: %{time_starttransfer}s | Total: %{time_total}s\n" \
  -o /dev/null -s http://localhost:8080/health
```

- [ ] Health endpoint returns 200
- [ ] API responds correctly
- [ ] Authentication works
- [ ] Core functionality operational
- [ ] Response times are within acceptable range

### 8.2 Error Monitoring

```bash
# Systemd logs
sudo journalctl -u app --no-pager -n 50
sudo journalctl -u app --since "5 minutes ago" | grep -i "error\|panic\|fatal"

# Docker logs
docker compose logs app --tail 100
docker compose logs app --since 5m | grep -i "error\|panic\|fatal"

# Application log file (if writing to file)
tail -f /var/log/app/app.log
grep -i "error\|panic\|fatal" /var/log/app/app.log | tail -20
```

- [ ] No panic or fatal errors in logs
- [ ] No unexpected error messages
- [ ] Error rate has not increased compared to before deploy
- [ ] No goroutine leaks (check with pprof if available)

### 8.3 Performance Check

```bash
# Check process memory usage
ps aux | grep app | grep -v grep

# Check binary startup time
time ./bin/app --version

# Check open file descriptors
ls /proc/$(pgrep app)/fd | wc -l

# Check goroutine count (if pprof enabled)
curl -s http://localhost:6060/debug/pprof/goroutine?debug=1 | head -5

# Memory stats (if pprof enabled)
curl -s http://localhost:6060/debug/pprof/heap?debug=1 | head -20

# Quick load test (if hey is installed)
hey -n 1000 -c 50 http://localhost:8080/health
```

- [ ] Memory usage is reasonable (compare to baseline)
- [ ] Binary starts within expected time (< 2s for most services)
- [ ] Goroutine count is stable (not growing unbounded)
- [ ] Response latency is within SLA

---

## 9. ROLLBACK PLAN

### 9.1 Binary Rollback (Systemd)

```bash
#!/bin/bash
# rollback-systemd.sh — rollback to previous binary

set -e

APP_NAME="app"
APP_DIR="/opt/app"
BACKUP_DIR="/opt/app/backups"

# List available backups
echo "Available backups:"
ls -lt "$BACKUP_DIR/"

# Get the most recent backup
LATEST_BACKUP=$(ls -t "$BACKUP_DIR/" | head -1)

if [ -z "$LATEST_BACKUP" ]; then
    echo "FAIL No backup found"
    exit 1
fi

echo "Rolling back to: $LATEST_BACKUP"

# 1. Stop service
sudo systemctl stop "$APP_NAME"

# 2. Restore previous binary
cp "$BACKUP_DIR/$LATEST_BACKUP" "$APP_DIR/bin/app"
chmod +x "$APP_DIR/bin/app"

# 3. Start service
sudo systemctl start "$APP_NAME"

# 4. Verify
sleep 3
if systemctl is-active --quiet "$APP_NAME"; then
    echo "OK Rollback successful — service is running"
else
    echo "FAIL Service failed to start after rollback"
    sudo journalctl -u "$APP_NAME" --no-pager -n 20
    exit 1
fi

# 5. Health check
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)
if [ "$HTTP_CODE" -eq 200 ]; then
    echo "OK Health check passed after rollback"
else
    echo "FAIL Health check failed after rollback (HTTP $HTTP_CODE)"
    exit 1
fi
```

- [ ] Previous binary backup is available
- [ ] Rollback script tested and ready
- [ ] Team knows how to execute rollback

### 9.2 Docker Rollback

```bash
#!/bin/bash
# rollback-docker.sh — rollback to previous Docker image

set -e

REGISTRY="registry.example.com"
IMAGE_NAME="app"

# 1. Get previous tag
PREVIOUS_TAG=$(docker images "$REGISTRY/$IMAGE_NAME" --format "{{.Tag}}" | sed -n '2p')

if [ -z "$PREVIOUS_TAG" ]; then
    echo "FAIL No previous image tag found"
    exit 1
fi

echo "Rolling back to: $REGISTRY/$IMAGE_NAME:$PREVIOUS_TAG"

# 2. Update compose to use previous tag and redeploy
IMAGE_TAG="$PREVIOUS_TAG" docker compose up -d --force-recreate app

# 3. Verify
sleep 5
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)
if [ "$HTTP_CODE" -eq 200 ]; then
    echo "OK Docker rollback successful"
else
    echo "FAIL Health check failed after rollback (HTTP $HTTP_CODE)"
    docker compose logs app --tail 50
    exit 1
fi
```

- [ ] Previous Docker image is available in registry
- [ ] Rollback command documented and tested

### 9.3 Database Rollback

```bash
# golang-migrate — rollback last migration
migrate -path ./migrations -database "$DATABASE_URL" down 1

# goose — rollback last migration
goose -dir ./migrations down

# atlas — rollback (inspect current state first)
atlas migrate status --dir "file://migrations" --url "$DATABASE_URL"

# Full database restore from backup (last resort)
# PostgreSQL
pg_restore -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c backup_YYYYMMDD_HHMMSS.dump

# MySQL
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < backup_YYYYMMDD_HHMMSS.sql
```

- [ ] Migration rollback files exist and are tested
- [ ] Database backup is available and verified
- [ ] Restore procedure is documented

### 9.4 Rollback Triggers

Rollback immediately if:

- Error rate > 5% after deploy
- Panic or fatal errors in logs
- Critical functionality is broken (authentication, payments, core API)
- Database corruption detected
- Memory usage growing unbounded (goroutine/memory leak)
- Response latency degraded > 100% compared to baseline

---

## 10. SELF-CHECK

**DO NOT block deploy because of:**

| Seems like a blocker | Why it is not a blocker |
| -------------------- | ----------------------- |
| "golangci-lint warnings" | If build and tests pass — OK |
| "Deprecated dependency" | If it works — update later |
| "No tests for package X" | If functionality works — OK |
| "fmt.Println in utils" | Does not affect users, remove later |
| "Coverage below 80%" | If critical paths are covered — OK |
| "go vet informational" | Informational messages are not errors |
| "TODO comments exist" | If they are not blocking issues — OK |

**Readiness levels:**

```text
READY (95-100%) — Deploy now
   - Build passes
   - All tests pass with race detector
   - No critical vulnerabilities
   - Production config verified

ACCEPTABLE (70-94%) — Deploy possible
   - Has lint warnings but no errors
   - Minor issues can be fixed after
   - Non-critical TODOs remain

NOT READY (<70%) — Block
   - Build fails
   - Tests fail
   - Critical vulnerabilities found
   - Missing production configuration
   - Race conditions detected
```

---

## 11. REPORT FORMAT

```markdown
# Deploy Checklist Report — [Project Name]
Date: [date]
Version: [git commit hash / tag]
Go Version: [go version]

## Summary

| Step | Status |
|------|--------|
| Build | OK/FAIL |
| Vet | OK/FAIL |
| Lint | OK/FAIL |
| Tests | OK/FAIL |
| Vuln check | OK/FAIL |
| Migrations | OK/FAIL |
| Env config | OK/FAIL |
| Security | OK/FAIL |
| Deploy | OK/FAIL |
| Verify | OK/FAIL |

**Readiness**: XX% — [READY/ACCEPTABLE/NOT READY]

## Blockers

- [If any]

## Warnings

- [If any]

## Post-Deploy

- [ ] Monitor logs for 24h
- [ ] Check error rate after 1h
- [ ] Verify memory usage is stable after 4h
- [ ] Confirm goroutine count is stable
```

---

## 12. ACTIONS

1. **Check** — go through checklist (sections 0-6)
2. **Backup** — create database backup
3. **Build** — produce production binary
4. **Deploy** — execute deployment (section 7)
5. **Verify** — post-deployment checks (section 8)
6. **Monitor** — watch logs and metrics for 24h

Reply: "OK: Ready to deploy (XX%)" or "FAIL: Issues: [list]"
