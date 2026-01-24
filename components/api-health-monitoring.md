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

    /**
     * Detect error type from message/status code
     */
    protected function detectErrorType(string $message, ?int $statusCode): string
    {
        $message = strtolower($message);

        // No credits/balance
        if (str_contains($message, 'credit') ||
            str_contains($message, 'balance') ||
            str_contains($message, 'insufficient') ||
            str_contains($message, 'quota')) {
            return 'no_credits';
        }

        // Invalid/expired key
        if ($statusCode === 401 ||
            str_contains($message, 'invalid') ||
            str_contains($message, 'unauthorized') ||
            str_contains($message, 'authentication')) {
            return 'invalid_key';
        }

        // Rate limit
        if ($statusCode === 429 || str_contains($message, 'rate limit')) {
            return 'rate_limited';
        }

        // Service unavailable
        if ($statusCode >= 500) {
            return 'service_unavailable';
        }

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

    /**
     * Example: Check OpenAI/Anthropic API
     */
    public function checkOpenAI(): array
    {
        $apiKey = config('services.openai.api_key');

        if (empty($apiKey)) {
            return ['status' => 'not_configured', 'message' => 'API key not set'];
        }

        try {
            $response = Http::timeout(10)
                ->withHeaders(['Authorization' => "Bearer {$apiKey}"])
                ->get('https://api.openai.com/v1/models');

            if ($response->successful()) {
                $this->markOk('openai', 'API working');
                return ['status' => 'ok', 'message' => 'Working', 'checked_at' => now()];
            }

            $error = $response->json()['error']['message'] ?? 'Unknown error';
            $this->recordError('openai', $error, $response->status());

            return $this->getStatus('openai');

        } catch (\Exception $e) {
            $this->recordError('openai', $e->getMessage());
            return $this->getStatus('openai');
        }
    }

    /**
     * Example: Check Stripe API
     */
    public function checkStripe(): array
    {
        $apiKey = config('services.stripe.secret');

        if (empty($apiKey)) {
            return ['status' => 'not_configured', 'message' => 'API key not set'];
        }

        try {
            $response = Http::timeout(10)
                ->withBasicAuth($apiKey, '')
                ->get('https://api.stripe.com/v1/balance');

            if ($response->successful()) {
                $balance = $response->json();
                $available = ($balance['available'][0]['amount'] ?? 0) / 100;
                $this->markOk('stripe', "Balance: \${$available}");
                return ['status' => 'ok', 'message' => "Balance: \${$available}", 'checked_at' => now()];
            }

            $error = $response->json()['error']['message'] ?? 'Unknown error';
            $this->recordError('stripe', $error, $response->status());

            return $this->getStatus('stripe');

        } catch (\Exception $e) {
            $this->recordError('stripe', $e->getMessage());
            return $this->getStatus('stripe');
        }
    }
}
```

### 2. Using Auto-Detection in Services

```php
<?php

// In any service that calls external API:

class PaymentService
{
    public function charge(int $amount): bool
    {
        try {
            $response = Http::withBasicAuth(config('services.stripe.secret'), '')
                ->post('https://api.stripe.com/v1/charges', [
                    'amount' => $amount,
                    'currency' => 'usd',
                ]);

            if (!$response->successful()) {
                $error = $response->json()['error']['message'] ?? $response->body();

                // Auto-detect and record the error
                app(ApiHealthService::class)->recordError('stripe', $error, $response->status());

                return false;
            }

            return true;

        } catch (\Exception $e) {
            app(ApiHealthService::class)->recordError('stripe', $e->getMessage());
            throw $e;
        }
    }
}
```

### 3. Controller Endpoints

```php
<?php

namespace App\Http\Controllers;

use App\Services\ApiHealthService;

class ApiHealthController extends Controller
{
    public function status()
    {
        $health = app(ApiHealthService::class);

        return response()->json([
            'success' => true,
            'services' => [
                'openai' => $health->getStatus('openai'),
                'stripe' => $health->getStatus('stripe'),
                'twilio' => $health->getStatus('twilio'),
            ],
        ]);
    }

    public function check(string $service)
    {
        $result = app(ApiHealthService::class)->check($service);

        return response()->json([
            'success' => true,
            'result' => $result,
        ]);
    }
}
```

---

## Vue Component

### ApiStatusCard.vue

```vue
<script setup>
import { ref } from 'vue'

const props = defineProps({
    service: { type: String, required: true },
    label: { type: String, required: true },
    status: { type: Object, default: null },
    checkEndpoint: { type: String, required: true },
})

const checking = ref(false)
const currentStatus = ref(props.status)

const statusConfig = {
    ok: { color: 'green', icon: 'check-circle', text: 'Working' },
    no_credits: { color: 'red', icon: 'exclamation-circle', text: 'No credits!' },
    invalid_key: { color: 'red', icon: 'exclamation-circle', text: 'Invalid key' },
    rate_limited: { color: 'yellow', icon: 'exclamation-triangle', text: 'Rate limited' },
    service_unavailable: { color: 'yellow', icon: 'exclamation-triangle', text: 'Unavailable' },
    not_configured: { color: 'gray', icon: 'minus-circle', text: 'Not configured' },
    error: { color: 'orange', icon: 'exclamation-triangle', text: 'Error' },
}

