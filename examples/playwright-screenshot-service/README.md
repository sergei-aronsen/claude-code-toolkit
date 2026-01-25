# Playwright Screenshot Service Configuration

## Overview

Firecrawl Playwright service configuration for bulk website screenshot generation.

## File Locations

| File           | Path                                   | Purpose                  |
| -------------- | -------------------------------------- | ------------------------ |
| Docker Compose | `/opt/firecrawl/docker-compose.yaml`   | Container configuration  |
| Environment    | `/opt/firecrawl/.env`                  | Environment variables    |

## Key Settings

### Environment Variables (.env)

```bash
# Number of parallel Playwright pages
CRAWL_CONCURRENT_REQUESTS=50

# Maximum parallel jobs
MAX_CONCURRENT_JOBS=20
```

### Docker Resources (docker-compose.yaml)

```yaml
playwright-service:
  environment:
    MAX_CONCURRENT_PAGES: ${CRAWL_CONCURRENT_REQUESTS:-10}
  cpus: 4.0        # CPU limit
  mem_limit: 32G   # RAM limit
  memswap_limit: 32G
```

## Management Commands

### Check Status

```bash
curl http://127.0.0.1:3001/health
# Response: {"status":"healthy","maxConcurrentPages":50,"activePages":50}
```

### Restart Service

```bash
cd /opt/firecrawl
docker compose stop playwright-service
docker rm -f firecrawl-playwright-service-1
docker compose up -d playwright-service
```

### View Logs

```bash
docker logs -f firecrawl-playwright-service-1
```

## Performance Optimization

### Bottleneck: maxConcurrentPages

The main limiter is `maxConcurrentPages`. Default is 10, which creates a queue even with 100 workers.

**Recommendations:**

- Increase `CRAWL_CONCURRENT_REQUESTS` proportionally to the number of workers
- Monitor `activePages` in the health endpoint
- When `activePages == maxConcurrentPages` — increase the limit

### Docker CPU Limitation

**IMPORTANT:** Docker may not see all host CPUs after a VM upgrade.

```bash
# Check host CPUs
nproc  # 36

# Check CPUs in Docker
docker info | grep CPUs  # CPUs: 4

# If there's a discrepancy — Docker daemon restart is needed
sudo systemctl restart docker
```

## Troubleshooting

### Screenshots Not Being Taken / Slow

1. Check health: `curl http://127.0.0.1:3001/health`
2. If `activePages == maxConcurrentPages` — increase `CRAWL_CONCURRENT_REQUESTS`
3. Check logs: `docker logs firecrawl-playwright-service-1`

### cURL error 52: Empty reply from server

Playwright service is overloaded or crashed. Solution:

- Restart the container
- Decrease `CRAWL_CONCURRENT_REQUESTS` or increase resources

### Container conflict on restart

```bash
docker rm -f firecrawl-playwright-service-1
docker compose up -d playwright-service
```

## Tips

### Hide Cookie Banners

Use [idcac-playwright](https://www.npmjs.com/package/idcac-playwright) to automatically dismiss cookie consent popups before taking screenshots:

```typescript
import { getInjectableScript } from 'idcac-playwright';

// After page.goto()
await page.evaluate(getInjectableScript());
// Then take screenshot
```

### Screenshot Formats

Playwright supports only `png` and `jpeg`. For WebP, convert after capture:

```bash
cwebp screenshot.png -o screenshot.webp
```
