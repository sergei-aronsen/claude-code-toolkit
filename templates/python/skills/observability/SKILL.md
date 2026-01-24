# Observability Skill

> Load this skill when implementing logging, metrics, tracing, or monitoring.

---

## Rule

**OBSERVE WHAT MATTERS, NOT EVERYTHING!**

- Log for debugging, not for storage
- Metrics for dashboards and alerts
- Traces for distributed debugging

---

## Three Pillars of Observability

| Pillar | Purpose | Use When |
|--------|---------|----------|
| **Logs** | Debug specific events | "What happened?" |
| **Metrics** | Aggregate measurements | "How much/many?" |
| **Traces** | Request flow across services | "Where did time go?" |

---

## Logging Best Practices

### Log Levels

| Level | Use Case | Examples |
|-------|----------|----------|
| `ERROR` | Failures requiring attention | Unhandled exceptions, failed payments |
| `WARN` | Potential issues | Retry attempts, deprecated usage |
| `INFO` | Business events | User registered, order placed |
| `DEBUG` | Diagnostic details | Function inputs/outputs, SQL queries |

### Structured Logging

```json
{
  "timestamp": "2024-01-15T10:30:00.000Z",
  "level": "info",
  "message": "User registered",
  "service": "auth-service",
  "traceId": "abc123",
  "userId": "user_456",
  "email": "user@example.com",
  "duration_ms": 45
}
```

### Logging Patterns

```typescript
// Good: Structured with context
logger.info('Order placed', {
  orderId: order.id,
  userId: user.id,
  total: order.total,
  items: order.items.length,
});

// Bad: Unstructured
logger.info(`Order ${order.id} placed for user ${user.id}`);
```

### What NOT to Log

- Passwords, tokens, API keys
- Full credit card numbers
- Personal data (GDPR)
- High-frequency debug logs in production

### Logger Setup

```typescript
// Pino (Node.js - fastest)
import pino from 'pino';

const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  formatters: {
    level: (label) => ({ level: label }),
  },
  base: {
    service: 'my-service',
    env: process.env.NODE_ENV,
  },
});
```

---

## Metrics

### Metric Types

| Type | Use Case | Example |
|------|----------|---------|
| **Counter** | Cumulative count | Requests total, errors total |
| **Gauge** | Current value | Active connections, queue size |
| **Histogram** | Distribution | Request duration, response size |
| **Summary** | Percentiles | p50, p95, p99 latency |

### Naming Conventions

```text
# Pattern: <namespace>_<name>_<unit>

http_requests_total              # Counter
http_request_duration_seconds    # Histogram
db_connections_active            # Gauge
queue_messages_pending           # Gauge
```

### Essential Metrics (RED Method)

| Metric | Description |
|--------|-------------|
| **R**ate | Requests per second |
| **E**rrors | Error rate (%) |
| **D**uration | Latency (p50, p95, p99) |

### Prometheus Examples

```typescript
import { Counter, Histogram, Registry } from 'prom-client';

const register = new Registry();

const httpRequestsTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'path', 'status'],
  registers: [register],
});

const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration',
  labelNames: ['method', 'path'],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 5],
  registers: [register],
});

// Usage
httpRequestsTotal.inc({ method: 'GET', path: '/users', status: 200 });
httpRequestDuration.observe({ method: 'GET', path: '/users' }, 0.045);
```

---

## Distributed Tracing

### OpenTelemetry Setup

```typescript
import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: 'http://jaeger:4318/v1/traces',
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
```

### Manual Spans

```typescript
import { trace } from '@opentelemetry/api';

const tracer = trace.getTracer('my-service');

async function processOrder(orderId: string) {
  return tracer.startActiveSpan('processOrder', async (span) => {
    span.setAttribute('orderId', orderId);

    try {
      const result = await doWork();
      span.setStatus({ code: SpanStatusCode.OK });
      return result;
    } catch (error) {
      span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
      span.recordException(error);
      throw error;
    } finally {
      span.end();
    }
  });
}
```

### Trace Context Propagation

```typescript
// Automatically propagated via HTTP headers
// W3C Trace Context: traceparent, tracestate

// Manual propagation
import { context, propagation } from '@opentelemetry/api';

const headers = {};
propagation.inject(context.active(), headers);
// headers = { traceparent: '00-abc123...' }
```

---

## Health Checks

### Endpoint Types

| Endpoint | Purpose | Response |
|----------|---------|----------|
| `/health` | Basic liveness | 200 if running |
| `/health/live` | Kubernetes liveness | 200 if process alive |
| `/health/ready` | Kubernetes readiness | 200 if ready for traffic |

### Health Check Implementation

```typescript
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.get('/health/ready', async (req, res) => {
  const checks = {
    database: await checkDatabase(),
    redis: await checkRedis(),
    external: await checkExternalService(),
  };

  const healthy = Object.values(checks).every((c) => c.status === 'ok');

  res.status(healthy ? 200 : 503).json({
    status: healthy ? 'ok' : 'degraded',
    checks,
  });
});

async function checkDatabase() {
  try {
    await db.query('SELECT 1');
    return { status: 'ok' };
  } catch (error) {
    return { status: 'error', message: error.message };
  }
}
```

---

## Alerting Best Practices

### Alert Principles

1. **Actionable** - Someone can do something about it
2. **Urgent** - Requires immediate attention
3. **Relevant** - Affects users or business

### Alert Levels

| Level | Response Time | Example |
|-------|---------------|---------|
| **Critical** | < 5 min | Service down, data loss |
| **Warning** | < 1 hour | High error rate, disk 80% |
| **Info** | Next business day | Deprecation notices |

### SLO-Based Alerts

```yaml
# Alert on error budget burn rate
- alert: HighErrorRate
  expr: |
    (
      sum(rate(http_requests_total{status=~"5.."}[5m]))
      /
      sum(rate(http_requests_total[5m]))
    ) > 0.01
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Error rate above 1%"
```

---

## Dashboard Essentials

### Service Dashboard

```text
Row 1: Request Rate | Error Rate | Latency (p50, p95, p99)
Row 2: CPU Usage | Memory Usage | Active Connections
Row 3: Database Queries | Cache Hit Rate | Queue Depth
Row 4: Recent Errors (logs) | Slow Requests
```

### Key Queries (PromQL)

```promql
# Request rate
sum(rate(http_requests_total[5m])) by (service)

# Error rate percentage
100 * sum(rate(http_requests_total{status=~"5.."}[5m]))
  / sum(rate(http_requests_total[5m]))

# p95 latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Saturation (queue depth)
sum(queue_messages_pending) by (queue)
```

---

## Checklist

### Before Production

- [ ] Structured logging configured
- [ ] Log levels appropriate per environment
- [ ] Sensitive data not logged
- [ ] Metrics exported to Prometheus/StatsD
- [ ] Health endpoints implemented
- [ ] Traces connected to collector
- [ ] Alerts configured for SLOs
- [ ] Dashboards created

---

## When to Use This Skill

- Setting up logging infrastructure
- Adding metrics to application
- Implementing distributed tracing
- Creating health check endpoints
- Designing alerting strategy
- Building monitoring dashboards
