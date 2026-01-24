# Deployment Strategies Guide

> Safe deployment patterns for production systems.

---

## Strategy Overview

| Strategy | Risk | Downtime | Rollback | Best For |
|----------|------|----------|----------|----------|
| Rolling | Low | Zero | Medium | Most apps |
| Blue-Green | Very Low | Zero | Fast | Critical systems |
| Canary | Very Low | Zero | Fast | High-traffic apps |
| Recreate | High | Yes | Slow | Dev/staging |

---

## Rolling Deployment

### Concept

```text
Time →
[v1][v1][v1][v1]  Initial state
[v2][v1][v1][v1]  Replace 1st instance
[v2][v2][v1][v1]  Replace 2nd instance
[v2][v2][v2][v1]  Replace 3rd instance
[v2][v2][v2][v2]  Complete
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Max extra pods during update
      maxUnavailable: 0  # Always maintain capacity
  template:
    spec:
      containers:
        - name: app
          image: my-app:v2
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
```

### Docker Compose

```yaml
services:
  app:
    image: my-app:v2
    deploy:
      replicas: 4
      update_config:
        parallelism: 1
        delay: 10s
        failure_action: rollback
      rollback_config:
        parallelism: 1
        delay: 10s
```

---

## Blue-Green Deployment

### Concept

```text
                    Load Balancer
                         │
         ┌───────────────┴───────────────┐
         ▼                               ▼
    ┌─────────┐                    ┌─────────┐
    │  Blue   │ ← Active           │  Green  │ ← Idle/New
    │  (v1)   │                    │  (v2)   │
    └─────────┘                    └─────────┘

After switch:
                    Load Balancer
                         │
         ┌───────────────┴───────────────┐
         ▼                               ▼
    ┌─────────┐                    ┌─────────┐
    │  Blue   │ ← Idle/Rollback    │  Green  │ ← Active
    │  (v1)   │                    │  (v2)   │
    └─────────┘                    └─────────┘
```

### Implementation with nginx

```nginx
# /etc/nginx/conf.d/app.conf

upstream blue {
    server blue-app:8080;
}

upstream green {
    server green-app:8080;
}

# Switch by changing this line
upstream active {
    server green-app:8080;  # Currently green
}

server {
    listen 80;

    location / {
        proxy_pass http://active;
    }
}
```

### Switch Script

```bash
#!/bin/bash
# switch-deployment.sh

CURRENT=$(grep -oP 'server \K(blue|green)' /etc/nginx/conf.d/app.conf | head -1)

if [ "$CURRENT" = "blue" ]; then
    NEW="green"
else
    NEW="blue"
fi

sed -i "s/server ${CURRENT}-app/server ${NEW}-app/" /etc/nginx/conf.d/app.conf
nginx -s reload

echo "Switched from $CURRENT to $NEW"
```

### AWS ALB

```yaml
# CloudFormation
Resources:
  BlueTargetGroup:
    Type: AWS::ElasticLoadBalancingV2::TargetGroup
    Properties:
      Name: blue-tg

  GreenTargetGroup:
    Type: AWS::ElasticLoadBalancingV2::TargetGroup
    Properties:
      Name: green-tg

  Listener:
    Type: AWS::ElasticLoadBalancingV2::Listener
    Properties:
      DefaultActions:
        - Type: forward
          TargetGroupArn: !Ref GreenTargetGroup  # Switch here
```

---

## Canary Deployment

### Concept

```text
                    Load Balancer
                         │
              ┌──────────┴──────────┐
              │ 95%            5%   │
              ▼                     ▼
         ┌─────────┐          ┌─────────┐
         │ Stable  │          │ Canary  │
         │  (v1)   │          │  (v2)   │
         └─────────┘          └─────────┘

Gradual increase: 5% → 25% → 50% → 100%
```

### Kubernetes with Istio

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-app
spec:
  hosts:
    - my-app
  http:
    - route:
        - destination:
            host: my-app
            subset: stable
          weight: 95
        - destination:
            host: my-app
            subset: canary
          weight: 5
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: my-app
spec:
  host: my-app
  subsets:
    - name: stable
      labels:
        version: v1
    - name: canary
      labels:
        version: v2
```

### nginx Canary

```nginx
upstream stable {
    server stable-app:8080 weight=95;
}

upstream canary {
    server canary-app:8080 weight=5;
}

split_clients "${remote_addr}" $upstream {
    95% stable;
    5%  canary;
}

