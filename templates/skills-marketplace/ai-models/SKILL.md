# AI Models — Current Versions

> Load this skill when working with AI API (Anthropic, Google)

---

## Rule

**USE ONLY CURRENT VERSIONS!**

When working with API or adding models to code — ALWAYS use current versions:

- Claude 4.5+
- Gemini 3+

**DO NOT use outdated versions:** Claude 3.5, 4.0, Gemini 1.x, 2.x

---

## Claude (Anthropic)

| Model | Model ID | Usage |
| ------ | -------- | ------------- |
| **Opus 4.5** | `claude-opus-4-5-20251101` | Complex tasks, architecture, critical code |
| **Sonnet 4.5** | `claude-sonnet-4-5-20250929` | Everyday development, speed/quality balance |
| **Haiku 4.5** | `claude-haiku-4-5-20251001` | Fast tasks, autocomplete, simple operations |

### Python

```python
from anthropic import Anthropic

client = Anthropic()
message = client.messages.create(
    model="claude-sonnet-4-5-20250929",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Hello"}]
)
```

### TypeScript

```typescript
import Anthropic from '@anthropic-ai/sdk'

const client = new Anthropic()
const message = await client.messages.create({
  model: 'claude-sonnet-4-5-20250929',
  max_tokens: 1024,
  messages: [{ role: 'user', content: 'Hello' }]
})
```

### PHP

```php
use Anthropic\Anthropic;

$client = Anthropic::client(getenv('ANTHROPIC_API_KEY'));
$response = $client->messages()->create([
    'model' => 'claude-sonnet-4-5-20250929',
    'max_tokens' => 1024,
    'messages' => [['role' => 'user', 'content' => 'Hello']]
]);
```

---

## Gemini (Google)

| Model | Model ID | Usage |
| ------ | -------- | ------------- |
| **Gemini 3 Pro** | `gemini-3-pro-preview` | Complex tasks, analysis, critical code |
| **Gemini 3 Flash** | `gemini-3-flash-preview` | Fast tasks, speed/quality balance |

### Python

```python
import google.generativeai as genai

genai.configure(api_key=os.environ["GEMINI_API_KEY"])
model = genai.GenerativeModel("gemini-3-flash-preview")
response = model.generate_content("Hello")
```

### TypeScript

```typescript
import { GoogleGenerativeAI } from '@google/generative-ai'

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY)
const model = genAI.getGenerativeModel({ model: 'gemini-3-flash-preview' })
const result = await model.generateContent('Hello')
```

---

## Outdated Versions (DO NOT USE!)

```python
# WRONG
client.messages.create(model="claude-3-5-sonnet-20241022", ...)
client.messages.create(model="claude-3-opus-20240229", ...)
genai.GenerativeModel("gemini-1.5-flash")
genai.GenerativeModel("gemini-2.0-flash")
```

---

## When to update this skill

- When new model versions are released
- When old versions are deprecated
- When Model ID changes
