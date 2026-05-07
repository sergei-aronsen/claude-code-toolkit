# Claude Code Toolkit

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-6.3.0-blue.svg)](../../CHANGELOG.md)

**[English](../../README.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **Français** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

---

## Qu'est-ce que c'est

Une couche fine au-dessus de [**Superpowers**](https://github.com/obra/superpowers) (brainstorming, sub-agents, TDD, debug) et [**Get Shit Done**](https://github.com/gsd-build/get-shit-done) (Spec → Plan → Execute), qui comble les manques que ces plugins laissent pour les développeurs solos.

**Pour :** founders solos et équipes engineering d'une seule personne qui livrent de vrais produits avec [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

**Stacks supportés :** Laravel · Rails · Next.js · Node.js · Python · Go.

## Manques comblés

| Manque                                | Ce que le toolkit ajoute                                                                                                                          |
|---------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| **Validation multi-IA des plans**     | `/council` — envoie ton plan à Gemini et ChatGPT en parallèle pour review indépendante. Marche via CLI (`gemini`, `codex`) ou clés API directes. Persona overlays, cache par hash, cost gate, locale ru. |
| **Contexte par framework**            | 7 templates `CLAUDE.md` prêts (base + 6 stacks), auto-détectés via `artisan` / `next.config` / `go.mod` / `pyproject.toml` / `package.json`.     |
| **Filet de sécurité production**      | `cc-safety-net` bloque les commandes destructives (`rm -rf /`, `git reset --hard`, etc.) au PreToolUse — même obfusquées. Câblé dans l'installeur. |
| **Contrôle du coût en tokens**        | RTK réécrit la sortie verbeuse des commandes dev (`git status`, test runners) — économie de 60-90 % de tokens. Hook combiné avec `cc-safety-net`. |
| **Cost routing**                      | `better-model` route les tâches simples vers les modèles moins chers. Auto-installé et intégré dans le cycle de vie de l'install.                |
| **Recherche de code par symbole**     | [Serena](https://github.com/oraios/serena) (LSP, MIT, local) + ripgrep + claude-context (vecteur sémantique). Stack Layer-3 par défaut.          |
| **Multi-CLI bridges**                 | Auto-sync de `CLAUDE.md` vers `GEMINI.md` (Gemini CLI) et `AGENTS.md` (OpenAI Codex). Détection de drift à chaque install.                       |
| **Catalogue d'intégrations**          | Installeur TUI pour 24 serveurs MCP + 8 CLIs compagnons en 10 catégories (Backend / Payments / Workspace / Project Management / …). Scope par ligne. |
| **Visibilité des limites (Pro/Max)**  | La statusline affiche l'usage session/hebdo — tu vois quand tu vas taper le mur.                                                                  |
| **Dashboard de dépendances (v6.2)**   | `/update-deps` — TUI interactif listant chaque dépendance suivie (Layer 1/2/3) avec installed-vs-latest. Tu choisis quoi mettre à jour.          |
| **Guide post-install (v6.3)**         | Génère une page HTML locale (`.claude/setup-guide.html`) avec walkthrough par MCP (clé API) et par composant — uniquement pour ce qui est installé. |

La valeur centrale est la curation. Tout est opt-in via cases TUI — rien n'est forcé.

## Installation

Une commande. À lancer dans un terminal normal **dans** le dossier du projet (pas dans Claude Code) :

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

L'installeur affiche une checklist TUI (Toolkit, Security, RTK, Statusline, Council, Bridges, Integrations) et détecte si `superpowers` et `get-shit-done` sont déjà installés. Si oui, il saute les fichiers que ces plugins fournissent déjà et n'installe que les ~47 contributions uniques du toolkit.

Pour les utilisateurs de Claude Desktop — install via marketplace :

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

Guide pas-à-pas complet : [docs/howto/fr.md](../howto/fr.md).

## Après l'installation

| Commande           | Ce qu'elle fait                                                                |
|--------------------|--------------------------------------------------------------------------------|
| `/update-toolkit`  | Récupérer le contenu frais du toolkit dans `.claude/` en préservant tes éditions. |
| `/update-deps`     | Ouvrir le dashboard de dépendances (Layer 1/2/3 + MCP). Choisir quoi mettre à jour. |
| `/council`         | Envoyer un plan à Gemini + ChatGPT pour review indépendante.                   |
| `/learn`           | Sauvegarder la décision actuelle comme rule scoped pour les futures sessions. |
| `/audit`           | Lancer un des 7 audits framework-aware (security, performance, etc.).         |
| `/debug`           | Debugger systématique en 4 phases : root-cause → pattern → hypothesis → fix.   |
| `/setup-guide`     | Régénérer le guide HTML local de configuration pour les MCP/composants.        |

Liste complète des commandes : [docs/features.md](../features.md).

## Architecture

Le toolkit v6.2 est une **couche fine** organisée en trois layers :

- **Layer 1** — contenu du toolkit (templates, slash commands, composants, skills, agents)
- **Layer 2** — plugins de base gratuits (Superpowers, Get Shit Done, ru-text)
- **Layer 3** — outils externes optionnels (cc-safety-net, RTK, Serena, claude-context, better-model)

Diagramme complet : [docs/architecture.md](../architecture.md).
Pour les founders solos / non-développeurs : [docs/non-programmer-mode.md](../non-programmer-mode.md).

## Catalogue de serveurs MCP

Le flag `--integrations` (ou `/integrations` après la première install) ouvre une checklist TUI avec 24 serveurs en 10 catégories. Tu prends seulement ce dont ton projet a besoin.

| Catégorie              | Serveurs                                                                               |
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

Chaque serveur s'installe avec un choix de scope par ligne (`[U]` user / `[P]` project / `[L]` local). Le scope project écrit les credentials dans `<project>/.env` (mode 0600) avec auto-`.gitignore` ; `.mcp.json` ne porte que la forme `${VAR}`. Plus de détails : [docs/INTEGRATIONS.md](../INTEGRATIONS.md).

## Licence

MIT — voir [LICENSE](../../LICENSE).
