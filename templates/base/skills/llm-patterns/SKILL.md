---
name: LLM Patterns
description: LLM integration patterns — RAG, embeddings, streaming, tool use. Triggers on rag/embeddings/vector/llm/prompt keywords.
---

# LLM Patterns Skill

> Load this skill when working with LLMs, RAG systems, embeddings, or AI integrations.

---

## Rule

**LLM INTEGRATIONS MUST BE ROBUST AND COST-EFFECTIVE!**

- Always handle streaming and errors
- Optimize tokens for cost
- Use appropriate models for tasks

---

## Model Selection Guide

| Task | Model | Why |
|------|-------|-----|
| Complex reasoning | Claude Opus 4.5 / GPT-4 | Best quality |
| General tasks | Claude Sonnet 4.5 / GPT-4o | Balance |
| Simple tasks | Claude Haiku 4.5 / GPT-4o-mini | Fast & cheap |
| Embeddings | text-embedding-3-small | Cost-effective |
| Classification | Fine-tuned small model | Fastest |

---

## RAG Architecture

### Basic RAG Flow

```text
Query → Embed Query → Vector Search → Retrieve Chunks → Augment Prompt → LLM → Response
```

### Implementation

```typescript
async function ragQuery(query: string): Promise<string> {
  // 1. Embed the query
  const queryEmbedding = await embedText(query);

  // 2. Vector search for relevant chunks
  const chunks = await vectorStore.similaritySearch(queryEmbedding, {
    topK: 5,
    minScore: 0.7,
  });

  // 3. Build context from chunks
  const context = chunks.map((c) => c.content).join('\n\n---\n\n');

  // 4. Augment prompt
  const prompt = `Answer based on the following context:

Context:
${context}

Question: ${query}

Answer:`;

  // 5. Get LLM response
  return await llm.complete(prompt);
}
```

---

## Chunking Strategies

### Size Guidelines

| Document Type | Chunk Size | Overlap |
|---------------|------------|---------|
| Dense text (legal, technical) | 256-512 tokens | 50 tokens |
| General content | 512-1024 tokens | 100 tokens |
| Conversational | 1024-2048 tokens | 200 tokens |

### Chunking Methods

```typescript
// 1. Fixed size chunking
function fixedChunks(text: string, size: number, overlap: number): string[] {
  const chunks = [];
  for (let i = 0; i < text.length; i += size - overlap) {
    chunks.push(text.slice(i, i + size));
  }
  return chunks;
}

// 2. Semantic chunking (by paragraph/section)
function semanticChunks(text: string): string[] {
  return text
    .split(/\n\n+/)
    .filter((chunk) => chunk.trim().length > 50);
}

// 3. Recursive character splitting (LangChain style)
const splitter = new RecursiveCharacterTextSplitter({
  chunkSize: 1000,
  chunkOverlap: 200,
  separators: ['\n\n', '\n', '. ', ' ', ''],
});
```

---

## Streaming Responses

### Server-Sent Events (SSE)

```typescript
// Server (Express)
app.get('/api/chat', async (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  const stream = await anthropic.messages.stream({
    model: 'claude-sonnet-4-5-20250929',
    max_tokens: 1024,
    messages: [{ role: 'user', content: req.query.message }],
  });

  for await (const event of stream) {
    if (event.type === 'content_block_delta') {
      res.write(`data: ${JSON.stringify({ text: event.delta.text })}\n\n`);
    }
  }

  res.write('data: [DONE]\n\n');
  res.end();
});

// Client
const eventSource = new EventSource('/api/chat?message=Hello');

eventSource.onmessage = (event) => {
  if (event.data === '[DONE]') {
    eventSource.close();
    return;
  }
  const { text } = JSON.parse(event.data);
  appendToOutput(text);
};
```

### WebSocket Streaming

```typescript
// Server
ws.on('message', async (data) => {
  const { message } = JSON.parse(data);

  const stream = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages: [{ role: 'user', content: message }],
    stream: true,
  });

  for await (const chunk of stream) {
    const text = chunk.choices[0]?.delta?.content || '';
    ws.send(JSON.stringify({ type: 'chunk', text }));
  }

  ws.send(JSON.stringify({ type: 'done' }));
});
```

---

## Token Optimization

### Counting Tokens

```typescript
import { encoding_for_model } from 'tiktoken';

function countTokens(text: string, model = 'gpt-4'): number {
  const enc = encoding_for_model(model);
  return enc.encode(text).length;
}
```

### Cost Optimization Tips

1. **Use smaller models** for simple tasks
2. **Cache responses** for repeated queries
3. **Truncate context** to essential information
4. **Batch requests** when possible
5. **Use embeddings** for similarity instead of LLM

