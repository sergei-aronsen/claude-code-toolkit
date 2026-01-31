# Claude Toolkit

Umfassende Anleitungen fuer KI-gestuetzte Entwicklung mit Claude Code.

[![Quality Check](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](../../README.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **Deutsch** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

> Lies zuerst die vollstaendige [Schritt-fuer-Schritt Installationsanleitung](../howto/de.md).

---

## Fuer wen ist das

**Solo-Entwickler**, die Produkte mit [Claude Code](https://docs.anthropic.com/en/docs/claude-code) erstellen.

Unterstuetzte Stacks: **Laravel/PHP**, **Ruby on Rails**, **Next.js**, **Node.js**, **Python**, **Go**.

**7 Templates** (basic, Laravel, Rails, Next.js, Node.js, Python, Go)

**24 Slash Commands** | **7 Audits** | **23+ Anleitungen** | Siehe [vollstaendige Liste der Commands, Templates, Audits und Komponenten](../features.md#slash-commands-24-total).

---

## Schnellstart

### 1. Installation

Das Skript erkennt automatisch das Framework und kopiert das entsprechende Template.

Fuehre einfach im Terminal im Projektordner aus:

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

**Claude neu starten!** Fuer zukuenftige Updates verwende den `/update-toolkit` Befehl fuer Neuinstallation oder Updates.

### 2. Security Pack

Enthaelt ein Defense-in-Depth Sicherheits-Setup. Siehe [components/security-hardening.md](../../components/security-hardening.md) fuer die vollstaendige Anleitung.

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/setup-security.sh | bash
```

### 3. Rate Limit Statusline (Claude Max / Pro)

Zeigt Sitzungs-/Woechentliche Limits in der Claude Code Statusleiste an. Mehr: [components/rate-limit-statusline.md](../../components/rate-limit-statusline.md)

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/install-statusline.sh | bash
```

---

## Killer-Features

| Feature | Beschreibung |
|---------|--------------|
| **Self-Learning** | `/learn` speichert einmalige Loesungen; Skill Accumulation erfasst wiederkehrende Muster automatisch |
| **Auto-Activation Hooks** | Hook faengt Prompts ab, bewertet Kontext (Keywords, Intent, Dateipfade), empfiehlt relevante Skills |
| **Memory Persistence** | MCP-Memory nach `.claude/memory/` exportieren, in Git committen — auf jedem Rechner verfuegbar |
| **Systematic Debugging** | `/debug` erzwingt 4 Phasen: Ursache → Muster → Hypothese → Fix. Kein Raten |
| **Structured Workflow** | 3 Pflichtphasen: RECHERCHE (nur lesen) → PLAN (Scratchpad) → AUSFUEHRUNG (nach Bestaetigung) |

Siehe [detaillierte Beschreibungen und Beispiele](../features.md).

---

## MCP-Server (empfohlen!)

| Server | Zweck |
|--------|-------|
| `context7` | Bibliotheks-Dokumentation |
| `playwright` | Browser-Automatisierung, UI-Tests |
| `memory-bank` | Memory zwischen Sitzungen |
| `sequential-thinking` | Schrittweise Problemloesung |
| `memory` | Knowledge Graph (Beziehungsgraph) |

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add playwright -- npx @playwright/mcp@latest
claude mcp add memory-bank -- npx -y @allpepper/memory-bank-mcp@latest
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
claude mcp add memory -- npx -y @modelcontextprotocol/server-memory
```

---

## Struktur nach der Installation

```text
dein-projekt/
└── .claude/
    ├── CLAUDE.md              # Hauptanweisungen (fuer dein Projekt anpassen)
    ├── settings.json          # Hooks, Berechtigungen
    ├── commands/              # Slash-Befehle
    │   ├── verify.md
    │   ├── debug.md
    │   └── ...
    ├── prompts/               # Audits
    │   ├── SECURITY_AUDIT.md
    │   ├── PERFORMANCE_AUDIT.md
    │   ├── CODE_REVIEW.md
    │   ├── DESIGN_REVIEW.md
    │   ├── MYSQL_PERFORMANCE_AUDIT.md
    │   └── POSTGRES_PERFORMANCE_AUDIT.md
    ├── agents/                # Subagenten
    │   ├── code-reviewer.md
    │   ├── test-writer.md
    │   └── planner.md
    ├── skills/                # Framework-Expertise
    │   └── [framework]/SKILL.md
    ├── scratchpad/            # Arbeitsnotizen
    └── memory/                # MCP-Memory-Export
```

---

## Unterstuetzte Frameworks

| Framework | Template | Skills | Auto-Erkennung |
|-----------|----------|--------|----------------|
| Laravel | ✅ | ✅ | `artisan` Datei |
| Ruby on Rails | ✅ | ✅ | `bin/rails` / `config/application.rb` |
| Next.js | ✅ | ✅ | `next.config.*` |
| Node.js | ✅ | ✅ | `package.json` (ohne next.config) |
| Python | ✅ | ✅ | `pyproject.toml` / `requirements.txt` |
| Go | ✅ | ✅ | `go.mod` |
