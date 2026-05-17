# Deploy Templates — Multi-Region and Edge

Operational runbook templates for deploys that span multiple regions or
target edge runtimes (Cloudflare Workers, Vercel Edge, Deno Deploy,
AWS Lambda@Edge, Fastly Compute@Edge). Consumed via the base
`DEPLOY_CHECKLIST.md` → `Stack Specifics → Edge / Multi-Region`
reference.

These are **templates**, not a checklist. The pre-deploy decision gates
(baseline metrics, auth/crypto, CSRF, post-deploy comparison, rollback
triggers, time boundaries) live in
`templates/base/prompts/DEPLOY_CHECKLIST.md` — consult that file first.

Edge and multi-region deploys differ from single-region origin deploys
in three ways that need explicit runbook coverage:

1. **No instant rollback** — edge propagation has lag (tens of seconds
   to several minutes); cache and CDN state is regional.
2. **Partial-failure modes are normal** — one region green, another
   red is the default state during ramp, not a bug.
3. **Cold-start cost is per-region per-deploy** — every region pays
   the V8-isolate / Lambda init cost on first request after rollout.

---

## Phase 0 — Pre-Deploy Decisions

Decide before starting:

- [ ] **Rollout strategy** — global atomic vs region-by-region
  staggered. Global atomic is simpler but loses the early-warning
  signal from a single-region canary; staggered catches region-local
  bugs (data residency, auth provider quirks) but multiplies the
  watch window by N.
- [ ] **Rollback strategy** — re-deploy previous artifact (slow,
  re-propagates), traffic-shift to previous version pinned at the
  load balancer (fast, requires both versions live), or feature flag
  to route around the new code path (fastest, requires the new
  code path to be flag-gated).
- [ ] **Cache invalidation strategy** — global purge on deploy
  (expensive, cold-cache spike), surgical purge (precise but easy to
  miss a stale key), or version-keyed cache (asset URL includes
  build hash; old assets stay cached until eviction).
- [ ] **Origin-shield / multi-tier cache decision** — if origin
  cannot serve full bypass traffic, every region cold-start at once
  will DDoS the origin. Add origin shield or stage by region.

---

## Phase 1 — Region-by-Region Rollout (Vercel / Cloudflare / Lambda@Edge)

```bash
# Vercel — promote by environment, regions are automatic
vercel --prod --confirm
# Cloudflare Workers — staged rollout via wrangler (% of requests)
wrangler deploy --compatibility-date 2024-09-01 \
                --routes "example.com/*" \
                --gradual 0.10  # 10% canary
# Lambda@Edge — CloudFront staging distribution first, then promote
aws cloudfront create-invalidation --distribution-id ESTAGING --paths "/*"
# Verify on staging distribution before promoting to primary
aws cloudfront update-distribution --id EPROD \
    --distribution-config file://updated-config-pointing-at-new-version.json
```

---

## Phase 2 — Edge-Specific Gates (Phase 0a baseline equivalents)

Edge runtimes do not expose origin-server SLIs like GC pause or DB
pool utilization. Capture these instead:

| Signal | Baseline source | Alert band |
| ------ | --------------- | ---------- |
| `wall-clock-time` per request (Cloudflare) / `Duration` (Lambda@Edge) | Workers Analytics, CloudWatch | p99 > 50ms steady state for compute, > 200ms for SSR |
| `subrequest-count` (origin fetches per request) | Workers Analytics | > 5 per request = N+1 at the edge |
| Cache hit ratio at edge (HIT / MISS / DYNAMIC) | CDN logs, edge analytics | < 80% on cacheable surfaces = config drift |
| Cold-start count per region per minute | Workers / Lambda metrics | Spike on deploy is normal; sustained > 1/s post-warmup = leak |
| Per-region error rate | CDN logs aggregated by `cf-ray` region / `x-amz-cf-pop` | one-region anomaly = regional code path, not global bug |
| KV / R2 / D1 / DynamoDB Global Tables replication lag | Provider metric | > 60s sustained = cross-region reads inconsistent |

