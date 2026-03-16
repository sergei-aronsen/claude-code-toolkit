# Erste Schritte mit dem Claude Code Toolkit

> Komplette Einsteiger-Anleitung: von Null zur produktiven Entwicklung mit Claude Code

**[English](en.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **Deutsch** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

---

## Voraussetzungen

Stelle sicher, dass Folgendes installiert ist:

- **Node.js** (pruefen: `node --version`)
- **Claude Code** (pruefen: `claude --version`)

Falls Claude Code noch nicht installiert ist:

```bash
npm install -g @anthropic-ai/claude-code
```

---

## Zwei Ebenen der Einrichtung

| Ebene | Was | Wann |
|-------|-----|------|
| **Global** | Sicherheitsregeln + Hooks + Plugins | Einmal pro Rechner |
| **Pro Projekt** | Befehle, Skills, Vorlagen | Einmal pro Projekt |

---

## Schritt 1: Globale Einrichtung (einmal pro Rechner)

Hierbei werden Sicherheitsregeln, der kombinierte Hook (safety-net + RTK-Unterstuetzung) und die offiziellen Anthropic-Plugins installiert. Wird **einmal** ausgefuehrt, funktioniert fuer **alle** Projekte.

Oeffne dein normales Terminal (nicht Claude Code):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)
```

**Was passiert:**

- `~/.claude/CLAUDE.md` wird erstellt — globale Sicherheitsregeln. Claude Code liest diese Datei **bei jedem Start in jedem Projekt**. Es ist eine Anweisung wie "mache niemals SQL-Injection, verwende kein eval(), frage vor gefaehrlichen Operationen"
- `cc-safety-net` wird installiert — blockiert destruktive Befehle (`rm -rf /`, `git push --force`, usw.)
- Ein kombinierter Hook wird konfiguriert (safety-net + RTK sequenziell, keine parallelen Konflikte)
- Offizielle Anthropic-Plugins werden aktiviert (code-review, commit-commands, security-guidance, frontend-design)

**Ueberpruefen, ob alles funktioniert:**

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/verify-install.sh)
```

Das war's. Der globale Teil ist erledigt. Du musst **das nie wiederholen**.

---

## Schritt 2: Dein Projekt erstellen

Zum Beispiel ein Laravel-Projekt:

```bash
cd ~/Projects
composer create-project laravel/laravel my-app
cd my-app
git init
```

Oder Next.js:

```bash
cd ~/Projects
npx create-next-app@latest my-app
cd my-app
```

Oder wenn du bereits ein Projekt hast — navigiere einfach in dessen Ordner:

```bash
cd ~/Projects/my-app
```

---

## Schritt 3: Toolkit im Projekt installieren

Fuehre **im Projektordner** folgenden Befehl aus:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
```

Das Skript **erkennt automatisch** dein Framework (Laravel, Next.js, Python, Go, usw.) und erstellt:

```text
my-app/
└── .claude/
    ├── CLAUDE.md              ← Anweisungen fuer Claude (FUER DEIN PROJEKT)
    ├── settings.json          ← Einstellungen, Hooks
    ├── commands/              ← 24 Slash-Befehle
    │   ├── debug.md           ← /debug — systematisches Debugging
    │   ├── plan.md            ← /plan — Planung vor dem Coden
    │   ├── verify.md          ← /verify — Pre-Commit-Pruefung
    │   ├── audit.md           ← /audit — Sicherheits-/Performance-Audit
    │   ├── test.md            ← /test — Tests schreiben
    │   └── ...                ← ~19 weitere Befehle
    ├── prompts/               ← Audit-Vorlagen
    ├── agents/                ← Sub-Agents (code-reviewer, test-writer)
    ├── skills/                ← Framework-Expertise
    ├── cheatsheets/           ← Spickzettel (9 Sprachen)
    ├── memory/                ← Gedaechtnis zwischen Sitzungen
    └── scratchpad/            ← Arbeitsnotizen
```

**Um das Framework explizit anzugeben:**

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh) laravel
```

---

## Schritt 4: CLAUDE.md fuer dein Projekt konfigurieren

Dies ist die wichtigste Datei. Oeffne `.claude/CLAUDE.md` in deinem Editor und fuelle sie aus:

