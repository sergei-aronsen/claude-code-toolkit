# Comet Research — Security Model and Setup Guide

> Reusable component. Reference this from `CLAUDE.md` if your project relies on
> the `comet-bridge` MCP for `/research`, `/lookup`, or `/factcheck`.

The `comet-bridge` MCP gives Claude Code a research backend that uses your
**Perplexity Pro subscription** instead of paying per token for the Sonar API.
The bridge talks to a locally-running Comet browser (Perplexity's Chromium
fork) over the Chrome DevTools Protocol.

This document explains the **security model** — because giving an AI agent
DOM-level access to a browser session is non-trivial.

---

## Threat Model

The MCP agent has, via CDP:

- DOM read on every open tab in the connected Comet profile
- Click / type / submit / navigate on those tabs
- Open new tabs to any URL
- Trigger downloads to the user's filesystem

**If the connected Comet profile is logged into your personal Google account
on the side, then prompt injection in any single research result can drain
your Gmail, Drive, banking, GitHub, password manager, etc.**

The mitigation is profile isolation. Treat the Comet profile that MCP
connects to as **single-purpose**: only Perplexity, nothing else.

---

## Required Setup

`scripts/setup-comet.sh` automates everything below. Read this section to
understand what it does and why.

### 1. Dedicated Comet profile

```bash
mkdir -p ~/comet-profiles/mcp-only
chmod 700 ~/comet-profiles/mcp-only
```

Comet is launched with `--user-data-dir=$HOME/comet-profiles/mcp-only` so it
keeps a profile separate from your personal Comet profile.

### 2. CDP bound to localhost

Comet is launched with:

```text
--remote-debugging-port=9223
--remote-debugging-address=127.0.0.1
```

CDP listens **only on the loopback interface**. No remote connections accepted.
Any local process on your machine can still connect — see the kill switch
section.

### 3. Perplexity-only login

Inside the isolated profile:

- Sign in to perplexity.ai with **email + OTP** (do not use Google SSO; OTP
  arrives in your normal mail client outside Comet, never log into mail
  inside this profile).
- **Disable** Password Manager, Autofill, and Sync in Comet Settings.
- Disable browsing history if your queries are sensitive.
- **Do not** import settings from Chrome or any other browser. Importing
  copies cookies and saved sessions and breaks isolation.

### 4. Optional — burner Perplexity account

If your queries reveal client/business context that you would not want
intermixed with personal queries, create a separate Perplexity account on a
dedicated email (Apple Hide My Email, ProtonMail, etc.) and move the Pro
subscription to that account.

### 5. Project-scope MCP only

Register `comet-bridge` with `--scope project`, never global:

```bash
claude mcp add comet-bridge --scope project --env COMET_PORT=9223 \
  -- npx -y perplexity-comet-mcp
```

This way only the projects you explicitly opt in get DOM access to Comet.
Sessions of Claude Code in unrelated directories are isolated.

### 6. Kill switch

Comet runs only when you actively need MCP. After research:

```bash
~/comet-mcp/stop.sh
```

This kills only the isolated-profile Comet (filtered by
`--remote-debugging-port=9223`), not your personal Comet windows.

---

## Operational Checklist

Before each research session, verify:

- [ ] `lsof -nP -iTCP:9223 -sTCP:LISTEN` shows Comet, not something else.
- [ ] Only `perplexity.ai` tabs are open in the isolated profile.
- [ ] You are signed in **only** to Perplexity (no Google, no Gmail, no
      GitHub, no banking).
- [ ] macOS Firewall is on (System Settings → Network → Firewall).

After:

- [ ] Run `~/comet-mcp/stop.sh`.
- [ ] Periodically clear Perplexity chat history of sensitive queries.

---

## When to Use Comet vs Other Tools

| Need | Tool | Why |
|------|------|-----|
| Library docs (React, Next.js, Stripe SDK) | `context7` MCP | Official docs, fast, no Comet needed |
| Current API version / release date / deprecation | `/lookup` | Fresh facts with citations, free via Pro |
| Multi-source comparison / market state | `/research` | Deep multi-step, 15-30 sources |
| Verify a specific claim | `/factcheck` | Structured verdict |
| Random web page content | `WebFetch` | One-off, no JS rendering |
| JS-heavy page or paywall content | `comet_ask` with explicit URL | Comet renders JS, has your sessions |
| Production code automation | Sonar API (paid) | No browser dependency, predictable SLA |

---

## What This Component Does Not Cover

- Sonar API integration (separate concern; for production-grade
  programmatic use)
- Council fact-check pre-flight (`PR-2` in the toolkit roadmap)
- GSD planning hooks (`PR-3`)

These extend the same `comet-bridge` MCP but live in their own components.

---

## ToS Reminder

Cookie/CDP-based bridges to Perplexity are a gray area under their Terms of
Service. Perplexity's official position is that automated access requires
the API. Use this bridge responsibly:

- Do not run high-volume automated workloads through it.
- Do not redistribute or resell the resulting answers.
- Personal research and small-team development use is the expected scope.

If your usage is commercial / high-volume / customer-facing, switch to the
official Sonar API.
