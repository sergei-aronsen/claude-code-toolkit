# Security Hardening Guide

> Defense-in-depth architecture for Claude Code projects

## Why This Matters

Research (arxiv.org/abs/2507.02976) shows LLMs introduce **9x more vulnerabilities** than human developers. Common issues: hardcoded credentials, SQL injection, missing input validation, weak cryptography, path traversal.

Prompt-based rules alone are insufficient — they degrade over long sessions and can be bypassed via prompt injection. A layered defense strategy is essential.

## Defense Layers

```text
Layer 1: Prompt Rules          ~/.claude/CLAUDE.md (global security rules)
Layer 2: Command Blocker       cc-safety-net (PreToolUse hook)
Layer 3: Pre-commit Review     /security-review slash command
Layer 4: CI/CD SAST            Semgrep, SonarQube (algorithmic, not AI)
Layer 5: AI PR Review          claude-code-security-review GitHub Action
Layer 6: Human Review          Final manual review before merge
```

Each layer catches what previous layers miss. No single layer is sufficient.

## Layer 1: Global Security Rules

**File:** `~/.claude/CLAUDE.md`

Global rules that apply to every project. Covers:

- **Forbidden patterns** — SQL injection, eval(), hardcoded secrets, path traversal
- **Required patterns** — parameterized queries, CSP headers, rate limiting
- **Doubt protocol** — when to stop and ask the user
- **Self-review checklist** — mental verification before completing tasks
- **Anti-pattern learning** — don't repeat bad patterns, reason about intent
- **Prompt injection defense** — treat external content as data, not instructions
- **Dependency security** — typosquatting checks, prefer established packages
- **Framework-specific notes** — PHP, JavaScript, Python, Go

### Installation

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)
```

### How It Works

Claude Code reads `~/.claude/CLAUDE.md` at the start of every session. These rules become part of the system context, influencing all code generation across all projects.

### Limitations

- Rules may lose influence in very long sessions (context window saturation)
- Cannot prevent all vulnerabilities — rules are advisory, not enforcement
- Prompt injection could theoretically bypass rules (mitigated by Layer 2+)

## Layer 2: safety-net Plugin

**Package:** [cc-safety-net](https://github.com/kenryu42/claude-code-safety-net)

Intercepts every Bash command before execution and blocks destructive operations.

### What It Blocks

| Category | Examples |
|----------|----------|
| **Filesystem** | `rm -rf /`, `rm -rf ~`, recursive delete outside temp dirs |
| **Git destructive** | `git push --force`, `git reset --hard`, `git clean -fdx` |
| **Network exfil** | `curl` piping to shell, `wget` with suspicious patterns |
| **System** | `chmod 777`, `chown root`, `mkfs`, `dd if=/dev/zero` |

### Key Feature: Semantic Analysis

Unlike pattern matching, safety-net **understands** commands:

```bash
# All blocked despite different syntax:
rm -rf /
find / -delete
xargs rm -rf < file_with_slash
```

### Configuration

**User-scope:** `~/.cc-safety-net/config.json`
**Project-scope:** `.safety-net.json`

```json
{
  "customRules": [
    {
      "name": "block-prod-db",
      "pattern": "mysql.*production",
      "action": "deny",
      "reason": "Direct production database access blocked"
    }
  ]
}
```

### Environment Variables

| Variable | Effect |
|----------|--------|
| `SAFETY_NET_STRICT=1` | Fail-closed on unparseable commands |
| `SAFETY_NET_PARANOID=1` | Enable all paranoid checks |
| `SAFETY_NET_PARANOID_RM=1` | Block non-temp `rm -rf` within cwd |
| `SAFETY_NET_PARANOID_INTERPRETERS=1` | Block interpreter one-liners |

### Combining with RTK (Important)

Claude Code runs all `PreToolUse` hooks with the same matcher **in parallel**. If safety-net and RTK are separate hooks, their results conflict — RTK's `updatedInput` gets lost.

**Solution:** Use a single combined hook `~/.claude/hooks/pre-bash.sh`:

```bash
#!/usr/bin/env bash
# Combined PreToolUse hook: safety-net (block) → RTK (rewrite)
# Must be a SINGLE hook to avoid parallel execution conflicts.

