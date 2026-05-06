# Fast Apply Replacements — Research Report

**Date:** 2026-05-06
**Question:** What can replace Morph Fast Apply in `claude-code-toolkit` after we remove the Morph entry?
**Scope:** Fast-apply / "speculative edit" tooling reachable from Claude Code (MCP, CLI, or hook). English; cites every URL.

---

## 1. What Morph Fast Apply actually does (baseline to match)

- **Tool contract** (`edit_file` from `morph-fast-tools` MCP, per [Morph docs](https://docs.morphllm.com/sdk/components/fast-apply)):
  - `target_filepath` — path to modify.
  - `instructions` — first-person description of the change.
  - `code_edit` — only the changed lines with `// ... existing code ...` markers.
- **Server-side prompt** (per Morph docs): `<code>` (full original) + `<update>` (sketch/snippet) + `<instruction>` → `<updated-code>` (full rewritten file).
- **Claimed numbers:** ~10,500 tok/s, "98% accuracy", "40% fewer tokens than full rewrite", 5–10× latency reduction vs frontier full-file rewrite.
- **Models:** `morph-v3-fast`, `morph-v3-large` — proprietary, hosted-only.
- **Privacy:** code (file content + edit) leaves the box on every call; **no privacy/data-retention statement on the docs page** (verified: docs page has no SOC2/HIPAA/zero-retention claim).
- **Source-code situation (relevant to the user's removal decision):**
  - `@morphllm/morphsdk` on npm — **MIT-licensed**, last published 2026-04-29 (≈1 week ago at time of writing), 7.1 MB unpacked. ([npm](https://www.npmjs.com/package/@morphllm/morphsdk))
  - But: the **GitHub source repo is not public** under [github.com/morphllm](https://github.com/morphllm) — only the OpenCode plugin and Claude Code plugin shells are open. The actual SDK + MCP are shipped as compiled npm artifacts, no `repository` URL points to source.
  - `@morph-llm/morph-fast-apply` is **deprecated**, moved to `@morphllm/morphmcp` ([npm](https://www.npmjs.com/package/@morph-llm/morph-fast-apply)).
  - Net: license is permissive but auditability is low — user's "supply-chain risk" framing is reasonable.

---

## 2. Alternatives evaluated

### 2.1 Anthropic native (Claude Code Edit tool)

- **Source/URL:** [docs.claude.com Edit tool](https://platform.claude.com/docs/en/agents-and-tools/tool-use/text-editor-tool); behaviour write-up [Replace Is All You Need (Medium)](https://medium.com/@rquintino/replace-is-all-you-need-the-surprisingly-simple-technique-behind-claudes-new-lightning-fast-b5ae18c3c113); built-in tools reference [vtrivedy](https://www.vtrivedy.com/posts/claudecode-tools-reference).
- **What it is:** the `Edit` tool used by Claude Code today. Pure **exact string replace** (`old_string` / `new_string`). No apply model, no speculative decoding.
- **License/host:** part of Claude Code itself (Anthropic, proprietary client; model API hosted).
- **Pricing:** model tokens at standard Sonnet/Opus rate.
- **MCP integration:** N/A (built-in, not MCP).
- **Maturity:** ships with every Claude Code install since v1; the path of least resistance.
- **Gap vs Morph:** Claude must emit `old_string` AND `new_string` — i.e. it pays output tokens for the *new* version. For a 50-line diff in a 1500-line file, Anthropic Edit emits ~50 lines of new text (cheap). Morph emits ~50 lines of sketch and the apply model regenerates 1500 lines (also cheap *for the agent*). **Net: for small diffs, native Edit is roughly as cheap as Morph and removes a hop.** Gap shows up only when the agent wants to do "rewrite this whole function differently" — Morph turns that into a sketch + apply, native Edit forces the agent to write the new function in full.
- **Verdict:** No fast-apply / speculative decoding from Anthropic as of May 2026 (verified via [Releasebot Anthropic May 2026](https://releasebot.io/updates/anthropic/claude) — no such feature in changelog). For most edits in Claude Code, native Edit already wins on simplicity.

### 2.2 OpenAI Predicted Outputs

- **Source/URL:** [OpenAI Predicted Outputs guide](https://developers.openai.com/api/docs/guides/predicted-outputs); [Azure mirror](https://learn.microsoft.com/en-us/azure/foundry/openai/how-to/predicted-outputs).
- **What it is:** `prediction` parameter on Chat Completions; agent passes "expected output" along with the prompt; speculative decoding accepts matching prefix tokens for free, charges only for divergence.
- **Models:** gpt-4o, gpt-4o-mini, plus newer (per OpenAI changelog). NOT supported by Claude API.
- **Latency claim:** 3–5× speedup on edits where 80–99% of output is predictable (per Morph's own [comparison page](https://www.morphllm.com/openai/predicted-outputs), citing OpenAI). Unverified by Anthropic.
- **Pricing gotcha:** rejected predicted tokens are **still billed** as completion tokens (per OpenAI docs). Cost can go *up* if predictions miss often.
- **MCP integration:** none official. A community MCP could wrap "edit this file by sending the original as `prediction` to gpt-4o" — but that means routing edits through OpenAI, not Anthropic. Out of scope for a Claude-Code-first toolkit unless cost/routing is the goal.
- **Verdict:** **not applicable to Claude Code** unless we add an OpenAI provider hop. Mention only as the OpenAI-side equivalent.

### 2.3 Relace (Instant Apply / Apply 3)

- **Source/URL:** [docs.relace.ai](https://docs.relace.ai/); pricing via [pricepertoken.com](https://pricepertoken.com/pricing-page/model/relace-relace-apply-3); listed as recommended apply model in [Continue docs](https://docs.continue.dev/customize/model-roles/apply).
- **License/host:** **proprietary, hosted-only**. No open weights, no self-host.
- **Pricing:** $0.85 / M input + $1.25 / M output for Apply 3 (256K context). Approx. 2× Morph's typical billing pattern; comparable order of magnitude.
- **Latency:** ~10,000 tok/s claim (per docs.relace.ai).
- **MCP:** **no official Relace MCP server found** on GitHub or in Continue's listing. Continue.dev integrates Relace via its own apply role, not via MCP.
- **Privacy:** docs landing page surfaces no zero-retention statement (unverified beyond "enterprise" boilerplate).
- **Verdict:** **same exact problem as Morph** — closed, hosted SaaS with no source repo and no MCP for Claude Code. Replacing Morph with Relace is not a real win.

### 2.4 Inception Labs Mercury Edit 2 (diffusion LLM)

- **Source/URL:** [inceptionlabs.ai](https://www.inceptionlabs.ai/).
- **What it is:** Mercury Edit 2 — small diffusion LLM positioned for code editing.
- **License/host:** hosted via inception API + AWS Bedrock + Azure Foundry. **No open weights** (verified — page mentions enterprise / private deployments but not open release).
- **Pricing:** $0.25 / M input, $0.75 / M output — cheapest of the bunch.
- **Latency:** "several times faster"; no published tok/s figure.
- **MCP:** none.
- **Maturity:** team from Stanford/UCLA/Cornell/DeepMind; well-funded but no public stars metric since closed.
- **Verdict:** interesting on price + speed, **but no MCP, no open weights, no Claude Code integration today**. Same closed-SaaS shape as Morph/Relace; would need a custom MCP wrapper. Not a drop-in.

### 2.5 Kortix FastApply (open weights — the strongest candidate)

- **Source/URLs:**
  - GitHub: [kortix-ai/fast-apply](https://github.com/kortix-ai/fast-apply) — **Apache-2.0**, **402 stars**.
  - Models: [Kortix/FastApply-1.5B-v1.0](https://huggingface.co/Kortix/FastApply-1.5B-v1.0) and [Kortix/FastApply-7B-v1.0](https://huggingface.co/Kortix/FastApply-7B-v1.0) — **Apache-2.0**, base = Qwen2.5-Coder.
  - Quantized GGUF for Ollama / llama.cpp / LM Studio / Jan: 15 community quantizations indexed on HF.
- **Architecture:** Qwen2.5-Coder fine-tuned with QLoRA on the kortix-ai/fast-apply-dataset (~5,600 examples, 80% TS/TSX, 15% Python, 5% other; synthetic data generated with Claude 3.5 Sonnet 70% + GPT-4 30%).
- **Prompt contract** (verified in HF model card):

  ```text
  <code>{original_code}</code>
  <update>{update_snippet}</update>
  → <updated-code>...</updated-code>
  ```

  Same shape as Morph's `<code>` + `<update>` + `<instruction>` — **drop-in semantically**.
- **Latency:** ~340 tok/s on Fireworks for the 1.5B; ~150 tok/s for 7B (per HF card). Local on a workstation GPU is realistic; pure CPU is sluggish but possible for 1.5B-Q4.
- **VRAM:** ~3.1 GB for 1.5B BF16, ~2 GB Q4 (per [LLM Explorer](https://llm-explorer.com/model/Kortix%2FFastApply-1.5B-v1.0,7rhYj7Idx0z7t53sraupMF)).
- **Privacy:** **fully local** when self-hosted. No data leaves the box.
- **MCP integration:** **two community MCP servers exist**:
  - `tickernelz/fastapply-mcp` — MIT, **2 stars**, exposes `fast_apply_edit(target_filepath, original_code, code_edit)`. Backend-agnostic via `FAST_APPLY_URL` (Ollama / LM Studio / vLLM / any OpenAI-compatible). Documented Claude Desktop / Claude Code config. ([GitHub](https://github.com/tickernelz/fastapply-mcp))
  - `betmoar/FastApply-MCP` — MIT, **7 stars**, broader scope (15+ tools incl. AST search, security scan). Claude-Code-ready config snippet in README. ([GitHub](https://github.com/betmoar/fastapply-mcp))
- **Maturity caveat:** the model itself (402 stars, kortix-ai is the org behind Suna AI / SoftGen) is reasonably credible. The **two MCP wrappers are tiny** (≤7 stars). Treat MCP wrappers as reference implementations — fork or reimplement if depended on.
- **Downloads (signal of real use):** 192 last month for FastApply-1.5B-v1.0 (per HF). Modest but non-zero — model is alive, MCPs are not yet popular.

### 2.6 Aider's diff-format pattern (no apply model — different mental model)

- **Source/URL:** [aider edit formats](https://aider.chat/docs/more/edit-formats.html), [unified diffs writeup](https://aider.chat/docs/unified-diffs.html), [edit leaderboard](https://aider.chat/docs/leaderboards/edit.html).
- **Approach:** agent emits a unified diff (`udiff`) or `diff-fenced` block; client applies it deterministically — **no second model call**.
- **Token economics:** comparable to Morph for the *agent's* output (only changed lines), without a server-side apply step. Saves money + a network hop.
- **License/host:** Aider is Apache-2.0; the diff-emit prompts and parsers are reusable patterns, not a service.
- **MCP integration:** none needed. Could be implemented as a Claude Code skill / hook that nudges Claude to emit udiff and post-processes.
- **Risk:** Anthropic models have not been benchmarked on udiff format the way GPT-4-Turbo was; whether Sonnet 4.6/4.7/Opus 4.7 emit clean udiffs without fenceposts is **unverified** for our use case.
- **Verdict:** philosophically closest match to "remove a paid third party"; but the toolkit would have to author the prompt + parser, and we'd be reinventing what Claude Code's Edit tool already does at the string-replace level.

### 2.7 Cursor Apply (reference only)

- **Closed-source.** Mentioned only as the ground truth most users compare to. Not installable outside Cursor.

### 2.8 Continue / Continue.dev apply role

- **Source:** [Continue apply role docs](https://docs.continue.dev/customize/model-roles/apply).
- Continue.dev itself is open-source (Apache-2.0) but its apply *model* recommendations are **Morph or Relace** — same SaaS we're trying to leave. Continue does support "any chat model as apply" (e.g. Claude 3.5 Haiku) — that's just falling back to a generic LLM as apply, which is what Anthropic Edit already implicitly does.
- **Verdict:** Continue's catalog confirms our finding: in May 2026 the only credible specialized apply models are Morph, Relace, and Kortix FastApply.

### 2.9 Other npm/MCP packages

- `razorback16/morph-mcp` — depends on Morph API key; not an alternative. ([GitHub](https://github.com/razorback16/morph-mcp))
- `JRedeker/opencode-morph-fast-apply` — wraps Morph; not an alternative (MIT, 127 stars, OpenCode-only). ([GitHub](https://github.com/JRedeker/opencode-morph-fast-apply))
- `lobehub/ufvice-mcp-edit-service` — wraps Morph; not an alternative.
- `@morphllm/morphmcp` — Morph itself.
- No npm package literally named `fast-apply`, `apply-model`, `code-apply`, or `diff-apply` produced a non-Morph, MCP-ready hit.

---

## 3. Match-to-gap matrix

| Feature ↓ / Tool → | Anthropic Edit (native) | OpenAI Predicted Outputs | Relace Apply 3 | Inception Mercury Edit 2 | **Kortix FastApply** | Aider udiff pattern |
| --- | --- | --- | --- | --- | --- | --- |
| Open source / source available | client closed, model closed | closed | closed | closed | **Apache-2.0 weights + repo** | Apache-2.0 (pattern, no service) |
| Self-hostable | no (managed Claude) | no | no | no (Bedrock/Azure deploy ≠ self-host) | **yes (Ollama / vLLM / LM Studio)** | n/a (no model) |
| Open MCP integration today | built-in, not MCP | none | none official | none | **2 community MCPs (small)** | none (skill/hook authorable) |
| Cost per 1M tokens | Sonnet ~$3 in / $15 out | gpt-4o $2.50 / $10 + rejected-token risk | $0.85 / $1.25 | $0.25 / $0.75 | **$0 (local)** or hosting GPU cost | $0 marginal (uses chat model) |
| Latency claim | n/a (string replace) | 3–5× via spec decode | ~10,000 tok/s | "several times faster" | ~340 tok/s (1.5B Fireworks); ~70–200 tok/s local | n/a |
| Privacy: code stays local? | leaves to Anthropic | leaves to OpenAI | leaves to Relace | leaves to Inception/Bedrock | **yes — fully local possible** | code stays in agent ↔ Anthropic only |
| Maintainer / signal | Anthropic | OpenAI | YC startup, closed | Stanford/DeepMind alums, closed | Kortix (Suna/SoftGen), 402★ + 192 dl/mo | Paul Gauthier (aider), 30k★ |
| Works in Claude Code today | **yes, by default** | no (no MCP) | no (no MCP) | no (no MCP) | **yes via 2 MCPs (≤7★)** or 1 day of glue | yes via skill/hook, ~1 day of glue |
| Activity (Apr–May 2026) | continuous | continuous | active | active | model April 2025; MCPs Q4 2025 / 2026 | active |

---

## 4. Recommendation

### 4.1 The honest answer

**There is no MIT/Apache, well-maintained, ≥2k-star, plug-and-play apply-model MCP for Claude Code in May 2026.** Closest credible options are:

- Kortix **FastApply** (model: 402★ Apache-2.0; **MCP wrappers are immature: 2★ and 7★**).
- Anthropic's **native Edit tool** — already shipped, no third party.
- Aider's **udiff pattern** — reusable idea, no plug-in for Claude Code.

So the honest report to the user is: **Anthropic should ship native apply (they have not as of May 2026). Until they do, the toolkit's safest default is the native Edit tool.** Adding any apply MCP is opt-in, not default.

### 4.2 Pragmatic stack to recommend

1. **Default for everyone:** native `Edit` tool. Removes a hop, no third party, no MCP. Loses speed only on large rewrites — and Claude Code agents already break those into multiple Edits anyway.
2. **Opt-in advanced (privacy-conscious / power user with a GPU):** **Kortix FastApply-1.5B via Ollama or vLLM, fronted by `tickernelz/fastapply-mcp`** — but **mark it experimental**. The model has reasonable provenance; the MCP wrapper does not yet meet the toolkit's "≥2k stars OR known maintainer" bar.
3. **Opt-in cost-routed (cheap, hosted, non-Anthropic):** the toolkit already has the cost-routing wrapper (`better-model`); recommend Sonnet-as-apply for code edits, not a separate apply provider. This is what Continue.dev calls "any chat model as apply" and what aider has used since 2024.

### 4.3 Why not just swap Morph → Relace

Relace is the same shape: closed, hosted, no open weights, no MCP. Replacing one black-box SaaS with another doesn't address the user's stated reason for removing Morph (supply-chain audit + no source repo). **Skip Relace.**

### 4.4 Why not Mercury / Predicted Outputs as default

- Mercury Edit 2: cheap and fast, but closed and no MCP. Toolkit would have to author and maintain a wrapper for a vendor we don't trust more than Morph.
- OpenAI Predicted Outputs: only useful inside an OpenAI call. Adding an OpenAI hop to a Claude Code workflow is architecturally backward and adds a second vendor relationship.

---

## 5. What to do in the toolkit (concrete actions)

1. **Remove the Morph catalog entry.** Replace with a one-paragraph "why we removed it" note in the same MCP catalog file: closed source, no public repo for `@morphllm/morphsdk`, sends every code edit to a hosted SaaS with no zero-retention statement on the docs page.
2. **Do NOT add a Morph replacement as default.** Document explicitly in the catalog: "Claude Code's native Edit tool covers 95% of fast-apply use cases. We don't ship a default apply-model MCP."
3. **Add an EXPERIMENTAL catalog entry for Kortix FastApply** with the following caveats baked in:
   - Marked `experimental` (per toolkit's own ≥2k-star rule).
   - Lists requirements: GPU + Ollama/vLLM, Apache-2.0 model, ~3 GB VRAM for 1.5B-Q4.
   - Points at `tickernelz/fastapply-mcp` (MIT) as the reference MCP, with the warning that the wrapper has 2 stars and may need forking.
   - Sample `claude_desktop_config.json` snippet (already in the upstream README).
4. **Optional follow-up (not in this PR):** if real demand surfaces, the toolkit could ship its own audited fork of `tickernelz/fastapply-mcp` under `claude-code-toolkit/fastapply-mcp`. ~1 day of work — the upstream is small and the contract is the model card's exact prompt format. Defer until at least one user asks.

---

## 6. Sources (every URL cited above)

- Morph
  - [docs.morphllm.com — Fast Apply](https://docs.morphllm.com/sdk/components/fast-apply)
  - [npm @morphllm/morphsdk](https://www.npmjs.com/package/@morphllm/morphsdk)
  - [npm @morph-llm/morph-fast-apply (deprecated)](https://www.npmjs.com/package/@morph-llm/morph-fast-apply)
  - [github.com/morphllm](https://github.com/morphllm)
  - [Predicted Outputs comparison page (Morph)](https://www.morphllm.com/openai/predicted-outputs)
- Anthropic
  - [Edit / text-editor tool](https://platform.claude.com/docs/en/agents-and-tools/tool-use/text-editor-tool)
  - [Claude Code overview](https://code.claude.com/docs/en/overview)
  - [Releasebot Anthropic May 2026](https://releasebot.io/updates/anthropic/claude)
  - ["Replace Is All You Need" — Medium](https://medium.com/@rquintino/replace-is-all-you-need-the-surprisingly-simple-technique-behind-claudes-new-lightning-fast-b5ae18c3c113)
  - [Built-in tools reference — vtrivedy](https://www.vtrivedy.com/posts/claudecode-tools-reference)
- OpenAI
  - [Predicted Outputs guide](https://developers.openai.com/api/docs/guides/predicted-outputs)
  - [Azure / Foundry mirror](https://learn.microsoft.com/en-us/azure/foundry/openai/how-to/predicted-outputs)
- Relace
  - [docs.relace.ai](https://docs.relace.ai/)
  - [pricepertoken — Relace Apply 3](https://pricepertoken.com/pricing-page/model/relace-relace-apply-3)
- Inception Labs
  - [inceptionlabs.ai](https://www.inceptionlabs.ai/)
- Kortix FastApply
  - [GitHub kortix-ai/fast-apply](https://github.com/kortix-ai/fast-apply)
  - [HF Kortix/FastApply-1.5B-v1.0](https://huggingface.co/Kortix/FastApply-1.5B-v1.0)
  - [HF Kortix/FastApply-7B-v1.0](https://huggingface.co/Kortix/FastApply-7B-v1.0)
  - [LLM Explorer — VRAM](https://llm-explorer.com/model/Kortix%2FFastApply-1.5B-v1.0,7rhYj7Idx0z7t53sraupMF)
- MCP wrappers
  - [tickernelz/fastapply-mcp](https://github.com/tickernelz/fastapply-mcp)
  - [betmoar/fastapply-mcp](https://github.com/betmoar/fastapply-mcp)
  - [razorback16/morph-mcp](https://github.com/razorback16/morph-mcp)
  - [JRedeker/opencode-morph-fast-apply](https://github.com/JRedeker/opencode-morph-fast-apply)
- Aider
  - [aider edit formats](https://aider.chat/docs/more/edit-formats.html)
  - [unified diffs writeup](https://aider.chat/docs/unified-diffs.html)
  - [edit leaderboard](https://aider.chat/docs/leaderboards/edit.html)
- Continue.dev
  - [apply role docs](https://docs.continue.dev/customize/model-roles/apply)
  - [Morph in Continue](https://docs.continue.dev/customize/model-providers/more/morph)

### Unverified claims (called out for honesty)

- Morph's "98% accuracy" — Morph self-reports; no third-party benchmark cited.
- Morph "10,500 tok/s" — Morph self-reports; verifiable only against their hosted endpoint.
- Relace "10,000 tok/s" — Relace self-reports.
- "Predicted Outputs 3–5× speedup" — page citing it is Morph's comparison page, not OpenAI's official benchmark; OpenAI docs say only "speeds up responses" without a specific multiplier.
- Inception Mercury Edit 2 "several times faster" — vendor claim, no benchmark.
- Kortix FastApply 340 tok/s — Fireworks-specific number from the model card; local hardware will be much slower.
