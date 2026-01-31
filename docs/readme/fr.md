# Claude Toolkit

Instructions completes pour le developpement assiste par IA avec Claude Code.

[![Quality Check](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](../../README.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **Français** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

> Lisez d'abord le [guide d'installation etape par etape](../howto/fr.md).

---

## A qui s'adresse ce guide

**Developpeurs solo** qui creent des produits avec [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Stacks supportes : **Laravel/PHP**, **Ruby on Rails**, **Next.js**, **Node.js**, **Python**, **Go**.

**7 templates** (basic, Laravel, Rails, Next.js, Node.js, Python, Go)

**24 commandes slash** | **7 audits** | **23+ guides** | Voir la [liste complete des commandes, templates, audits et composants](../features.md#slash-commands-24-total).

---

## Demarrage rapide

### 1. Installation

Le script detecte automatiquement le framework et copie le template approprie.

Executez simplement dans le terminal dans le dossier du projet :

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

**Redemarrez Claude !** Pour les mises a jour futures, utilisez la commande `/update-toolkit` pour la reinstallation ou les mises a jour.

### 2. Security Pack

Inclut une configuration de securite en profondeur. Voir [components/security-hardening.md](../../components/security-hardening.md) pour le guide complet.

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/setup-security.sh | bash
```

### 3. Rate Limit Statusline (Claude Max / Pro)

Affiche les limites de session/hebdomadaires dans la barre d'etat de Claude Code. Plus d'infos : [components/rate-limit-statusline.md](../../components/rate-limit-statusline.md)

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/install-statusline.sh | bash
```

---

## Fonctionnalites phares

| Fonctionnalite | Description |
|----------------|-------------|
| **Self-Learning** | `/learn` sauvegarde les solutions ponctuelles ; Skill Accumulation capture automatiquement les patterns recurrents |
| **Auto-Activation Hooks** | Le hook intercepte les prompts, evalue le contexte (mots-cles, intention, chemins de fichiers) et recommande les competences pertinentes |
| **Memory Persistence** | Exporte la memoire MCP vers `.claude/memory/`, commit dans git — disponible sur n'importe quelle machine |
| **Systematic Debugging** | `/debug` impose 4 phases : cause racine, pattern, hypothese, correction. Pas de devinettes |
| **Structured Workflow** | 3 phases obligatoires : RECHERCHE (lecture seule), PLAN (scratchpad), EXECUTION (apres confirmation) |

Voir les [descriptions detaillees et exemples](../features.md).

---

## Serveurs MCP (recommandes !)

| Serveur | Objectif |
|---------|----------|
| `context7` | Documentation des bibliotheques |
| `playwright` | Automatisation navigateur, tests UI |
| `memory-bank` | Memoire entre sessions |
| `sequential-thinking` | Resolution de problemes etape par etape |
| `memory` | Knowledge Graph (graphe de relations) |

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add playwright -- npx @playwright/mcp@latest
claude mcp add memory-bank -- npx -y @allpepper/memory-bank-mcp@latest
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
claude mcp add memory -- npx -y @modelcontextprotocol/server-memory
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
    └── memory/                # Export memoire MCP
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