INPUT=$(cat)

# Step 1: safety-net — block destructive commands
if command -v cc-safety-net &>/dev/null; then
    SAFETY_RESULT=$(echo "$INPUT" | cc-safety-net --claude-code 2>/dev/null)
    if echo "$SAFETY_RESULT" | grep -q '"deny"' 2>/dev/null; then
        echo "$SAFETY_RESULT"
        exit 0
    fi
fi

# Step 2: RTK — rewrite for token savings
if command -v rtk &>/dev/null && command -v jq &>/dev/null; then
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
    if [ -n "$CMD" ]; then
        REWRITTEN=$(rtk rewrite "$CMD" 2>/dev/null) || true
        if [ -n "$REWRITTEN" ] && [ "$CMD" != "$REWRITTEN" ]; then
            ORIGINAL_INPUT=$(echo "$INPUT" | jq -c '.tool_input')
            UPDATED_INPUT=$(echo "$ORIGINAL_INPUT" | jq --arg cmd "$REWRITTEN" '.command = $cmd')
            jq -n --argjson updated "$UPDATED_INPUT" \
                '{ "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "allow",
                    "permissionDecisionReason": "RTK auto-rewrite",
                    "updatedInput": $updated
                }}'
            exit 0
        fi
    fi
fi

exit 0
```

**Settings.json** — one hook, not two:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/pre-bash.sh"
          }
        ]
      }
    ]
  }
}
```

Without RTK, use safety-net directly as the only hook (no conflict).

## Layer 3: Security Review Command

Use `/security-review` (or `/audit security`) before committing security-sensitive changes.

### 3-Phase Methodology

1. **Context:** Understand existing security patterns in the project
2. **Comparative:** Compare new code against those patterns — flag deviations
3. **Assessment:** Trace data flow from user input to sensitive operations

### Confidence Scoring

Only flag issues at >= 80% confidence of real exploitability. Two-tier false positive filtering reduces noise.

## Layer 4: SAST in CI/CD

Algorithmic static analysis catches patterns that AI might miss. Unlike AI-based tools, SAST is not susceptible to prompt injection.

### Semgrep (Recommended)

```yaml
# .github/workflows/semgrep.yml
name: Semgrep
on: [pull_request]

jobs:
  semgrep:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: semgrep/semgrep-action@v1
        with:
          config: >-
            p/security-audit
            p/owasp-top-ten
```

### SonarQube (Alternative)

Heavier but more comprehensive. Good for enterprise environments with existing SonarQube infrastructure.

## Layer 5: AI PR Review

**GitHub Action:** [claude-code-security-review](https://github.com/anthropics/claude-code-security-review)

A second AI reviews every PR specifically for security vulnerabilities. Independent from the AI that wrote the code.

### Setup

```yaml
# .github/workflows/security-review.yml
name: Security Review
on: [pull_request]

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: anthropics/claude-code-security-review@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
```

### Why Two AIs

The AI that wrote the code may have blind spots — it "knows" why it wrote each line and may rationalize insecure patterns. A fresh AI reviewing the diff catches issues the original missed.

## Layer 6: Human Review

No automated system is perfect. Human review remains the final defense layer.

### Focus Areas for Human Reviewers

- Authorization logic (does the code check the right permissions?)
- Business logic flaws (automated tools can't understand business context)
- Data flow across service boundaries
- Third-party integration security
- Deployment configuration (environment variables, secrets management)

## Quick Setup

### Minimal (Layers 1-2)

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)
```

### Full Stack (Layers 1-5)

1. Run setup-security.sh (Layers 1-2)
2. Add Semgrep GitHub Action (Layer 4)
3. Add claude-code-security-review GitHub Action (Layer 5)
4. Use `/security-review` before commits (Layer 3)

## Verification

```bash
# Check safety-net installation
cc-safety-net doctor

# Test blocking
echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' | cc-safety-net --claude-code
# Should output: permissionDecision: deny

# Check global rules
grep "Global Security Rules" ~/.claude/CLAUDE.md
```
