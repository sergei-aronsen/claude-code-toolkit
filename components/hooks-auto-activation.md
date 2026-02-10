# Hooks: Auto-Activation System

Automatic skill/command activation based on prompt context.

**Inspired by:**

- [claude-code-infrastructure-showcase](https://github.com/diet103/claude-code-infrastructure-showcase)
- [claude-code-showcase](https://github.com/ChrisWiles/claude-code-showcase)

---

## Problem

You have 10 commands/skills but forget to use them. You write "make API endpoint" and Claude does it its own way, even though you have project rules.

## Solution

Hook intercepts prompt **BEFORE** sending to Claude, analyzes context and suggests which skill to use.

```text
User prompt -> Hook analyzes -> Scoring -> Confidence -> Recommendations
```

---

## Key Concepts

### Scoring (Points)

Different trigger types give different points:

| Trigger | Points | Why |
|---------|--------|-----|
| `keywords` | 2 | Simple word match |
| `keywordPatterns` | 3 | Regex on keywords |
| `intentPatterns` | 4 | Understanding intent |
| `pathPatterns` | 5 | Context of open files |
| `contentPatterns` | 4 | Content analysis |

**Example:**

```text
Prompt: "create endpoint for users"
Open file: src/api/users.controller.ts

Skill "backend-dev":
  - keyword "endpoint" = +2
  - intentPattern "(create|add).*endpoint" = +4
  - pathPattern "src/api/**" = +5
  -----------------------------------
  TOTAL: 11 points -> HIGH confidence
```

### Confidence Levels

Points convert to confidence levels:

| Level | Condition | Meaning |
|-------|-----------|---------|
| HIGH | `score >= threshold x 3` | Definitely needed |
| MEDIUM | `score >= threshold x 2` | Probably needed |
| LOW | `score >= threshold` | May be useful |
| - | `score < threshold` | Don't show |

With `minConfidenceScore: 4`:

- HIGH = 12+ points
- MEDIUM = 8-11 points
- LOW = 4-7 points
- Hidden = 0-3 points

### Exclude Patterns

Patterns that **exclude** skill even when triggers match:

```json
{
  "backend-dev": {
    "triggers": { "keywords": ["api", "endpoint"] },
    "excludePatterns": ["mock", "test", "spec", "__tests__"]
  }
}
```

```text
Prompt: "create mock for api"
  - keyword "api" = +2
  - excludePattern "mock" found -> EXCLUDE
  -> Skill NOT recommended
```

---

## File Structure

```text
.claude/
+-- hooks/
|   +-- skill-activation.sh           # Shell wrapper
|   +-- skill-activation.ts           # Logic with scoring
|   +-- skill-rules.schema.json       # JSON Schema (optional)
+-- skills/
|   +-- skill-rules.json              # Activation rules
|   +-- [skill-name]/
|       +-- SKILL.md
+-- settings.json                      # Hook registration
```

---

## Configuration

### 1. settings.json

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [".claude/hooks/skill-activation.sh"]
      }
    ]
  }
}
```

### 2. skill-activation.sh

```bash
#!/bin/bash
set -e
cd "$(dirname "$0")"
cat | npx tsx skill-activation.ts
```

### 3. skill-rules.json

```json
{
  "$schema": "./skill-rules.schema.json",
  "version": "2.0",
  "config": {
    "minConfidenceScore": 4,
    "maxSkillsToShow": 3
  },
  "scoring": {
    "keywords": 2,
    "keywordPatterns": 3,
    "intentPatterns": 4,
    "pathPatterns": 5,
    "contentPatterns": 4
  },
  "skills": {
    "backend-dev": {
      "description": "Backend development guidelines",
      "priority": 8,
      "triggers": {
        "keywords": ["backend", "api", "endpoint", "route", "controller"],
        "intentPatterns": [
          "(create|add|make).*?(endpoint|api|route)",
          "(implement|build).*?(service|controller)"
        ],
        "pathPatterns": ["src/api/**", "src/services/**", "src/controllers/**"]
      },
      "excludePatterns": ["mock", "test", "spec", "fake", "__tests__"]
    },
    "testing": {
      "description": "Testing conventions and patterns",
      "priority": 6,
      "triggers": {
        "keywords": ["test", "spec", "jest", "vitest", "coverage"],
        "intentPatterns": ["(write|add|create).*?test", "(add|improve).*?coverage"],
        "pathPatterns": ["**/*.test.ts", "**/*.spec.ts", "**/tests/**"]
      },
      "excludePatterns": []
    },
    "security-review": {
      "description": "Security-critical code review",
      "priority": 9,
      "triggers": {
        "keywords": ["auth", "password", "token", "jwt", "session", "secret"],
        "intentPatterns": [
          "(change|modify|update).*?(auth|login|password)",
          "(add|remove).*?(permission|role|access)"
        ],
        "pathPatterns": ["**/auth/**", "**/security/**"]
      },
      "excludePatterns": ["test", "mock", "example"]
    },
    "database": {
      "description": "Database and migration guidelines",
      "priority": 7,
      "triggers": {
        "keywords": ["database", "migration", "schema", "prisma", "model"],
        "intentPatterns": [
          "(add|create|modify).*?(table|column|model)",
          "(write|create).*?migration"
        ],
        "pathPatterns": ["**/migrations/**", "**/schema.prisma", "**/models/**"]
      },
      "excludePatterns": ["seed", "fixture"]
    }
  }
}
```

### 4. skill-activation.ts (with Scoring)

```typescript
import * as fs from "fs";
import * as path from "path";

