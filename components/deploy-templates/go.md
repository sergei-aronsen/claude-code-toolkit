# Deploy Templates — Go

Operational runbook templates for deploying a Go service: build flags,
systemd unit, multi-stage Docker, post-deploy verification, rollback
scripts. Consumed via the base `DEPLOY_CHECKLIST.md` → `Stack Specifics →
Go` reference.

These are **templates**, not a checklist. The pre-deploy decision gates
(baseline metrics, auth/crypto, CSRF, post-deploy comparison, rollback
triggers, time boundaries) live in
`templates/base/prompts/DEPLOY_CHECKLIST.md` — consult that file first.

---

## Production Build

Static binary with stripped symbols and embedded version info:

```bash
VERSION=$(git describe --tags --always --dirty)
BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
COMMIT=$(git rev-parse --short HEAD)

CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
  go build -ldflags="-s -w \
    -X main.version=$VERSION \
    -X main.buildTime=$BUILD_TIME \
    -X main.commit=$COMMIT" \
  -o bin/app cmd/api/main.go
```

- `CGO_ENABLED=0` — static binary, no glibc dependency.
- `-ldflags="-s -w"` — strip debug info, ~30% smaller binary.
- `-X main.version=...` — embed `git describe` into the binary so
  `--version` returns the deploy SHA.

Verify the build:

```bash
ls -lh bin/app                                  # 5-30 MB typical
file bin/app                                    # statically linked
ldd bin/app 2>&1 | grep -q "not a dynamic"      # true on Linux
./bin/app --version                             # version embedded?
```

---

## Systemd Deployment

Unit file (`/etc/systemd/system/app.service`):

```ini
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

Deploy script (`deploy-systemd.sh`):

```bash
#!/bin/bash
set -e

APP_NAME="app"
APP_DIR="/opt/app"
BINARY="bin/app"
BACKUP_DIR="/opt/app/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# 1. Backup current binary
if [ -f "$APP_DIR/$BINARY" ]; then
    mkdir -p "$BACKUP_DIR"
    cp "$APP_DIR/$BINARY" "$BACKUP_DIR/app_$DATE"
fi

# 2. Stop service gracefully
sudo systemctl stop "$APP_NAME"

# 3. Copy new binary
cp "./bin/app" "$APP_DIR/$BINARY"
chmod +x "$APP_DIR/$BINARY"

# 4. Run database migrations (uncomment one)
# migrate -path ./migrations -database "$DATABASE_URL" up
# goose -dir ./migrations up

# 5. Start service
sudo systemctl start "$APP_NAME"

# 6. Verify service is running
sleep 3
systemctl is-active --quiet "$APP_NAME" || {
    sudo journalctl -u "$APP_NAME" --no-pager -n 20
    exit 1
}

# 7. Health check
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)
[ "$HTTP_CODE" -eq 200 ] || exit 1
```

---

## Docker Deployment

Multi-stage `Dockerfile`:

```dockerfile
# Stage 1: Build
FROM golang:1.22-alpine AS builder
WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download
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

Compose (`docker-compose.yaml`):

```yaml
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

Deploy script (`deploy-docker.sh`):

```bash
#!/bin/bash
set -e

IMAGE_NAME="app"
IMAGE_TAG=$(git describe --tags --always --dirty)
REGISTRY="registry.example.com"

docker build -t "$REGISTRY/$IMAGE_NAME:$IMAGE_TAG" .
docker tag "$REGISTRY/$IMAGE_NAME:$IMAGE_TAG" "$REGISTRY/$IMAGE_NAME:latest"

docker push "$REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
docker push "$REGISTRY/$IMAGE_NAME:latest"

docker compose pull
docker compose up -d --force-recreate app

sleep 5
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)
[ "$HTTP_CODE" -eq 200 ] || {
    docker compose logs app --tail 50
    exit 1
}

docker image prune -f
```

---

## Post-Deploy Verification

Smoke tests with response time:

```bash
curl -s http://localhost:8080/health | jq .
curl -w "DNS: %{time_namelookup}s | Connect: %{time_connect}s | TTFB: %{time_starttransfer}s | Total: %{time_total}s\n" \
  -o /dev/null -s http://localhost:8080/health
```

pprof inspection (when pprof endpoint enabled):

```bash
# Goroutine count — should be stable, not growing
curl -s http://localhost:6060/debug/pprof/goroutine?debug=1 | head -5

# Heap profile
curl -s http://localhost:6060/debug/pprof/heap?debug=1 | head -20

# Load test (hey)
hey -n 1000 -c 50 http://localhost:8080/health
```

Error monitoring:

```bash
# Systemd
sudo journalctl -u app --since "5 minutes ago" | grep -iE "error|panic|fatal"

# Docker
docker compose logs app --since 5m | grep -iE "error|panic|fatal"
```

---

## Rollback Scripts

Binary rollback (`rollback-systemd.sh`):

```bash
#!/bin/bash
set -e

APP_NAME="app"
APP_DIR="/opt/app"
BACKUP_DIR="/opt/app/backups"

LATEST_BACKUP=$(ls -t "$BACKUP_DIR/" | head -1)
[ -z "$LATEST_BACKUP" ] && { echo "No backup found"; exit 1; }

sudo systemctl stop "$APP_NAME"
cp "$BACKUP_DIR/$LATEST_BACKUP" "$APP_DIR/bin/app"
chmod +x "$APP_DIR/bin/app"
sudo systemctl start "$APP_NAME"

sleep 3
systemctl is-active --quiet "$APP_NAME" || exit 1

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)
[ "$HTTP_CODE" -eq 200 ] || exit 1
```

Docker rollback (`rollback-docker.sh`):

```bash
#!/bin/bash
set -e

REGISTRY="registry.example.com"
IMAGE_NAME="app"

PREVIOUS_TAG=$(docker images "$REGISTRY/$IMAGE_NAME" --format "{{.Tag}}" | sed -n '2p')
[ -z "$PREVIOUS_TAG" ] && { echo "No previous tag"; exit 1; }

IMAGE_TAG="$PREVIOUS_TAG" docker compose up -d --force-recreate app

sleep 5
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)
[ "$HTTP_CODE" -eq 200 ] || {
    docker compose logs app --tail 50
    exit 1
}
```

Database rollback:

```bash
# golang-migrate
migrate -path ./migrations -database "$DATABASE_URL" down 1

# goose
goose -dir ./migrations down

# atlas
atlas migrate status --dir "file://migrations" --url "$DATABASE_URL"

# Full restore (last resort)
pg_restore -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c backup_YYYYMMDD_HHMMSS.dump
```

---

## Go-Specific Rollback Triggers

Beyond the generic triggers in `base/prompts/DEPLOY_CHECKLIST.md §8.2`,
roll back immediately when:

- Goroutine count growing unbounded (pprof goroutine profile keeps
  rising over 30 min) — leaked goroutines.
- Heap allocations keep growing without GC reclaim — likely a leak via
  a long-lived reference (sync.Pool misuse, dangling channels, package
  global).
- `panic` lines in `journalctl -u app` — even one panic is a hard
  rollback signal in Go (panics indicate state corruption, not a
  recoverable error).