const check = async () => {
    checking.value = true
    try {
        const response = await fetch(props.checkEndpoint, {
            method: 'POST',
            headers: {
                'Accept': 'application/json',
                'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content,
            },
        })
        const data = await response.json()
        if (data.success) {
            currentStatus.value = data.result
        }
    } catch (e) {
        console.error('Health check failed', e)
    } finally {
        checking.value = false
    }
}

const getConfig = (status) => statusConfig[status] || statusConfig.error
</script>

<template>
    <div class="bg-white rounded-lg shadow p-6">
        <div class="flex justify-between items-center">
            <div>
                <div class="text-sm text-gray-500 mb-1">{{ label }}</div>

                <!-- Not checked yet -->
                <div v-if="!currentStatus" class="text-gray-400">
                    Not checked
                </div>

                <!-- Has status -->
                <div v-else :class="`text-${getConfig(currentStatus.status).color}-600 flex items-center`">
                    <span class="font-medium">
                        {{ currentStatus.message || getConfig(currentStatus.status).text }}
                    </span>
                </div>

                <!-- Last checked time -->
                <div v-if="currentStatus?.checked_at" class="text-xs text-gray-400 mt-1">
                    Checked: {{ new Date(currentStatus.checked_at).toLocaleTimeString() }}
                </div>
            </div>

            <!-- Check button -->
            <button
                @click="check"
                :disabled="checking"
                class="bg-gray-100 text-gray-700 px-4 py-2 rounded hover:bg-gray-200 disabled:opacity-50"
            >
                <span v-if="checking">Checking...</span>
                <span v-else>Check</span>
            </button>
        </div>
    </div>
</template>
```

### Usage in Dashboard

```vue
<template>
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <ApiStatusCard
            service="openai"
            label="OpenAI API"
            :status="stats.openaiStatus"
            check-endpoint="/api/health/openai"
        />
        <ApiStatusCard
            service="stripe"
            label="Stripe"
            :status="stats.stripeStatus"
            check-endpoint="/api/health/stripe"
        />
        <ApiStatusCard
            service="twilio"
            label="Twilio SMS"
            :status="stats.twilioStatus"
            check-endpoint="/api/health/twilio"
        />
    </div>
</template>
```

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

Send Slack alerts on critical API errors:

```php
/**
 * Send Slack alert for API issues
 */
protected function sendSlackAlert(string $api, array $status): void
{
    $webhookUrl = config('services.slack.webhook_url');
    if (empty($webhookUrl)) {
        return;
    }

    // Rate limit: only one alert per API per hour
    $cacheKey = "slack_alert:{$api}:{$status['status']}";
    if (Cache::has($cacheKey)) {
        return;
    }

    $apiNames = [
        'claude' => 'Claude API',
        'stripe' => 'Stripe',
        '2captcha' => '2Captcha',
    ];

    $emoji = match ($status['status']) {
        'no_credits', 'no_balance' => ':money_with_wings:',
        'invalid_key' => ':key:',
        default => ':warning:',
    };

    $apiName = $apiNames[$api] ?? $api;
    $message = $status['message'] ?? 'Unknown error';

    Http::post($webhookUrl, [
        'text' => "{$emoji} *{$apiName}*: {$message}",
    ]);

    // Set cooldown (1 hour)
    Cache::put($cacheKey, true, 3600);
}
```

**Call from saveStatus:**

```php
protected function saveStatus(string $api, array $status): array
{
    // ... save to cache ...

    // Send Slack alert for critical statuses
    $criticalStatuses = ['no_credits', 'no_balance', 'invalid_key'];
    if (in_array($status['status'] ?? '', $criticalStatuses)) {
        $this->sendSlackAlert($api, $status);
    }

    return $status;
}
```

**.env:**

```bash
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/XXX/YYY/ZZZ
```

---

## Extension

### Adding a New Service

1. Add check method to `ApiHealthService`:

   ```php
   public function checkNewService(): array
   {
       $apiKey = config('services.newservice.api_key');

       if (empty($apiKey)) {
           return ['status' => 'not_configured', 'message' => 'API key not set'];
       }

       try {
           // Make minimal request to check
           $response = Http::timeout(10)
               ->withHeaders(['Authorization' => "Bearer {$apiKey}"])
               ->get('https://api.newservice.com/v1/account');

           if ($response->successful()) {
               $this->markOk('newservice', 'Working');
               return ['status' => 'ok', 'message' => 'Working', 'checked_at' => now()];
           }

           $error = $response->json()['error'] ?? 'Unknown error';
           $this->recordError('newservice', $error, $response->status());
           return $this->getStatus('newservice');

       } catch (\Exception $e) {
           $this->recordError('newservice', $e->getMessage());
           return $this->getStatus('newservice');
       }
   }
   ```

2. Add `recordError()` to the service that uses this API

3. Add card to dashboard

---

## See Also

- [Quick Check Scripts](./quick-check-scripts.md) — automated checks
- [Severity Levels](./severity-levels.md) — severity levels