interface SkillTriggers {
  keywords?: string[];
  keywordPatterns?: string[];
  intentPatterns?: string[];
  pathPatterns?: string[];
  contentPatterns?: string[];
}

interface SkillRule {
  description: string;
  priority: number;
  triggers: SkillTriggers;
  excludePatterns?: string[];
}

interface SkillRules {
  version: string;
  config: {
    minConfidenceScore: number;
    maxSkillsToShow: number;
  };
  scoring: {
    keywords: number;
    keywordPatterns: number;
    intentPatterns: number;
    pathPatterns: number;
    contentPatterns: number;
  };
  skills: Record<string, SkillRule>;
}

interface HookInput {
  prompt: string;
  files?: string[];
}

interface ScoredSkill {
  name: string;
  rule: SkillRule;
  score: number;
  confidence: "HIGH" | "MEDIUM" | "LOW";
}

// Read stdin
let input = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => (input += chunk));
process.stdin.on("end", () => {
  const hookInput: HookInput = JSON.parse(input);
  const prompt = hookInput.prompt.toLowerCase();
  const files = hookInput.files || [];

  // Load rules
  const rulesPath = path.join(__dirname, "../skills/skill-rules.json");
  if (!fs.existsSync(rulesPath)) {
    process.exit(0);
  }

  const rules: SkillRules = JSON.parse(fs.readFileSync(rulesPath, "utf8"));
  const { config, scoring, skills } = rules;
  const scored: ScoredSkill[] = [];

  // Evaluate each skill
  for (const [name, rule] of Object.entries(skills)) {
    // Check exclude patterns first
    if (rule.excludePatterns?.length) {
      const excluded = rule.excludePatterns.some(
        (pattern) =>
          prompt.includes(pattern.toLowerCase()) ||
          files.some((f) => f.toLowerCase().includes(pattern.toLowerCase()))
      );
      if (excluded) continue;
    }

    let score = 0;

    // Keywords
    if (rule.triggers.keywords) {
      for (const kw of rule.triggers.keywords) {
        if (prompt.includes(kw.toLowerCase())) {
          score += scoring.keywords;
        }
      }
    }

    // Keyword patterns
    if (rule.triggers.keywordPatterns) {
      for (const pattern of rule.triggers.keywordPatterns) {
        if (new RegExp(pattern, "i").test(prompt)) {
          score += scoring.keywordPatterns;
        }
      }
    }

    // Intent patterns
    if (rule.triggers.intentPatterns) {
      for (const pattern of rule.triggers.intentPatterns) {
        if (new RegExp(pattern, "i").test(prompt)) {
          score += scoring.intentPatterns;
        }
      }
    }

    // Path patterns
    if (rule.triggers.pathPatterns && files.length > 0) {
      for (const pattern of rule.triggers.pathPatterns) {
        const regex = new RegExp(
          pattern.replace(/\*\*/g, ".*").replace(/\*/g, "[^/]*")
        );
        if (files.some((f) => regex.test(f))) {
          score += scoring.pathPatterns;
        }
      }
    }

    // Only include if meets minimum threshold
    if (score >= config.minConfidenceScore) {
      const confidence: "HIGH" | "MEDIUM" | "LOW" =
        score >= config.minConfidenceScore * 3
          ? "HIGH"
          : score >= config.minConfidenceScore * 2
            ? "MEDIUM"
            : "LOW";

      scored.push({ name, rule, score, confidence });
    }
  }

  // Sort by score (desc), then priority (desc)
  scored.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    return b.rule.priority - a.rule.priority;
  });

  // Limit output
  const toShow = scored.slice(0, config.maxSkillsToShow);

  // Output recommendations
  if (toShow.length > 0) {
    console.log("\n SKILL RECOMMENDATIONS:");
    console.log("================================");

    for (const { name, rule, score, confidence } of toShow) {
      const icon =
        confidence === "HIGH" ? "[HIGH]" : confidence === "MEDIUM" ? "[MED]" : "[LOW]";

      console.log(`${icon} ${name} (score: ${score})`);
      console.log(`   ${rule.description}`);
    }

    console.log("\n-> Use Skill tool BEFORE responding to load guidelines.");
    console.log("================================\n");
  }
});
```

### 5. skill-rules.schema.json (optional)

JSON Schema for IDE autocompletion in `skill-rules.json`. Generate from the
TypeScript interfaces above, or reference `"$schema": "./skill-rules.schema.json"` in your rules file.

---

## Output Example

```text
Prompt: "create POST endpoint for user registration"
Files: ["src/api/auth.controller.ts"]

