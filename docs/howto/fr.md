# Installation et utilisation de Claude Code Toolkit

> Le parcours complet, de zéro au développement productif avec Claude Code, en un seul endroit.

**[English](en.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **Français** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

---

## Prérequis

Assure-toi d'avoir :

- **Node.js** — `node --version` (20.x ou plus récent recommandé)
- **Claude Code** — `claude --version`
- **git** — pour committer `.claude/` dans ton repo
- **jq** — requis par l'installeur pour merger `settings.json` (`brew install jq` / `apt install jq`)

Si Claude Code n'est pas encore installé :

```bash
npm install -g @anthropic-ai/claude-code
```

---

## Installation

`cd` dans le dossier du projet dans un **terminal normal** (pas dans Claude Code) et lance :

```bash
cd ~/Projects/my-app
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

L'installeur ouvre une checklist TUI avec tous les composants :

```text
[x] toolkit              ← contenu du toolkit (.claude/ dans le projet)
[x] security             ← security pack global + cc-safety-net
[ ] rtk                  ← réécrire la sortie verbeuse des commandes dev (-60-90% tokens)
[ ] statusline           ← usage session/hebdo dans la barre d'état
[ ] council              ← /council = validation de plans avec Gemini + ChatGPT
[ ] gemini-bridge        ← auto-sync CLAUDE.md → GEMINI.md
[ ] codex-bridge         ← auto-sync CLAUDE.md → AGENTS.md
[ ] mcp-servers (24)     ← checklist TUI pour les intégrations (Stripe, Sentry, dbhub, …)
[ ] skills (22)          ← skills marketplace (i18n, shadcn, stripe, …)
```

`Espace` pour basculer, `↑/↓` pour bouger, `Entrée` pour installer ce qui est coché.

L'installeur détecte ton framework (Laravel, Next.js, Python, Go, …) via les fichiers signature et livre le template `CLAUDE.md` adapté. Si `superpowers` et `get-shit-done` sont déjà installés, le toolkit saute les fichiers que ces plugins fournissent déjà et n'installe que les ~47 contributions uniques.

À la fin, une page HTML locale s'ouvre à `.claude/setup-guide.html` avec les instructions pas-à-pas pour chaque MCP installé (où chercher la clé API, quelle env var positionner, comment tester).

---

## Commit et lancement

```bash
git add .claude/ CLAUDE.md
git commit -m "chore: add Claude Code toolkit configuration"
claude
```

Claude Code démarre et charge automatiquement :

1. Le `~/.claude/CLAUDE.md` global (security rules — installées par le script)
2. Le `CLAUDE.md` projet (adapté à ton stack — tu peux étendre avec des détails project-specific)
3. Chaque commande de `.claude/commands/` et chaque skill du marketplace

---

## Commandes utiles

| Commande           | Ce qu'elle fait                                                                |
|--------------------|--------------------------------------------------------------------------------|
| `/update-toolkit`  | Récupérer le contenu frais du toolkit en préservant tes éditions de `CLAUDE.md`. |
| `/update-deps`     | Dashboard de dépendances (Layer 1/2/3 + MCP). Choisir quoi mettre à jour.      |
| `/council plan`    | Envoyer un plan à Gemini + ChatGPT pour review indépendante.                   |
| `/learn`           | Sauvegarder la décision actuelle comme rule scoped pour les futures sessions.  |
| `/audit security`  | Un des 7 audits framework-aware.                                              |
| `/debug problème`  | Debugger systématique en 4 phases.                                            |
| `/setup-guide`     | Régénérer le guide HTML local de configuration.                                |
| `/helpme`          | Cheatsheet complet des commandes.                                              |

---

## Schéma visuel

```text
┌────────────────────────────────────────────────────────┐
│  INSTALLATION (une fois par projet)                    │
│                                                        │
│  $ cd ~/Projects/my-app                                │
│  $ bash <(curl -sSL …/install.sh)                      │
│  → checklist TUI → Espace/Entrée                       │
│                                                        │
│  Résultat :                                            │
│   ~/.claude/CLAUDE.md       ← security rules           │
│   .claude/                  ← commandes, skills, agents│
│   CLAUDE.md                 ← template adapté au stack │
│   .claude/setup-guide.html  ← guide d'API des MCPs     │
└────────────────────────────────────────────────────────┘
                       │
                       ▼
┌────────────────────────────────────────────────────────┐
│  TRAVAIL QUOTIDIEN                                     │
│                                                        │
│  $ claude                                              │
│  > /plan ajouter l'authentification                    │
│  > /debug 500 sur /api/users                           │
│  > /audit security                                     │
│  > /council mon plan de migration de BDD               │
└────────────────────────────────────────────────────────┘
```

---

## Mise à jour

```bash
cd ~/Projects/my-app
# Dans Claude Code :
> /update-toolkit   # contenu du toolkit
> /update-deps      # toutes les dépendances (TUI avec cases)
```

`/update-deps` montre la liste TUI complète avec installed-vs-latest. Tu choisis quoi bumper, le reste reste tel quel.

---

## Claude Desktop

Les utilisateurs Desktop installent via marketplace :

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

Tu obtiens trois sous-plugins : `tk-skills` (22 skills), `tk-commands` (29 commandes), `tk-framework-rules` (7 fragments de CLAUDE.md). Détails : [docs/CLAUDE_DESKTOP.md](../CLAUDE_DESKTOP.md).

---

## Résolution de problèmes

| Problème                                            | Solution                                                                                  |
|-----------------------------------------------------|-------------------------------------------------------------------------------------------|
| `cc-safety-net: command not found` après install    | `npm install -g cc-safety-net`, puis `bash <(curl …/scripts/install-hooks.sh)`            |
| RTK ne réécrit pas les commandes                    | `~/.claude/settings.json` doit avoir **un seul** hook combiné, pas deux séparés           |
| Claude ne voit pas les commandes du projet          | Relance `claude` depuis le même dossier où se trouve `.claude/`                           |
| safety-net bloque une commande dont tu as besoin    | Lance-la à la main dans un terminal normal (ou temporairement `TK_NO_SAFETY=1`)           |
| L'installeur reste bloqué dans le TUI               | `Ctrl-C`, relance ; sur macOS `bash` 3.2 ↑/↓ peuvent nécessiter `--no-tui-fallback`       |
| `setup-guide.html` ne s'ouvre pas                   | `open .claude/setup-guide.html` (macOS) / `xdg-open` (Linux). Ou lance `/setup-guide`.    |
