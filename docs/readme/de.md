# Claude Code Toolkit

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-6.4.0-blue.svg)](../../CHANGELOG.md)

**[English](../../README.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **Deutsch** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

---

## Was ist das

Eine dünne Overlay-Schicht über [**Superpowers**](https://github.com/obra/superpowers) (Brainstorming, Subagenten, TDD, Debugging) und [**Get Shit Done**](https://github.com/gsd-build/get-shit-done) (Spec → Plan → Execute), die die Lücken schließt, die diese Plugins für Solo-Produktentwickler offen lassen.

**Für:** Solo-Gründer und One-Person-Engineering-Teams, die mit [Claude Code](https://docs.anthropic.com/en/docs/claude-code) echte Produkte ausliefern.

**Unterstützte Stacks:** Laravel · Rails · Next.js · Node.js · Python · Go.

## Welche Lücken werden geschlossen

| Lücke                                | Was das Toolkit hinzufügt                                                                                                                          |
|--------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------|
| **Multi-AI-Plan-Validierung**        | `/council` — schickt deinen Plan parallel an Gemini und ChatGPT für unabhängiges Review. Funktioniert per CLI (`gemini`, `codex`) oder direkten API-Keys. Persona-Overlays, Hash-Cache, Cost Gate, ru-Locale. |
| **Framework-Kontext**                | 7 fertige `CLAUDE.md`-Templates (base + 6 Stacks), Auto-Detection via `artisan` / `next.config` / `go.mod` / `pyproject.toml` / `package.json`.   |
| **Production Safety Net**            | `cc-safety-net` blockiert destruktive Befehle (`rm -rf /`, `git reset --hard` usw.) bei PreToolUse — auch verschleierte. Im Installer verdrahtet. |
| **Token-Kostenkontrolle**            | RTK schreibt verbose Dev-Befehl-Ausgabe um (`git status`, Test-Runner) — 60-90 % Token-Ersparnis. Kombinierter Hook mit `cc-safety-net`.          |
| **Cost Routing**                     | `better-model` routet einfache Aufgaben an günstigere Modelle. Wird automatisch installiert und in den Install-Lifecycle integriert.               |
| **Symbol-aware Code-Suche**          | [Serena](https://github.com/oraios/serena) (LSP, MIT, lokal) + ripgrep + claude-context (semantischer Vektor). Standard-Layer-3-Stack.            |
| **Multi-CLI-Bridges**                | Auto-Sync von `CLAUDE.md` zu `GEMINI.md` (Gemini CLI) und `AGENTS.md` (OpenAI Codex). Drift-Detection bei jeder Installation.                     |
| **Integrations-Katalog**             | TUI-Installer für 24 MCP-Server + 8 Companion-CLIs in 10 Kategorien (Backend / Payments / Workspace / Project Management / …). Per-Row-Scope.    |
| **Limit-Sichtbarkeit (Pro/Max)**     | Statusline zeigt Session/Weekly Usage — du siehst, wann du gegen die Wand läufst.                                                                  |
| **Dependency-Dashboard (v6.2)**      | `/update-deps` — interaktives TUI mit allen getrackten Abhängigkeiten (Layer 1/2/3) plus installed-vs-latest. Du wählst, was aktualisiert wird.    |
| **Post-Install-Setup-Guide (v6.3)**  | Erzeugt eine lokale HTML-Seite (`.claude/setup-guide.html`) mit MCP-API-Key-Walkthroughs und Komponenten-Konfiguration — nur für tatsächlich Installiertes. |

Der Kern-Mehrwert ist Kuration. Alles ist Opt-in via TUI-Checkboxen — nichts wird erzwungen.

## Installation

Ein Befehl. Im normalen Terminal **innerhalb** deines Projektordners ausführen (nicht in Claude Code):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

Der Installer zeigt eine TUI-Checkliste (Toolkit, Security, RTK, Statusline, Council, Bridges, Integrations) und erkennt, ob `superpowers` und `get-shit-done` bereits installiert sind. Wenn ja, überspringt er die Dateien, die diese Plugins schon liefern, und installiert nur die ~47 toolkit-eigenen Beiträge.

Für Claude-Desktop-Nutzer — Installation per Marketplace:

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

Vollständige Schritt-für-Schritt-Anleitung: [docs/howto/de.md](../howto/de.md).

## Nach der Installation

| Befehl             | Was er tut                                                                     |
|--------------------|--------------------------------------------------------------------------------|
| `/update-toolkit`  | Frischen Toolkit-Inhalt nach `.claude/` ziehen, lokale Bearbeitungen erhalten. |
| `/update-deps`     | Dependency-Dashboard öffnen (Layer 1/2/3 + MCP). Auswählen, was aktualisiert wird. |
| `/council`         | Plan an Gemini + ChatGPT für unabhängiges Review schicken.                     |
| `/learn`           | Aktuelle Entscheidung als scoped Rule für künftige Sessions speichern.         |
| `/audit`           | Eine von 7 framework-aware Audits ausführen (Security, Performance, etc.).    |
| `/debug`           | 4-Phasen-Debugger: Root-Cause → Pattern → Hypothesis → Fix.                    |
| `/setup-guide`     | Lokale HTML-Setup-Anleitung für installierte MCPs/Komponenten neu erzeugen.    |

Vollständige Befehlsliste: [docs/features.md](../features.md).

## Architektur

Toolkit v6.2 ist eine **dünne Overlay-Schicht**, in drei Layer organisiert:

- **Layer 1** — Toolkit-Inhalt (Templates, Slash-Commands, Komponenten, Skills, Agenten)
- **Layer 2** — kostenlose Basis-Plugins (Superpowers, Get Shit Done, ru-text)
- **Layer 3** — optionale externe Tools (cc-safety-net, RTK, Serena, claude-context, better-model)

Vollständiges Diagramm: [docs/architecture.md](../architecture.md).
Für Solo-Gründer / Nicht-Entwickler: [docs/non-programmer-mode.md](../non-programmer-mode.md).

## MCP-Server-Katalog

Das Flag `--integrations` (oder `/integrations` nach der ersten Installation) öffnet eine TUI-Checkliste mit 24 Servern in 10 Kategorien. Du wählst nur, was dein Projekt braucht.

| Kategorie              | Server                                                                                 |
|------------------------|----------------------------------------------------------------------------------------|
| **docs-research**      | `context7` · `firecrawl` · `notebooklm`                                                |
| **backend**            | `aws-cloudwatch-logs` · `aws-cost-explorer` · `cloudflare` · `dbhub` · `supabase`      |
| **payments**           | `stripe`                                                                               |
| **email**              | `resend` · `mailgun`                                                                   |
| **workspace**          | `calendly` · `notion`                                                                  |
| **project-management** | `jira` · `linear` · `youtrack`                                                         |
| **communication**      | `slack` · `telegram`                                                                   |
| **design**             | `figma`                                                                                |
| **dev-tools**          | `magic` · `openrouter` · `serena` · `claude-context` · `playwright`                    |
| **monitoring**         | `sentry` · `datadog` · `posthog`                                                       |

Jeder Server wird mit per-Row-Scope-Auswahl installiert (`[U]` user / `[P]` project / `[L]` local). Project-Scope schreibt Credentials in `<project>/.env` (Modus 0600) mit Auto-`.gitignore`; `.mcp.json` enthält nur die `${VAR}`-Substitutionsform. Mehr: [docs/INTEGRATIONS.md](../INTEGRATIONS.md).

## Lizenz

MIT — siehe [LICENSE](../../LICENSE).