---

## Phase 3 — Cache Invalidation

```bash
# Cloudflare — purge by URL (preferred) or tag (preferred for grouped assets)
curl -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/purge_cache" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"files":["https://example.com/api/manifest.json"]}'
# OR by cache-tag for bulk:
#   --data '{"tags":["product-catalog"]}'

# Vercel — purge by tag or path
vercel cache purge --tag=product-catalog
# OR
vercel cache purge "/api/manifest.json"

# CloudFront — invalidation (incurs cost per 1000 paths after first 1000/month)
aws cloudfront create-invalidation --distribution-id EPROD \
    --paths "/api/manifest.json" "/static/build-manifest.json"
```

Avoid `--paths "/*"` unless absolutely necessary — it nukes the cache
for every region simultaneously and forces a global cold-fetch spike
against origin.

---

## Phase 4 — Multi-Region Database Consistency

- [ ] **Read-after-write window** documented per data type. If a write
  in region A is read from region B within the replication lag window,
  the read returns stale. Mitigations: read-your-writes routing
  (pin user session to write region for N seconds post-write),
  causal-consistency tokens, single-region writes with global reads.
- [ ] **Cross-region transactions** flagged. Distributed transactions
  across regions (e.g., DynamoDB Global Tables, Spanner) have
  different consistency guarantees than single-region — verify the
  code path uses the right read mode.
- [ ] **Failover region** verified. If the primary region goes down,
  the failover path is tested (DNS failover via Route 53 health
  checks, manual cutover, automatic promotion of a read replica).

---

## Phase 5 — Verification (per region)

Edge / multi-region verification iterates over regions, not just
endpoints:

```bash
# Probe each PoP / region explicitly via cf-region or aws-region
for region in iad sfo nrt fra syd; do
    response=$(curl -sw '%{http_code}\t%{time_total}\n' \
        -H "CF-Connecting-IP: $REGION_PROBE_IP_$region" \
        -o /dev/null \
        "https://example.com/api/health")
    echo "$region $response"
done

# For Cloudflare Workers: trace per-PoP via cf-ray
curl -I https://example.com/api/health | grep -i 'cf-ray\|cf-cache-status\|cf-worker'
# For Vercel: x-vercel-id contains the PoP code (e.g., iad1::abc...)
curl -I https://example.com/api/health | grep -i 'x-vercel-id\|x-vercel-cache'
# For CloudFront: x-amz-cf-pop and x-cache headers
curl -I https://example.com/api/health | grep -i 'x-amz-cf-pop\|x-cache'
```

- [ ] Health endpoint returns 200 in **every** rolled-out region.
  A single-region 5xx is a regional bug — pause the rollout,
  investigate before continuing.
- [ ] Cache-status header (`cf-cache-status`, `x-vercel-cache`,
  `x-cache`) returns HIT on the second request in each region (cold
  vs warm verification).
- [ ] Per-region error rate within the 7.4 / 7.6 bands of
  `DEPLOY_CHECKLIST.md`. Apply the bands per-region, not globally —
  global average hides a single-region disaster.

---

## Phase 6 — Rollback

- [ ] **Re-deploy previous artifact** is the safest rollback. Slow
  (re-propagation lag) but well-understood.
- [ ] **Traffic-shift rollback** — keep N-1 version live behind a
  load-balancer rule, flip the rule. Fast, but requires the
  infrastructure to support pinned versions.
- [ ] **Flag-gated rollback** — toggle a feature flag that routes
  around the new code path. Fastest, but requires the new path to
  have been flag-gated in the first place.
- [ ] **Cache state after rollback** — explicitly purge edge cache
  for surfaces that may have cached the bad version's output.
  Otherwise users keep seeing the bad response until natural TTL.
- [ ] **Per-region rollback verification** — rollback is not done
  until every region is back to the previous version AND the cache
  is purged AND the per-region error rate has returned to baseline.
