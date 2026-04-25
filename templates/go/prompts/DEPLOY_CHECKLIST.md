# Deploy Checklist — Go Template

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

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

## 10. SELF-CHECK (FP Recheck — 6-Step Procedure)
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

## 11. OUTPUT FORMAT (Structured Report Schema — Phase 14)
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

1. **Check** — go through checklist (sections 0-6)
2. **Backup** — create database backup
3. **Build** — produce production binary
4. **Deploy** — execute deployment (section 7)
5. **Verify** — post-deployment checks (section 8)
6. **Monitor** — watch logs and metrics for 24h

Reply: "OK: Ready to deploy (XX%)" or "FAIL: Issues: [list]"

## Council Handoff
<!-- v42-splice: council-handoff -->

When the structured report is complete, hand it off to the Supreme Council for
peer review. See `commands/audit.md` Phase 5 (Council Pass — mandatory) for the
invocation: `/council audit-review --report <path>`. The Council runs in
audit-review mode (see `commands/council.md` `## Modes`). The Council verdict
slot in the report is pre-populated with the byte-exact placeholder
`_pending — run /council audit-review_` (U+2014 em-dash) and is overwritten by
the Council pass.
