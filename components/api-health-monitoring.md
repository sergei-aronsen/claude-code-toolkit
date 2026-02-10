# API Health Monitoring

Pattern for monitoring external paid API status (Stripe, OpenAI, 2Captcha, SMS providers, etc.).

---

## When to Use

- Project uses **paid external APIs** (balance can run out)
- Need to **automatically detect** when API stops working
- Want to see **status of all APIs on dashboard**
- Need to prevent "silent" service failures

---

## Key Components

| Component | Purpose |
| --------- | ------- |
| `ApiHealthService` | Centralized monitoring service |
| `recordError()` | Auto-detect errors in catch blocks |
| `checkHealth()` | Manual API status check |
| Status Card | UI component for status display |

---

## Laravel Implementation

### 1. ApiHealthService

```php
<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class ApiHealthService
{
    /**
     * Cache TTL for status (5 minutes)
     */
    protected int $statusTtl = 300;

    /**
     * Get current status of a service
     */
    public function getStatus(string $service): ?array
    {
        return Cache::get("api_health:{$service}");
    }

    /**
     * Record an error from a service (auto-detection)
     * Call this in catch blocks when API fails
     */
    public function recordError(string $service, string $message, ?int $statusCode = null): void
    {
        $status = $this->detectErrorType($message, $statusCode);

        Cache::put("api_health:{$service}", [
            'status' => $status,
            'message' => $this->getErrorMessage($status, $message),
            'checked_at' => now()->toIso8601String(),
            'auto_detected' => true,
        ], $this->statusTtl);

        Log::warning("API Health: {$service} error detected", [
            'service' => $service,
            'status' => $status,
            'message' => $message,
            'code' => $statusCode,
        ]);
    }

    protected function detectErrorType(string $message, ?int $statusCode): string
    {
        $message = strtolower($message);

        if (str_contains($message, 'credit') || str_contains($message, 'balance') ||
            str_contains($message, 'insufficient') || str_contains($message, 'quota'))
            return 'no_credits';
        if ($statusCode === 401 || str_contains($message, 'invalid') ||
            str_contains($message, 'unauthorized') || str_contains($message, 'authentication'))
            return 'invalid_key';
        if ($statusCode === 429 || str_contains($message, 'rate limit'))
            return 'rate_limited';
        if ($statusCode >= 500)
            return 'service_unavailable';

        return 'error';
    }

    /**
     * Get human-readable error message
     */
    protected function getErrorMessage(string $status, string $originalMessage): string
    {
        return match ($status) {
            'no_credits' => 'No credits/balance',
            'invalid_key' => 'Invalid API key',
            'rate_limited' => 'Rate limited',
            'service_unavailable' => 'Service unavailable',
            default => substr($originalMessage, 0, 100),
        };
    }

    /**
     * Mark service as OK
     */
    public function markOk(string $service, ?string $message = null): void
    {
        Cache::put("api_health:{$service}", [
            'status' => 'ok',
            'message' => $message ?? 'Working',
            'checked_at' => now()->toIso8601String(),
        ], $this->statusTtl);
    }

    /**
     * Manual health check for a service
     * Override in subclass or use specific check methods
     */
    public function check(string $service): array
    {
        return match ($service) {
            'openai' => $this->checkOpenAI(),
            'stripe' => $this->checkStripe(),
            'twilio' => $this->checkTwilio(),
            default => ['status' => 'unknown', 'message' => 'No check implemented'],
        };
    }

    // Example check method (follow this pattern for each service):
    // 1. Check if key configured → return 'not_configured' if empty
    // 2. Make test API call (e.g. GET /v1/models for OpenAI, GET /v1/balance for Stripe)
    // 3. On success: $this->markOk($service, 'Working')
    // 4. On failure: $this->recordError($service, $error, $response->status())
}
```

### 2. Using Auto-Detection in Services

In any service that calls external APIs, add to catch blocks and error responses:

```php
// On failed response:
app(ApiHealthService::class)->recordError('stripe', $error, $response->status());

// In catch block:
app(ApiHealthService::class)->recordError('stripe', $e->getMessage());
```

### 3. Controller Endpoints

Two routes: `GET /api/health` returns all service statuses, `POST /api/health/{service}/check` triggers a manual check. Both return JSON with `success` and service status data from `ApiHealthService`.

---

## Vue Component (ApiStatusCard)

`StatusCard` component: shows service label, colored status indicator (green/red/yellow/gray), last checked time, and a "Check" button. Uses a `statusConfig` map for status-to-color/icon/text mapping (`ok` = green, `no_credits`/`invalid_key` = red, `rate_limited`/`service_unavailable` = yellow, `not_configured` = gray). POSTs to check endpoint on button click and updates status from response.

Props: `service`, `label`, `status` (object), `checkEndpoint` (URL).

---

## Statuses

| Status | Meaning | Action |
| ------ | ------- | ------ |
| `ok` | API is working | - |
| `no_credits` | Balance depleted | Top up balance |
| `invalid_key` | Invalid API key | Check/update key in .env |
| `rate_limited` | Rate limit exceeded | Wait or increase limit |
| `service_unavailable` | Service unavailable | Wait |
| `not_configured` | API not configured | Add key to .env |
| `error` | Other error | Check logs |

---

## Best Practices

1. **Auto-detect everywhere** — add `recordError()` to every catch block when working with external API

2. **Don't block main functionality** — if API is unavailable, log the error but don't crash the app

3. **TTL for status** — use reasonable TTL (5-15 minutes) so status auto-resets

4. **Slack alerts** — for critical statuses (`no_credits`, `invalid_key`) send to Slack

5. **Manual check** — always provide ability to check API manually via dashboard button

---

## Slack Alerts

Add Slack webhook alerts for critical statuses (`no_credits`, `invalid_key`). Rate-limit: one alert per API per status per hour using `Cache::has("slack_alert:{$api}:{$status}")`. Call `sendSlackAlert()` from `recordError()` for critical statuses. Configure via `SLACK_WEBHOOK_URL` in `.env`.

---

## Adding a New Service

1. Add check method to `ApiHealthService` (follow `checkOpenAI`/`checkStripe` pattern)
2. Add `recordError()` calls in the service's catch blocks
3. Add card to dashboard

---

## See Also

- [Quick Check Scripts](./quick-check-scripts.md) — automated checks
- [Severity Levels](./severity-levels.md) — severity levels