SKILL RECOMMENDATIONS:
================================
[HIGH] backend-dev (score: 13)    — keyword "endpoint" +2, intent +4, path +5
[HIGH] security-review (score: 12) — keyword "password" +2, intent +4, path +5
================================
```

Exclusion: `"create mock for api"` → "mock" matches `excludePatterns` → skill skipped.

---

## Threshold Configuration

### Strict Mode (fewer recommendations)

```json
{
  "config": {
    "minConfidenceScore": 6,
    "maxSkillsToShow": 2
  }
}
```

### Lenient Mode (more recommendations)

```json
{
  "config": {
    "minConfidenceScore": 3,
    "maxSkillsToShow": 5
  }
}
```

### Adjusting Weights

```json
{
  "scoring": {
    "keywords": 1,
    "intentPatterns": 5,
    "pathPatterns": 6
  }
}
```

If you want file context to be more important than words - increase `pathPatterns`.

---

## Adding a New Skill

### 1. Create SKILL.md

```text
.claude/skills/my-skill/SKILL.md
```

### 2. Add to skill-rules.json

```json
{
  "skills": {
    "my-skill": {
      "description": "My skill description",
      "priority": 5,
      "triggers": {
        "keywords": ["my-keyword"],
        "intentPatterns": ["(do|make).*?something"]
      },
      "excludePatterns": ["test", "mock"]
    }
  }
}
```

### 3. Done

Hook automatically picks up the new skill.

---

## Dependencies

```bash
cd .claude/hooks/
npm init -y
npm install typescript tsx @types/node
```

---

## Troubleshooting

### Too many recommendations

1. Increase `minConfidenceScore`
2. Decrease `maxSkillsToShow`
3. Add `excludePatterns`

### Skill doesn't activate

1. Check that score >= `minConfidenceScore`
2. Check for match with `excludePatterns`
3. Add console.log in TypeScript for debugging

### IDE doesn't suggest in skill-rules.json

Add `"$schema": "./skill-rules.schema.json"` at the beginning of the file.