server {
    location / {
        proxy_pass http://$upstream;
    }
}
```

---

## Feature Flags Integration

### With Canary

```typescript
// Check if user is in canary group
function isCanary(userId: string): boolean {
  const hash = hashUserId(userId);
  return hash % 100 < CANARY_PERCENTAGE;
}

// Feature flag check
async function getFeature(flag: string, userId: string): Promise<boolean> {
  if (isCanary(userId)) {
    return await featureFlags.get(`${flag}_canary`);
  }
  return await featureFlags.get(flag);
}
```

### Gradual Rollout

```typescript
const rolloutConfig = {
  'new-checkout': {
    percentage: 25,  // 25% of users
    allowList: ['user_123', 'user_456'],  // Always enabled
    denyList: ['user_789'],  // Always disabled
  },
};

function isFeatureEnabled(flag: string, userId: string): boolean {
  const config = rolloutConfig[flag];
  if (!config) return false;

  if (config.denyList.includes(userId)) return false;
  if (config.allowList.includes(userId)) return true;

  const hash = hashUserId(userId);
  return hash % 100 < config.percentage;
}
```

---

## Rollback Procedures

### Kubernetes Rollback

```bash
# View history
kubectl rollout history deployment/my-app

# Rollback to previous
kubectl rollout undo deployment/my-app

# Rollback to specific revision
kubectl rollout undo deployment/my-app --to-revision=2

# Check status
kubectl rollout status deployment/my-app
```

### Docker Compose Rollback

```bash
# Keep previous image tagged
docker tag my-app:latest my-app:previous

# Deploy new version
docker compose up -d

# Rollback
docker tag my-app:previous my-app:latest
docker compose up -d
```

### Database Rollback

```bash
# Before deployment: create backup
pg_dump -Fc mydb > backup_$(date +%Y%m%d_%H%M%S).dump

# Rollback migration
# Laravel
php artisan migrate:rollback

# Django
python manage.py migrate app_name 0005_previous_migration

# Prisma
npx prisma migrate resolve --rolled-back "migration_name"
```

---

## Zero-Downtime Database Migrations

### Safe Migration Pattern

```text
1. Add new column (nullable)     ← Deploy migration
2. Deploy code (write to both)   ← Deploy v2
3. Backfill data                 ← Run script
4. Deploy code (read from new)   ← Deploy v3
5. Drop old column               ← Deploy migration
```

### Example: Rename Column

```sql
-- Step 1: Add new column
ALTER TABLE users ADD COLUMN full_name VARCHAR(255);

-- Step 2: Backfill (in batches)
UPDATE users SET full_name = name WHERE full_name IS NULL LIMIT 1000;

-- Step 3: After backfill complete, add NOT NULL
ALTER TABLE users ALTER COLUMN full_name SET NOT NULL;

-- Step 4: After code fully migrated, drop old column
ALTER TABLE users DROP COLUMN name;
```

### Prisma Expand-Contract

```prisma
// Step 1: Add new field
model User {
  id       Int     @id
  name     String  // Old
  fullName String? // New (nullable)
}

// Step 2: After migration + backfill
model User {
  id       Int    @id
  name     String // Keep for rollback
  fullName String // Now required
}

// Step 3: After full deployment
model User {
  id       Int    @id
  fullName String
}
```

---

## Health Checks

### Liveness vs Readiness

| Check | Purpose | Failure Action |
|-------|---------|----------------|
| Liveness | Is app alive? | Restart container |
| Readiness | Can handle traffic? | Remove from LB |

### Implementation

```typescript
// Health endpoint
app.get('/health/live', (req, res) => {
  // Basic liveness - app is running
  res.status(200).json({ status: 'ok' });
});

app.get('/health/ready', async (req, res) => {
  // Readiness - can handle requests
  const checks = {
    database: await checkDatabase(),
    cache: await checkRedis(),
  };

  const healthy = Object.values(checks).every(c => c.ok);
  res.status(healthy ? 200 : 503).json({ status: healthy ? 'ok' : 'degraded', checks });
});
```

### Kubernetes Config

```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: 8080
  initialDelaySeconds: 15
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /health/ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 3
```

---

## Deployment Checklist

### Pre-Deployment

- [ ] All tests passing
- [ ] Database migrations tested
- [ ] Feature flags configured
- [ ] Rollback plan documented
- [ ] Monitoring alerts set
- [ ] Team notified

### During Deployment

- [ ] Monitor error rates
- [ ] Watch response times
- [ ] Check resource usage
- [ ] Verify health checks

### Post-Deployment

- [ ] Smoke tests passing
- [ ] Metrics normal
- [ ] No error spikes
- [ ] User feedback monitored
