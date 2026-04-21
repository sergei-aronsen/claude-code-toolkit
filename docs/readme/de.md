# Claude Code Toolkit

Umfassende Anleitungen für KI-gestützte Entwicklung mit Claude Code.

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](../../README.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **Deutsch** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

> Lesen Sie zuerst die vollständige [Schritt-für-Schritt-Installationsanleitung](../howto/de.md).

---

## Für wen ist das

**Solo-Entwickler**, die Produkte mit [Claude Code](https://docs.anthropic.com/en/docs/claude-code) erstellen.

Unterstützte Stacks: **Laravel/PHP**, **Ruby on Rails**, **Next.js**, **Node.js**, **Python**, **Go**.

**30 Slash-Befehle** | **7 Audits** | **29 Anleitungen** | Siehe [vollständige Liste der Befehle, Templates, Audits und Komponenten](../features.md#slash-commands-30-total).

---

## Schnellstart

### 1. Globale Einrichtung (einmalig)

#### a) Security Pack

Defense-in-Depth-Sicherheits-Setup. Siehe [components/security-hardening.md](../../components/security-hardening.md) für die vollständige Anleitung.

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)
```

#### b) RTK — Token-Optimierer (empfohlen)

[RTK](https://github.com/rtk-ai/rtk) reduziert den Token-Verbrauch um 60–90 % bei Entwicklungsbefehlen (`git status`, `cargo test` usw.).

```bash
brew install rtk
rtk init -g
```

> **Hinweis:** Wenn RTK und cc-safety-net separate Hooks sind, entstehen Konflikte.
> Das Security Pack (Schritt 1a) konfiguriert bereits einen kombinierten Hook, der beide sequenziell ausführt.
> Siehe [components/security-hardening.md](../../components/security-hardening.md) für Details.

#### c) Rate Limit Statusline (Claude Max / Pro, optional)

Zeigt Sitzungs-/Wochenlimits in der Statusleiste von Claude Code an. Mehr: [components/rate-limit-statusline.md](../../components/rate-limit-statusline.md)

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-statusline.sh)
```

## Installationsmodi

TK erkennt automatisch, ob `superpowers` (obra) und `get-shit-done` (gsd-build) installiert sind, und
wählt einen von vier Modi: `standalone`, `complement-sp`, `complement-gsd` oder `complement-full`.
Jedes Framework-Template dokumentiert seine erforderlichen Basis-Plugins unter `## Required Base Plugins` — siehe
z. B. [templates/base/CLAUDE.md](../../templates/base/CLAUDE.md). Die vollständige 12-Zellen-Installationsmatrix
und die Schritt-für-Schritt-Anleitung finden Sie unter [docs/INSTALL.md](../INSTALL.md).

### Eigenständige Installation

Sie haben weder `superpowers` noch `get-shit-done` installiert (oder haben sich dagegen entschieden).
TK installiert alle 54 Dateien — die vollständige Standardoption. Führen Sie den Befehl im normalen
Terminal (nicht in Claude Code!) im Projektordner aus:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
```

Starten Sie anschließend Claude Code in diesem Verzeichnis. Für zukünftige Updates verwenden Sie `/update-toolkit`.

### Komplement-Installation

Sie haben einen oder beide — `superpowers` (obra) und `get-shit-done` (gsd-build) — installiert. TK
erkennt diese automatisch und überspringt die 7 Dateien, die SP-Funktionalität duplizieren würden, und behält
die ~47 einzigartigen TK-Beiträge (Council, Framework-CLAUDE.md-Templates, Komponentenbibliothek,
Cheatsheets, Framework-Skills). Verwenden Sie denselben Installationsbefehl — TK wählt den `complement-*`-Modus
automatisch. Zum Überschreiben übergeben Sie `--mode standalone` (oder einen anderen Modusnamen):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh) --mode complement-full
```

### Upgrade von v3.x

v3.x-Benutzer, die SP oder GSD nach TK installiert haben, sollten `scripts/migrate-to-complement.sh` ausführen, um
duplizierte Dateien mit Bestätigung pro Datei und vollständigem Backup vor der Migration zu entfernen. Siehe
[docs/INSTALL.md](../INSTALL.md) für die vollständige Matrix und die Schritt-für-Schritt-Anleitung.

> **Wichtig:** Das Projekttemplate ist nur für `project/.claude/CLAUDE.md`. Kopieren Sie es nicht nach
> `~/.claude/CLAUDE.md` — diese Datei sollte nur globale Sicherheitsregeln und persönliche Einstellungen
> enthalten (unter 50 Zeilen). Siehe [components/claude-md-guide.md](../../components/claude-md-guide.md).

---

## Killer-Features

| Feature | Beschreibung |
|---------|--------------|
| **Self-Learning** | `/learn` speichert Lösungen als Regeldateien mit `globs:` — automatisch nur für relevante Dateien geladen |
| **Auto-Activation Hooks** | Hook fängt Prompts ab, bewertet Kontext (Keywords, Intent, Dateipfade), empfiehlt relevante Skills |
| **Knowledge Persistence** | Projektfakten in `.claude/rules/` — automatisch bei jeder Sitzung geladen, in Git, auf jedem Rechner verfügbar |
| **Systematic Debugging** | `/debug` erzwingt 4 Phasen: Ursache → Muster → Hypothese → Fix. Kein Raten |
| **Production Safety** | `/deploy` mit Pre-/Post-Checks, `/fix-prod` für Hotfixes, inkrementelle Deployments, Worker-Sicherheit |
| **Supreme Council** | `/council` sendet Pläne an Gemini + ChatGPT für unabhängige Prüfung vor dem Coding |
| **Structured Workflow** | 3 Pflichtphasen: RESEARCH (nur lesen) → PLAN (Entwurf) → EXECUTE (nach Bestätigung) |

Siehe [detaillierte Beschreibungen und Beispiele](../features.md).

---

## MCP-Server (empfohlen!)

### Global (alle Projekte)

| Server | Zweck |
|--------|-------|
| `context7` | Bibliotheks-Dokumentation |
| `playwright` | Browser-Automatisierung, UI-Tests |
| `sequential-thinking` | Schrittweise Problemlösung |
| `sentry` | Fehlerüberwachung und Vorfallsanalyse |

```bash
claude mcp add -s user context7 -- npx -y @upstash/context7-mcp
claude mcp add -s user playwright -- npx @playwright/mcp@latest --browser chromium
claude mcp add -s user sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp
```

### Pro Projekt (Zugangsdaten)

| Server | Zweck |
|--------|-------|
| `dbhub` | Universeller Datenbankzugriff (PostgreSQL, MySQL, MariaDB, SQL Server, SQLite) |

```bash
claude mcp add dbhub -- npx -y @bytebase/dbhub --dsn "postgresql://user:pass@localhost:5432/dbname"
```

> **Sicherheit:** Verwenden Sie immer einen **schreibgeschützten Datenbankbenutzer** — verlassen Sie sich nicht allein auf das `--readonly`-Flag von DBHub ([bekannte Umgehungen](https://github.com/bytebase/dbhub/issues/271)). Pro-Projekt-Server kommen in `.claude/settings.local.json` (in .gitignore, sicher für Zugangsdaten). Siehe [mcp-servers-guide.md](../../components/mcp-servers-guide.md).

---

## Struktur nach der Installation

Mit † markierte Dateien kollidieren mit `superpowers` — in den Modi `complement-sp` und `complement-full` weggelassen.

```text
dein-projekt/
└── .claude/
    ├── CLAUDE.md              # Hauptanweisungen (passen Sie sie für Ihr Projekt an)
    ├── settings.json          # Hooks, Berechtigungen
    ├── commands/              # Slash-Befehle
    │   ├── verify.md          # † ausgelassen in complement-sp/full
    │   ├── debug.md           # † ausgelassen in complement-sp/full
    │   └── ...
    ├── prompts/               # Audits
    │   ├── SECURITY_AUDIT.md
    │   ├── PERFORMANCE_AUDIT.md
    │   ├── CODE_REVIEW.md
    │   ├── DESIGN_REVIEW.md
    │   ├── MYSQL_PERFORMANCE_AUDIT.md
    │   └── POSTGRES_PERFORMANCE_AUDIT.md
    ├── agents/                # Subagenten
    │   ├── code-reviewer.md   # † ausgelassen in complement-sp/full
    │   ├── test-writer.md
    │   └── planner.md
    ├── skills/                # Framework-Expertise
    │   └── [framework]/SKILL.md
    ├── rules/                 # Automatisch geladene Projektfakten
    └── scratchpad/            # Arbeitsnotizen
```

---

## Unterstützte Frameworks

| Framework | Template | Skills | Auto-Erkennung |
|-----------|----------|--------|----------------|
| Laravel | ✅ | ✅ | `artisan`-Datei |
| Ruby on Rails | ✅ | ✅ | `bin/rails` / `config/application.rb` |
| Next.js | ✅ | ✅ | `next.config.*` |
| Node.js | ✅ | ✅ | `package.json` (ohne next.config) |
| Python | ✅ | ✅ | `pyproject.toml` / `requirements.txt` |
| Go | ✅ | ✅ | `go.mod` |

---

## Komponenten

Wiederverwendbare Markdown-Abschnitte zum Erstellen benutzerdefinierter `CLAUDE.md`-Dateien. Komponenten sind
Repository-Root-Assets — sie werden **nicht** in `.claude/` installiert; verweisen Sie per absoluter GitHub-URL.

**Orchestrierungsmuster** — siehe [components/orchestration-pattern.md](../../components/orchestration-pattern.md)
für das Design mit schlankem Orchestrator und leistungsfähigen Subagenten, das Council und GSD-Workflows nutzen.
Hilft jedem benutzerdefinierten Slash-Befehl, über ein einzelnes Kontextfenster hinaus zu skalieren.