### Context Window Management

```typescript
function trimContext(messages: Message[], maxTokens: number): Message[] {
  let totalTokens = 0;
  const trimmed = [];

  // Always keep system message
  const systemMsg = messages.find((m) => m.role === 'system');
  if (systemMsg) {
    totalTokens += countTokens(systemMsg.content);
    trimmed.push(systemMsg);
  }

  // Add messages from most recent
  for (const msg of messages.reverse()) {
    if (msg.role === 'system') continue;

    const tokens = countTokens(msg.content);
    if (totalTokens + tokens > maxTokens) break;

    totalTokens += tokens;
    trimmed.unshift(msg);
  }

  return trimmed;
}
```

---

## Tool Use / Function Calling

### Defining Tools

```typescript
const tools = [
  {
    name: 'get_weather',
    description: 'Get current weather for a location',
    input_schema: {
      type: 'object',
      properties: {
        location: {
          type: 'string',
          description: 'City name, e.g., "San Francisco, CA"',
        },
      },
      required: ['location'],
    },
  },
];

const response = await anthropic.messages.create({
  model: 'claude-sonnet-4-5-20250929',
  max_tokens: 1024,
  tools,
  messages: [{ role: 'user', content: 'What is the weather in Tokyo?' }],
});

// Handle tool use
if (response.stop_reason === 'tool_use') {
  const toolUse = response.content.find((c) => c.type === 'tool_use');
  const result = await executeTools(toolUse.name, toolUse.input);

  // Continue conversation with tool result
  const finalResponse = await anthropic.messages.create({
    model: 'claude-sonnet-4-5-20250929',
    max_tokens: 1024,
    tools,
    messages: [
      { role: 'user', content: 'What is the weather in Tokyo?' },
      { role: 'assistant', content: response.content },
      { role: 'user', content: [{ type: 'tool_result', tool_use_id: toolUse.id, content: result }] },
    ],
  });
}
```

---

## Error Handling

### Retry Strategy

```typescript
async function llmWithRetry<T>(
  fn: () => Promise<T>,
  maxRetries = 3
): Promise<T> {
  let lastError: Error;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;

      if (error.status === 429) {
        // Rate limit - exponential backoff
        const delay = Math.min(1000 * Math.pow(2, attempt), 30000);
        await sleep(delay);
        continue;
      }

      if (error.status >= 500) {
        // Server error - retry
        await sleep(1000 * attempt);
        continue;
      }

      // Client error - don't retry
      throw error;
    }
  }

  throw lastError;
}
```

### Common Error Codes

| Code | Meaning | Action |
|------|---------|--------|
| 400 | Bad request | Fix prompt/parameters |
| 401 | Invalid API key | Check credentials |
| 429 | Rate limited | Backoff and retry |
| 500 | Server error | Retry with backoff |
| 529 | Overloaded | Retry with longer backoff |

---

## Prompt Engineering Tips

### System Prompts

```typescript
const systemPrompt = `You are a helpful assistant that answers questions based on the provided context.

Rules:
1. Only use information from the context
2. If the answer is not in the context, say "I don't have information about that"
3. Be concise but complete
4. Cite relevant parts of the context`;
```

### Structured Output

```typescript
const response = await anthropic.messages.create({
  model: 'claude-sonnet-4-5-20250929',
  max_tokens: 1024,
  messages: [
    {
      role: 'user',
      content: `Extract entities from this text and return as JSON:

Text: "John Smith, CEO of Acme Corp, announced the merger on January 15, 2024."

Return format:
{
  "people": [{"name": string, "role": string}],
  "organizations": [string],
  "dates": [string]
}`,
    },
  ],
});
```

---

## Cost Estimation

### Token Pricing (approximate)

| Model | Input (1M tokens) | Output (1M tokens) |
|-------|-------------------|---------------------|
| GPT-4o | $2.50 | $10.00 |
| GPT-4o-mini | $0.15 | $0.60 |
| Claude Sonnet 4.5 | $3.00 | $15.00 |
| Claude Haiku 4.5 | $0.25 | $1.25 |

### Estimation Formula

```typescript
function estimateCost(inputTokens: number, outputTokens: number, model: string): number {
  const pricing = {
    'gpt-4o': { input: 0.0000025, output: 0.00001 },
    'claude-sonnet-4-5': { input: 0.000003, output: 0.000015 },
  };

  const p = pricing[model];
  return inputTokens * p.input + outputTokens * p.output;
}
```

---

## When to Use This Skill

- Implementing RAG systems
- Setting up vector search
- Adding streaming to chat
- Optimizing LLM costs
- Building tool-using agents
- Handling LLM errors gracefully
