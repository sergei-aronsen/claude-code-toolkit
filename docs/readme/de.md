# Claude Code Toolkit

Umfassende Anleitungen fuer KI-gestuetzte Entwicklung mit Claude Code.

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](../../README.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **Deutsch** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

> Lies zuerst die vollstaendige [Schritt-fuer-Schritt Installationsanleitung](../howto/de.md).

---

## Fuer wen ist das

**Solo-Entwickler**, die Produkte mit [Claude Code](https://docs.anthropic.com/en/docs/claude-code) erstellen.

Unterstuetzte Stacks: **Laravel/PHP**, **Ruby on Rails**, **Next.js**, **Node.js**, **Python**, **Go**.

**7 Templates** (basic, Laravel, Rails, Next.js, Node.js, Python, Go)

**29 Slash Commands** | **7 Audits** | **30 Anleitungen** | Siehe [vollstaendige Liste der Commands, Templates, Audits und Komponenten](../features.md#slash-commands-29-total).

---

## Schnellstart

### 1. Globale Einrichtung (einmalig)

#### a) Security Pack

Defense-in-Depth Sicherheits-Setup. Siehe [components/security-hardening.md](../../components/security-hardening.md) fuer die vollstaendige Anleitung.

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh | bash
```

#### b) RTK — Token-Optimierer (empfohlen)

[RTK](https://github.com/rtk-ai/rtk) reduziert den Token-Verbrauch um 60-90% bei Entwicklungsbefehlen (`git status`, `cargo test`, usw.).

```bash
brew install rtk
rtk init -g
```

> **Hinweis:** Das Security Pack (Schritt 1a) konfiguriert bereits einen kombinierten Hook, der safety-net und RTK sequenziell ausfuehrt.
> Siehe [components/security-hardening.md](../../components/security-hardening.md) fuer Details.

#### c) Rate Limit Statusline (Claude Max / Pro, optional)

Zeigt Sitzungs-/Woechentliche Limits in der Statusleiste an. Mehr: [components/rate-limit-statusline.md](../../components/rate-limit-statusline.md)

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-statusline.sh | bash
```

### 2. Installation (pro Projekt)

Der Installer:

- Fragt nach deinem **Stack** (Auto-Erkennung empfohlen)
- Installiert das Toolkit (Befehle, Agenten, Prompts, Skills)
- Richtet **Supreme Council** ein (Multi-AI Review mit Gemini + ChatGPT)
- Fuehrt durch die API-Key-Konfiguration

Fuehre im Terminal im Projektordner aus:

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

**Claude neu starten!** Fuer zukuenftige Updates verwende den `/update-toolkit` Befehl.

---

## Killer-Features

| Feature | Beschreibung |
|---------|--------------|
| **Self-Learning** | `/learn` speichert einmalige Loesungen; Skill Accumulation erfasst wiederkehrende Muster automatisch |
| **Auto-Activation Hooks** | Hook faengt Prompts ab, bewertet Kontext (Keywords, Intent, Dateipfade), empfiehlt relevante Skills |
| **Knowledge Persistence** | Projektfakten in `.claude/rules/` — automatisch bei jeder Sitzung geladen, in Git committet, auf jedem Rechner verfuegbar |
| **Systematic Debugging** | `/debug` erzwingt 4 Phasen: Ursache → Muster → Hypothese → Fix. Kein Raten |
| **Production Safety** | `/deploy` mit Pre-/Post-Checks, `/fix-prod` fuer Hotfixes, inkrementelle Deployments |
| **Supreme Council** | `/council` sendet Plaene an Gemini + ChatGPT fuer unabhaengige Pruefung vor dem Coding |
| **Structured Workflow** | 3 Pflichtphasen: RECHERCHE (nur lesen) → PLAN (Scratchpad) → AUSFUEHRUNG (nach Bestaetigung) |

Siehe [detaillierte Beschreibungen und Beispiele](../features.md).

---

## MCP-Server (empfohlen!)

| Server | Zweck |
|--------|-------|
| `context7` | Bibliotheks-Dokumentation |
| `playwright` | Browser-Automatisierung, UI-Tests |
| `sequential-thinking` | Schrittweise Problemloesung |

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add playwright -- npx @playwright/mcp@latest
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
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
