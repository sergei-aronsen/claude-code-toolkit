# Claude Guides

Umfassende Anleitungen fuer KI-gestuetzte Entwicklung mit Claude Code.

[![Quality Check](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](README.md)** | **[Русский](README.ru.md)** | **[Español](README.es.md)** | **Deutsch** | **[Français](README.fr.md)** | **[中文](README.zh.md)** | **[日本語](README.ja.md)** | **[Português](README.pt.md)** | **[한국어](README.ko.md)**

> **Neu bei Claude Code?** Lies zuerst die [Schritt-fuer-Schritt Installationsanleitung](howto/de.md).

---

## Fuer wen ist das

**Solo-Entwickler**, die Produkte mit [Claude Code](https://docs.anthropic.com/en/docs/claude-code) erstellen.

Unterstuetzte Stacks: **Laravel/PHP**, **Next.js**, **Node.js**, **Python**, **Go**, **Ruby on Rails**.

Ohne ein Team gibt es kein Code-Review, niemanden, den man zur Architektur fragen kann, niemanden, der die Sicherheit prueft. Dieses Repository fuellt diese Luecken:

| Problem | Loesung |
|---------|---------|
| Claude vergisst jedes Mal die Regeln | `CLAUDE.md` — Anweisungen, die zu Beginn der Sitzung gelesen werden |
| Niemanden zum Fragen | `/debug` — systematisches Debugging statt Raten |
| Kein Code-Review | `/audit code` — Claude prueft gegen eine Checkliste |
| Kein Sicherheits-Review | `/audit security` — SQL-Injection, XSS, CSRF, Authentifizierung |
| Vergisst vor dem Deploy zu pruefen | `/verify` — Build, Typen, Lint, Tests in einem Befehl |

**Was drin ist:** 24 Befehle, 7 Audits, 23+ Anleitungen, Templates fuer alle wichtigen Stacks.

---

## Schnellstart

### Erste Installation

Sag Claude Code:

```text
Download instructions from https://github.com/digitalplanetno/claude-code-toolkit
```

Oder fuehre im Terminal aus:

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

Das Skript erkennt automatisch das Framework (Laravel, Next.js) und kopiert das entsprechende Template.

### Nach der Installation

Verwende den `/install` Befehl fuer Neuinstallation oder Updates:

```text
/install          # Framework automatisch erkennen
/install laravel  # Laravel erzwingen
/install nextjs   # Next.js erzwingen
/install nodejs   # Node.js erzwingen
/install python   # Python erzwingen
/install go       # Go erzwingen
/install rails    # Ruby on Rails erzwingen
```

Oder via Terminal:

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/update-claude.sh | bash
```

---

## Killer-Features

### 1. Selbstlernendes System

Claude lernt aus deinen Korrekturen und sammelt Projektwissen an.

**Zwei Mechanismen:**

| Mechanismus | Was es macht | Wann verwenden |
|-------------|--------------|----------------|
| `/learn` | Speichert **einmalige** Problemloesung | Nicht-triviales Problem geloest, Workaround gefunden |
| **Skill-Akkumulation** | Sammelt **wiederkehrende** Muster | Claude wurde 2+ Mal korrigiert |

**Der Unterschied:**

```text
/learn  → "Wie ich Problem X geloest habe"    (einmaliger Fix)
skill   → "Wie wir Y immer machen"            (Projektmuster)
```

**Beispiel /learn:**

```text
> /learn

Analysiere Sitzung...
Gefunden: Prisma Serverless Connection Fix

Problem: Connection Timeout in Vercel Edge Functions
Loesung: ?connection_limit=1 zur DATABASE_URL hinzufuegen

In .claude/learned/prisma-serverless.md speichern? → ja
```

**Beispiel Skill-Akkumulation:**

```text
Benutzer: erstelle Endpunkt fuer Benutzer
Claude: [erstellt Endpunkt]
Benutzer: nein, wir verwenden Zod fuer Validierung und AppError fuer Fehler

Claude: Muster erkannt: Endpunkte verwenden Zod + AppError
        Als Skill 'backend-endpoints' speichern?
        Wird aktiviert bei: endpoint, api, route

Benutzer: ja

[Naechstes Mal verwendet Claude direkt Zod + AppError]
```

### 2. Auto-Aktivierungs-Hooks

**Problem:** Du hast 10 Skills, vergisst aber sie zu verwenden.

**Loesung:** Hook faengt den Prompt **BEVOR** er an Claude gesendet wird ab und empfiehlt das Laden eines Skills.

```text
Benutzer-Prompt → Hook analysiert → Bewertung → Empfehlung
```

**Bewertungssystem:**

| Trigger | Punkte | Beispiel |
|---------|--------|----------|
| keyword | +2 | "endpoint" im Prompt |
| intentPattern | +4 | "create.*endpoint" |
| pathPattern | +5 | Datei `src/api/*` ist geoeffnet |

**Beispiel:**

```text
Prompt: "erstelle POST Endpunkt fuer Registrierung"
Datei: src/api/auth.controller.ts

SKILL-EMPFEHLUNGEN:
[HOCH] backend-dev (Punktzahl: 13)
[HOCH] security-review (Punktzahl: 12)

Verwende Skill-Tool zum Laden der Richtlinien.
```

### 3. Memory-Persistenz

**Problem:** MCP-Memory wird lokal gespeichert. Wechsel zu einem anderen Computer — Memory verloren.

**Loesung:** Export nach `.claude/memory/` → Git-Commit → ueberall verfuegbar.

```text
.claude/memory/
├── knowledge-graph.json   # Komponentenbeziehungen
├── project-context.md     # Projektkontext
└── decisions-log.md       # Warum wir Entscheidung X getroffen haben
```

**Arbeitsablauf:**

```text
Bei Sitzungsstart:     Sync pruefen → Memory von MCP laden
Nach Aenderungen:      Export → .claude/memory/ committen
Auf neuem Computer:    Pull → In MCP importieren
```

### 4. Systematisches Debugging (/debug)

**Eiserne Regel:**

```text
KEINE FIXES OHNE VORHERIGE URSACHENANALYSE
```

**4 Phasen:**

| Phase | Was tun | Abschlusskriterium |
|-------|---------|-------------------|
| **1. Ursache** | Fehler lesen, reproduzieren, Datenfluss verfolgen | Verstanden WAS und WARUM |
| **2. Muster** | Funktionierendes Beispiel finden, vergleichen | Unterschiede gefunden |
| **3. Hypothese** | Theorie formulieren, EINE Aenderung testen | Bestaetigt |
| **4. Fix** | Test schreiben, fixen, verifizieren | Tests gruen |

**Drei-Fixes-Regel:**

```text
Wenn 3+ Fixes nicht funktioniert haben — STOPP!
Das ist kein Bug. Das ist ein Architekturproblem.
```

### 5. Strukturierter Arbeitsablauf

**Problem:** Claude "codet oft sofort" anstatt die Aufgabe zu verstehen.

**Loesung:** 3 Phasen mit expliziten Einschraenkungen:

| Phase | Zugriff | Was erlaubt ist |
|-------|---------|-----------------|
| **RECHERCHE** | Nur-Lesen | Glob, Grep, Read — Kontext verstehen |
| **PLAN** | Nur-Scratchpad | Plan in `.claude/scratchpad/` schreiben |
| **AUSFUEHRUNG** | Voll | Nur nach Plan-Bestaetigung |

```text
Benutzer: Fuege E-Mail-Validierung hinzu

Claude: Phase 1: RECHERCHE
        [Liest Dateien, sucht Muster]
        Gefunden: Formular in RegisterForm.tsx, Validierung via Zod

        Phase 2: PLAN
        [Erstellt Plan in .claude/scratchpad/current-task.md]
        Plan fertig. Bestaetigen zum Fortfahren.

Benutzer: ok

Claude: Phase 3: AUSFUEHRUNG
        Schritt 1: Schema hinzufuegen...
        Schritt 2: In Formular integrieren...
        Schritt 3: Tests...
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

## Was drin ist

### Templates (7 Optionen)

| Template | Wofuer | Features |
|----------|--------|----------|
| `base/` | Jedes Projekt | Universelle Regeln |
| `laravel/` | Laravel + Vue/Inertia | Eloquent, Migrationen, Blade, Pint |
| `nextjs/` | Next.js + TypeScript | App Router, RSC, Tailwind |
| `nodejs/` | Node.js + TypeScript | Express, APIs, Backend-Services |
| `python/` | Python + FastAPI | Type Hints, Pydantic, asyncio |
| `go/` | Go + Standard Library | Modules, Interfaces, Concurrency |
| `rails/` | Ruby on Rails + Hotwire | ActiveRecord, Turbo, Stimulus, RSpec |

### Slash-Befehle (24 insgesamt)

| Befehl | Beschreibung |
|--------|--------------|
| `/verify` | Pre-Commit-Pruefung: Build, Typen, Lint, Tests |
| `/debug [problem]` | 4-Phasen-Debugging: Ursache → Hypothese → Fix → Verifizieren |
| `/learn` | Problemloesung in `.claude/learned/` speichern |
| `/plan` | Plan im Scratchpad vor der Implementierung erstellen |
| `/audit [type]` | Audit ausfuehren (security, performance, code, design, database) |
| `/test` | Tests fuer Modul schreiben |
| `/refactor` | Refactoring unter Beibehaltung des Verhaltens |
| `/fix [issue]` | Spezifisches Problem beheben |
| `/explain` | Erklaeren, wie der Code funktioniert |
| `/doc` | Dokumentation generieren |
| `/context-prime` | Projektkontext bei Sitzungsstart laden |
| `/checkpoint` | Fortschritt im Scratchpad speichern |
| `/handoff` | Aufgabenuebergabe vorbereiten (Zusammenfassung + naechste Schritte) |
| `/worktree` | Git-Worktrees-Verwaltung |
| `/install` | claude-guides ins Projekt installieren |
| `/migrate` | Datenbank-Migrations-Unterstuetzung |
| `/find-function` | Funktion nach Name/Beschreibung finden |
| `/find-script` | Skript in package.json/composer.json finden |
| `/tdd` | Test-Driven-Development-Arbeitsablauf |
| `/docker` | Docker-Container-Verwaltung und Debugging |
| `/api` | API-Endpunkt erstellen und dokumentieren |
| `/e2e` | End-to-End-Tests schreiben und ausfuehren |
| `/perf` | Performance-Analyse und Optimierung |
| `/deps` | Abhaengigkeiten pruefen und aktualisieren |

### Audits (7 Typen)

| Audit | Datei | Was es prueft |
|-------|-------|---------------|
| **Security** | `SECURITY_AUDIT.md` | SQL-Injection, XSS, CSRF, Auth, Geheimnisse |
| **Performance** | `PERFORMANCE_AUDIT.md` | N+1, Bundle-Groesse, Caching, Lazy Loading |
| **Code-Review** | `CODE_REVIEW.md` | Muster, Lesbarkeit, SOLID, DRY |
| **Design-Review** | `DESIGN_REVIEW.md` | UI/UX, Barrierefreiheit, Responsive (Playwright MCP) |
| **MySQL** | `MYSQL_PERFORMANCE_AUDIT.md` | performance_schema, Indizes, langsame Abfragen |
| **PostgreSQL** | `POSTGRES_PERFORMANCE_AUDIT.md` | pg_stat_statements, Bloat, Verbindungen |
| **Deploy** | `DEPLOY_CHECKLIST.md` | Pre-Deploy-Checkliste |

### Komponenten (23+ Anleitungen)

| Komponente | Beschreibung |
|------------|--------------|
| `structured-workflow.md` | 3-Phasen-Ansatz: Recherche → Plan → Ausfuehrung |
| `smoke-tests-guide.md` | Minimale API-Tests (Laravel/Next.js/Node.js) |
| `hooks-auto-activation.md` | Auto-Aktivierung von Skills nach Prompt-Kontext |
| `skill-accumulation.md` | Selbstlernen: Claude sammelt Projektwissen |
| `modular-skills.md` | Progressive Offenlegung fuer grosse Richtlinien |
| `spec-driven-development.md` | Spezifikationen vor dem Code |
| `mcp-servers-guide.md` | Empfohlene MCP-Server |
| `memory-persistence.md` | MCP-Memory-Sync mit Git |
| `plan-mode-instructions.md` | Think-Level: think → think hard → ultrathink |
| `git-worktrees-guide.md` | Paralleles Arbeiten an Branches |
| `devops-highload-checklist.md` | Checkliste fuer Hochlast-Projekte |
| `api-health-monitoring.md` | API-Endpunkt-Monitoring |
| `bootstrap-workflow.md` | Arbeitsablauf fuer neue Projekte |
| `github-actions-guide.md` | CI/CD mit GitHub Actions |
| `pre-commit-hooks.md` | Pre-Commit-Hooks-Konfiguration |
| `deployment-strategies.md` | Deployment-Strategien und Best Practices |

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
```

---

## Anwendungsbeispiele

### /verify — Pre-Commit-Pruefung

```text
> /verify

Fuehre Pruefungen aus...
Build: bestanden
TypeScript: keine Fehler
ESLint: 2 Warnungen (unbenutzte Imports)
Tests: 23 bestanden

Empfehlung: Lint-Warnungen vor dem Commit beheben.
```

### /debug — systematisches Debugging

```text
> /debug API gibt 500 bei /api/users zurueck

Phase 1: URSACHENANALYSE
├── Lese app/api/users/route.ts
├── Pruefe Logs
└── Gefunden: prisma.user.findMany() ohne try/catch

Phase 2: HYPOTHESE
└── Datenbank-Verbindungs-Timeout bei Kaltstart

Phase 3: FIX
└── Fuege Fehlerbehandlung + Retry-Logik hinzu

Phase 4: VERIFIZIEREN
└── Teste Endpunkt — funktioniert
```

### /audit security — Sicherheitsaudit

```text
> /audit security

SICHERHEITSAUDIT-BERICHT
========================

KRITISCH (1)
├── SQL-Injection in UserController:45
└── Empfehlung: Prepared Statements verwenden

MITTEL (2)
├── Kein Rate-Limiting auf /api/login
└── CORS konfiguriert als Access-Control-Allow-Origin: *

NIEDRIG (1)
└── Debug-Modus in .env.example
```

---

## Unterstuetzte Frameworks

| Framework | Template | Skills | Auto-Erkennung |
|-----------|----------|--------|----------------|
| Laravel | Dediziert | Ja | `artisan` Datei |
| Next.js | Dediziert | Ja | `next.config.*` |
| Node.js | Dediziert | Ja | `package.json` (ohne next.config) |
| Python | Dediziert | Ja | `pyproject.toml` / `requirements.txt` |
| Go | Dediziert | Ja | `go.mod` |
| Ruby on Rails | Dediziert | Ja | `bin/rails` / `config/application.rb` |
