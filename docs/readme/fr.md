# Claude Code Toolkit

Instructions completes pour le developpement assiste par IA avec Claude Code.

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](../../README.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **Français** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

> Lisez d'abord le [guide d'installation etape par etape](../howto/fr.md).

---

## A qui s'adresse ce guide

**Developpeurs solo** qui creent des produits avec [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Stacks supportes : **Laravel/PHP**, **Ruby on Rails**, **Next.js**, **Node.js**, **Python**, **Go**.

**7 templates** (basic, Laravel, Rails, Next.js, Node.js, Python, Go)

**29 commandes slash** | **7 audits** | **30 guides** | Voir la [liste complete des commandes, templates, audits et composants](../features.md#slash-commands-29-total).

---

## Demarrage rapide

### 1. Configuration Globale (une seule fois)

#### a) Security Pack

Configuration de securite en profondeur. Voir [components/security-hardening.md](../../components/security-hardening.md) pour le guide complet.

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)
```

#### b) RTK — Optimiseur de Tokens (recommande)

[RTK](https://github.com/rtk-ai/rtk) reduit la consommation de tokens de 60-90% sur les commandes de developpement (`git status`, `cargo test`, etc.).

```bash
brew install rtk
rtk init -g
```

> **Note :** Le Security Pack (etape 1a) configure deja un hook combine qui execute safety-net et RTK sequentiellement.
> Voir [components/security-hardening.md](../../components/security-hardening.md) pour les details.

#### c) Rate Limit Statusline (Claude Max / Pro, optionnel)

Affiche les limites de session/hebdomadaires dans la barre d'etat. Plus d'infos : [components/rate-limit-statusline.md](../../components/rate-limit-statusline.md)

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-statusline.sh)
```

### 2. Installation (par projet)

L'installateur :

- Vous demande de **choisir votre stack** (detection automatique recommandee)
- Installe le toolkit (commandes, agents, prompts, skills)
- Configure **Supreme Council** (revue multi-IA avec Gemini + ChatGPT)
- Vous guide dans la configuration des cles API

Executez dans votre terminal habituel (pas dans Claude Code) dans le dossier du projet :

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
```

**Lancez Claude Code !** Pour les mises a jour futures, utilisez la commande `/update-toolkit`.

---

## Fonctionnalites phares

| Fonctionnalite | Description |
|----------------|-------------|
| **Self-Learning** | `/learn` sauvegarde les solutions ponctuelles ; Skill Accumulation capture automatiquement les patterns recurrents |
| **Auto-Activation Hooks** | Le hook intercepte les prompts, evalue le contexte (mots-cles, intention, chemins de fichiers) et recommande les competences pertinentes |
| **Persistance des Connaissances** | Faits du projet dans `.claude/rules/` — chargement automatique a chaque session, commit dans git, disponible sur n'importe quelle machine |
| **Systematic Debugging** | `/debug` impose 4 phases : cause racine, pattern, hypothese, correction. Pas de devinettes |
| **Production Safety** | `/deploy` avec verifications pre/post, `/fix-prod` pour les hotfixes, deploiements incrementaux |
| **Supreme Council** | `/council` envoie les plans a Gemini + ChatGPT pour une revue independante avant le codage |
| **Structured Workflow** | 3 phases obligatoires : RECHERCHE (lecture seule), PLAN (scratchpad), EXECUTION (apres confirmation) |

Voir les [descriptions detaillees et exemples](../features.md).

---

## Serveurs MCP (recommandes !)

| Serveur | Objectif |
|---------|----------|
| `context7` | Documentation des bibliotheques |
| `playwright` | Automatisation navigateur, tests UI |
| `sequential-thinking` | Resolution de problemes etape par etape |

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add playwright -- npx @playwright/mcp@latest
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
```

---

## Structure apres installation

```text
your-project/
└── .claude/
    ├── CLAUDE.md              # Instructions principales (a adapter pour votre projet)
    ├── settings.json          # Hooks, permissions
    ├── commands/              # Commandes slash
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
    ├── agents/                # Sous-agents
    │   ├── code-reviewer.md
    │   ├── test-writer.md
    │   └── planner.md
    ├── skills/                # Expertise framework
    │   └── [framework]/SKILL.md
    ├── scratchpad/            # Notes de travail
    └── rules/                 # Donnees du projet (chargement auto)
```

---

## Frameworks supportes

| Framework | Template | Skills | Detection automatique |
|-----------|----------|--------|----------------------|
| Laravel | ✅ | ✅ | Fichier `artisan` |
| Ruby on Rails | ✅ | ✅ | `bin/rails` / `config/application.rb` |
| Next.js | ✅ | ✅ | `next.config.*` |
| Node.js | ✅ | ✅ | `package.json` (sans next.config) |
| Python | ✅ | ✅ | `pyproject.toml` / `requirements.txt` |
| Go | ✅ | ✅ | `go.mod` |
