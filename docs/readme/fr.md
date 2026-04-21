# Claude Code Toolkit

Instructions complètes pour le développement assisté par IA avec Claude Code.

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](../../README.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **Français** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

> Lisez d'abord le [guide d'installation pas à pas](../howto/fr.md) complet.

---

## Pour qui est-ce

**Solo-développeurs** qui créent des produits avec [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Stacks compatibles : **Laravel/PHP**, **Ruby on Rails**, **Next.js**, **Node.js**, **Python**, **Go**.

**30 commandes slash** | **7 audits** | **29 guides** | Voir la [liste complète des commandes, modèles, audits et composants](../features.md#slash-commands-30-total).

---

## Démarrage rapide

### 1. Configuration globale (une fois)

#### a) Security Pack

Configuration de sécurité en profondeur. Voir [components/security-hardening.md](../../components/security-hardening.md) pour le guide complet.

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)
```

#### b) RTK — Optimiseur de tokens (recommandé)

[RTK](https://github.com/rtk-ai/rtk) réduit la consommation de tokens de 60-90 % sur les commandes de développement (`git status`, `cargo test`, etc.).

```bash
brew install rtk
rtk init -g
```

> **Remarque :** Si RTK et cc-safety-net sont des hooks séparés, leurs résultats entrent en conflit.
> Le Security Pack (étape 1a) configure déjà un hook combiné qui exécute les deux séquentiellement.
> Voir [components/security-hardening.md](../../components/security-hardening.md) pour les détails.

#### c) Rate Limit Statusline (Claude Max / Pro, optionnel)

Affiche les limites de session/semaine dans la barre d'état de Claude Code. Plus d'infos : [components/rate-limit-statusline.md](../../components/rate-limit-statusline.md)

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-statusline.sh)
```

## Modes d'installation

TK détecte automatiquement si `superpowers` (obra) et `get-shit-done` (gsd-build) sont installés et
choisit l'un des quatre modes : `standalone`, `complement-sp`, `complement-gsd` ou `complement-full`.
Chaque modèle de framework documente ses plugins de base requis dans `## Required Base Plugins` — voir,
par exemple, [templates/base/CLAUDE.md](../../templates/base/CLAUDE.md). Pour la matrice d'installation
complète de 12 cellules et le guide étape par étape, consultez [docs/INSTALL.md](../INSTALL.md).

### Installation autonome

Vous n'avez pas `superpowers` ni `get-shit-done` installés (ou vous avez choisi de ne pas les utiliser).
TK installe les 54 fichiers complets — l'option par défaut complète. Exécutez dans votre terminal
habituel (pas dans Claude Code !) dans le dossier du projet :

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
```

Démarrez ensuite Claude Code dans ce répertoire. Pour les mises à jour futures, utilisez `/update-toolkit`.

### Installation complémentaire

Vous avez l'un ou les deux de `superpowers` (obra) et `get-shit-done` (gsd-build) installés. TK
les détecte automatiquement et ignore les 7 fichiers qui doubleraient la fonctionnalité de SP, en conservant les
~47 contributions uniques de TK (Council, modèles CLAUDE.md par framework, bibliothèque de composants,
cheatsheets, skills par framework). Utilisez la même commande d'installation — TK sélectionne automatiquement le
mode `complement-*`. Pour le remplacer, passez `--mode standalone` (ou un autre nom de mode) :

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh) --mode complement-full
```

### Mise à jour depuis v3.x

Les utilisateurs de v3.x qui ont installé SP ou GSD après TK doivent exécuter `scripts/migrate-to-complement.sh` pour
supprimer les fichiers dupliqués avec confirmation par fichier et une sauvegarde complète avant la migration. Voir
[docs/INSTALL.md](../INSTALL.md) pour la matrice complète de 12 cellules et le guide étape par étape.

> **Important :** Le modèle de projet est uniquement pour `project/.claude/CLAUDE.md`. Ne le copiez pas dans
> `~/.claude/CLAUDE.md` — ce fichier ne doit contenir que des règles de sécurité globales et des préférences
> personnelles (moins de 50 lignes). Voir [components/claude-md-guide.md](../../components/claude-md-guide.md)
> pour les détails.

---

## Fonctionnalités clés

| Fonctionnalité | Description |
|----------------|-------------|
| **Self-Learning** | `/learn` sauvegarde les solutions sous forme de fichiers de règles avec `globs:` — chargés automatiquement uniquement pour les fichiers pertinents |
| **Auto-Activation Hooks** | Hook intercepte les prompts, évalue le contexte (mots-clés, intention, chemins de fichiers), recommande les skills pertinents |
| **Knowledge Persistence** | Faits du projet dans `.claude/rules/` — chargés automatiquement à chaque session, dans git, disponibles sur n'importe quelle machine |
| **Systematic Debugging** | `/debug` applique 4 phases : cause racine → schéma → hypothèse → solution. Sans suppositions |
| **Production Safety** | `/deploy` avec vérifications pré/post, `/fix-prod` pour les hotfixes, déploiements incrémentiels, sécurité des workers |
| **Supreme Council** | `/council` envoie les plans à Gemini + ChatGPT pour une revue indépendante avant de coder |
| **Structured Workflow** | 3 phases obligatoires : RESEARCH (lecture seule) → PLAN (brouillon) → EXECUTE (après confirmation) |

Voir les [descriptions détaillées et exemples](../features.md).

---

## Serveurs MCP (recommandé !)

### Global (tous les projets)

| Serveur | Objectif |
|---------|----------|
| `context7` | Documentation des bibliothèques |
| `playwright` | Automatisation navigateur, tests UI |
| `sequential-thinking` | Résolution de problèmes étape par étape |
| `sentry` | Surveillance des erreurs et investigation des incidents |

```bash
claude mcp add -s user context7 -- npx -y @upstash/context7-mcp
claude mcp add -s user playwright -- npx @playwright/mcp@latest --browser chromium
claude mcp add -s user sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp
```

### Par projet (identifiants)

| Serveur | Objectif |
|---------|----------|
| `dbhub` | Accès universel aux bases de données (PostgreSQL, MySQL, MariaDB, SQL Server, SQLite) |

```bash
claude mcp add dbhub -- npx -y @bytebase/dbhub --dsn "postgresql://user:pass@localhost:5432/dbname"
```

> **Sécurité :** Utilisez toujours un **utilisateur de base de données en lecture seule** — ne vous fiez pas uniquement au flag `--readonly` de DBHub ([contournements connus](https://github.com/bytebase/dbhub/issues/271)). Les serveurs par projet vont dans `.claude/settings.local.json` (dans .gitignore, sécurisé pour les identifiants). Voir [mcp-servers-guide.md](../../components/mcp-servers-guide.md) pour tous les détails.

---

## Structure après l'installation

Les fichiers marqués d'un † entrent en conflit avec `superpowers` — omis dans les modes `complement-sp` et `complement-full`.

```text
your-project/
└── .claude/
    ├── CLAUDE.md              # Instructions principales (adaptez pour votre projet)
    ├── settings.json          # Hooks, permissions
    ├── commands/              # Commandes slash
    │   ├── verify.md          # † omis dans complement-sp/full
    │   ├── debug.md           # † omis dans complement-sp/full
    │   └── ...
    ├── prompts/               # Audits
    │   ├── SECURITY_AUDIT.md
    │   ├── PERFORMANCE_AUDIT.md
    │   ├── CODE_REVIEW.md
    │   ├── DESIGN_REVIEW.md
    │   ├── MYSQL_PERFORMANCE_AUDIT.md
    │   └── POSTGRES_PERFORMANCE_AUDIT.md
    ├── agents/                # Sous-agents
    │   ├── code-reviewer.md   # † omis dans complement-sp/full
    │   ├── test-writer.md
    │   └── planner.md
    ├── skills/                # Expertise frameworks
    │   └── [framework]/SKILL.md
    ├── rules/                 # Faits du projet chargés automatiquement
    └── scratchpad/            # Notes de travail
```

---

## Frameworks pris en charge

| Framework | Modèle | Skills | Détection automatique |
|-----------|--------|--------|-----------------------|
| Laravel | ✅ | ✅ | Fichier `artisan` |
| Ruby on Rails | ✅ | ✅ | `bin/rails` / `config/application.rb` |
| Next.js | ✅ | ✅ | `next.config.*` |
| Node.js | ✅ | ✅ | `package.json` (sans next.config) |
| Python | ✅ | ✅ | `pyproject.toml` / `requirements.txt` |
| Go | ✅ | ✅ | `go.mod` |

---

## Composants

Sections Markdown réutilisables pour composer des fichiers `CLAUDE.md` personnalisés. Les composants sont des
actifs à la racine du dépôt — ils ne sont **pas** installés dans `.claude/` ; référencez-les par URL GitHub absolue.

**Schéma d'orchestration** — voir [components/orchestration-pattern.md](../../components/orchestration-pattern.md)
pour la conception orchestrateur léger + sous-agents robustes qu'utilisent Council et les workflows GSD.
Aide toute commande slash personnalisée à passer à l'échelle au-delà d'une seule fenêtre de contexte.
