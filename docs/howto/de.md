# Installation und Nutzung des Claude Code Toolkit

> Der vollständige Weg von Null zu produktiver Entwicklung mit Claude Code an einem Ort.

**[English](en.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **Deutsch** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

---

## Voraussetzungen

Stelle sicher, dass installiert ist:

- **Node.js** — `node --version` (20.x oder neuer empfohlen)
- **Claude Code** — `claude --version`
- **git** — um `.claude/` ins Repo zu committen
- **jq** — vom Installer für `settings.json`-Merge benötigt (`brew install jq` / `apt install jq`)

Falls Claude Code noch nicht installiert ist:

```bash
npm install -g @anthropic-ai/claude-code
```

---

## Installation

`cd` in deinen Projektordner in einem **normalen Terminal** (nicht in Claude Code) und ausführen:

```bash
cd ~/Projects/my-app
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

Der Installer öffnet eine TUI-Checkliste mit allen Komponenten:

```text
[x] toolkit              ← Toolkit-Inhalt (.claude/ im Projekt)
[x] security             ← globaler Security-Pack + cc-safety-net
[ ] rtk                  ← verbose Dev-Befehl-Ausgabe umschreiben (-60-90% Tokens)
[ ] statusline           ← Session/Weekly Usage in der Statusleiste
[ ] council              ← /council = Plan-Validierung mit Gemini + ChatGPT
[ ] gemini-bridge        ← Auto-Sync CLAUDE.md → GEMINI.md
[ ] codex-bridge         ← Auto-Sync CLAUDE.md → AGENTS.md
[ ] mcp-servers (24)     ← TUI-Checkliste für Integrationen (Stripe, Sentry, dbhub, …)
[ ] skills (22)          ← Marketplace-Skills (i18n, shadcn, stripe, …)
```

`Leertaste` zum Umschalten, `↑/↓` zum Bewegen, `Enter` um Markiertes zu installieren.

Der Installer erkennt dein Framework (Laravel, Next.js, Python, Go, …) anhand charakteristischer Dateien und liefert das passende `CLAUDE.md`-Template aus. Wenn `superpowers` und `get-shit-done` bereits installiert sind, überspringt das Toolkit die Dateien, die diese Plugins schon liefern, und installiert nur die ~47 toolkit-eigenen Beiträge.

Am Ende öffnet sich eine lokale HTML-Seite unter `.claude/setup-guide.html` mit Schritt-für-Schritt-Anweisungen für jedes installierte MCP (wo den API-Key holen, welche Env-Var setzen, wie testen).

---

## Committen und arbeiten

```bash
git add .claude/ CLAUDE.md
git commit -m "chore: add Claude Code toolkit configuration"
claude
```

Claude Code startet und lädt automatisch:

1. Das globale `~/.claude/CLAUDE.md` (Security Rules — vom Skript installiert)
2. Das Projekt-`CLAUDE.md` (passend zum Stack — du kannst projektspezifische Details ergänzen)
3. Jeden Befehl aus `.claude/commands/` und jede Skill aus dem Marketplace

---

## Nützliche Befehle

| Befehl             | Funktion                                                                       |
|--------------------|--------------------------------------------------------------------------------|
| `/update-toolkit`  | Frischen Toolkit-Inhalt holen, lokale `CLAUDE.md`-Bearbeitungen erhalten.      |
| `/update-deps`     | Dependency-Dashboard (Layer 1/2/3 + MCP). Wählen, was aktualisiert wird.       |
| `/council plan`    | Plan an Gemini + ChatGPT für unabhängiges Review schicken.                     |
| `/learn`           | Aktuelle Entscheidung als scoped Rule für künftige Sessions speichern.         |
| `/audit security`  | Eine von 7 framework-aware Audits.                                            |
| `/debug problem`   | Systematischer 4-Phasen-Debugger.                                              |
| `/setup-guide`     | Lokale HTML-Setup-Anleitung neu erzeugen.                                      |
| `/helpme`          | Vollständige Befehlsübersicht.                                                 |

---

## Visueller Ablauf

```text
┌────────────────────────────────────────────────────────┐
│  INSTALLATION (einmal pro Projekt)                     │
│                                                        │
│  $ cd ~/Projects/my-app                                │
│  $ bash <(curl -sSL …/install.sh)                      │
│  → TUI-Checkliste → Leertaste/Enter                    │
│                                                        │
│  Ergebnis:                                             │
│   ~/.claude/CLAUDE.md       ← Security Rules           │
│   .claude/                  ← Befehle, Skills, Agenten │
│   CLAUDE.md                 ← Stack-passendes Template │
│   .claude/setup-guide.html  ← MCP-API-Setup-Guide      │
└────────────────────────────────────────────────────────┘
                       │
                       ▼
┌────────────────────────────────────────────────────────┐
│  TÄGLICHE ARBEIT                                       │
│                                                        │
│  $ claude                                              │
│  > /plan Authentifizierung hinzufügen                  │
│  > /debug 500 auf /api/users                           │
│  > /audit security                                     │
│  > /council mein DB-Migrationsplan                     │
└────────────────────────────────────────────────────────┘
```

---

## Aktualisieren

```bash
cd ~/Projects/my-app
# In Claude Code:
> /update-toolkit   # Toolkit-Inhalt
> /update-deps      # alle Abhängigkeiten (TUI mit Checkboxen)
```

`/update-deps` zeigt die volle TUI-Liste mit installed-vs-latest. Du wählst, welche Komponenten aktualisiert werden; alles andere bleibt unangetastet.

---

## Claude Desktop

Desktop-Nutzer installieren per Marketplace:

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

Du bekommst drei Sub-Plugins: `tk-skills` (22 Skills), `tk-commands` (29 Befehle), `tk-framework-rules` (7 CLAUDE.md-Fragmente). Details: [docs/CLAUDE_DESKTOP.md](../CLAUDE_DESKTOP.md).

---

## Fehlerbehebung

| Problem                                              | Lösung                                                                                    |
|------------------------------------------------------|-------------------------------------------------------------------------------------------|
| `cc-safety-net: command not found` nach der Install. | `npm install -g cc-safety-net`, dann `bash <(curl …/scripts/install-hooks.sh)`            |
| RTK schreibt Befehle nicht um                        | `~/.claude/settings.json` muss **einen kombinierten** Hook haben, nicht zwei getrennte    |
| Claude sieht die Projekt-Befehle nicht               | `claude` aus demselben Ordner neu starten, in dem `.claude/` liegt                        |
| safety-net blockiert einen Befehl, den du brauchst   | Manuell im normalen Terminal ausführen (oder kurzzeitig `TK_NO_SAFETY=1`)                 |
| Installer hängt im TUI                               | `Ctrl-C`, neu starten; auf macOS `bash` 3.2 brauchen ↑/↓ ggf. `--no-tui-fallback`         |
| `setup-guide.html` öffnet sich nicht                 | `open .claude/setup-guide.html` (macOS) / `xdg-open` (Linux). Oder `/setup-guide` rufen.  |