```markdown
# My App — Claude Code Instructions

## Project Overview
**Framework:** Laravel 12
**Description:** Online electronics store

## Key Directories
app/Services/    — business logic
app/Models/      — Eloquent models
resources/js/    — Vue components

## Development Workflow
### Running Locally
composer serve    — start server
npm run dev       — frontend

### Testing
php artisan test

## Project-Specific Rules
1. All controllers use Form Requests
2. Money is stored in cents (integer)
3. API returns JSON via Resources
```

Claude **liest diese Datei bei jedem Start** in diesem Projekt. Je besser du sie ausfuellst — desto intelligenter wird Claude arbeiten.

---

## Schritt 5: .claude in Git committen

```bash
git add .claude/
git commit -m "feat: add Claude Code toolkit configuration"
```

Jetzt ist die Konfiguration im Repository gespeichert. Wenn du das Projekt auf einem anderen Rechner klonst — ist das Toolkit bereits vorhanden.

---

## Schritt 6: Claude Code starten und arbeiten

```bash
claude
```

Claude Code startet und laedt automatisch:

1. **Globale** `~/.claude/CLAUDE.md` (Sicherheitsregeln — aus Schritt 1)
2. **Projekt** `.claude/CLAUDE.md` (deine Anweisungen — aus Schritt 4)
3. Alle Befehle aus `.claude/commands/`

Jetzt kannst du arbeiten:

```text
> Create a REST API for product management: CRUD, pagination, search
```

---

## Nuetzliche Befehle in Claude Code

| Befehl | Was er macht |
|--------|--------------|
| `/plan` | Erst denken, dann coden (Recherche → Plan → Umsetzung) |
| `/debug problem` | Systematisches Debugging in 4 Phasen |
| `/audit security` | Sicherheits-Audit |
| `/audit` | Code-Review |
| `/verify` | Pre-Commit-Pruefung (Build + Lint + Tests) |
| `/test` | Tests schreiben |
| `/learn` | Problemloesung fuer spaetere Referenz speichern |
| `/helpme` | Spickzettel aller Befehle |

---

## Visuelle Uebersicht — Der komplette Weg

```text
┌─────────────────────────────────────────────────────┐
│  EINMAL PRO RECHNER (Schritt 1)                     │
│                                                     │
│  Terminal:                                          │
│  $ bash <(curl ... setup-security.sh)                │
│                                                     │
│  Ergebnis:                                          │
│  ~/.claude/CLAUDE.md      ← Sicherheitsregeln       │
│  ~/.claude/settings.json  ← kombinierter Hook + Plugins │
│  ~/.claude/hooks/pre-bash.sh ← safety-net + RTK      │
│  cc-safety-net            ← npm-Paket                │
└─────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  FUER JEDES PROJEKT (Schritte 2-5)                  │
│                                                     │
│  Terminal:                                          │
│  $ cd ~/Projects/my-app                             │
│  $ bash <(curl ... init-claude.sh)                   │
│  $ # .claude/CLAUDE.md bearbeiten                   │
│  $ git add .claude/ && git commit                   │
│                                                     │
│  Ergebnis:                                          │
│  .claude/                 ← Befehle, Skills,        │
│                              Prompts, Agents        │
└─────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  ARBEITEN (Schritt 6)                               │
│                                                     │
│  $ claude                                           │
│  > /plan add authentication                         │
│  > /debug why 500 on /api/users                     │
│  > /verify                                          │
│  > /audit security                                  │
└─────────────────────────────────────────────────────┘
```

---

## Toolkit aktualisieren

Wenn neue Befehle oder Vorlagen veroeffentlicht werden:

```bash
cd ~/Projects/my-app
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/update-claude.sh)
```

Oder innerhalb von Claude Code:

```text
> /install
```

---

## Fehlerbehebung

| Problem | Loesung |
|---------|---------|
| `cc-safety-net: command not found` | Fuehre `npm install -g cc-safety-net` aus |
| Toolkit wird von Claude nicht erkannt | Pruefe, ob `.claude/CLAUDE.md` im Projektstammverzeichnis existiert |
| Befehle nicht verfuegbar | Fuehre `init-claude.sh` erneut aus oder pruefe den Ordner `.claude/commands/` |
| Safety-net blockiert einen legitimen Befehl | Fuehre den Befehl manuell im Terminal ausserhalb von Claude Code aus |
| RTK schreibt Befehle nicht um | Stelle sicher, dass ein einziger kombinierter Hook in settings.json vorhanden ist, keine separaten Hooks |
