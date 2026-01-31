# Claude Guides

Instructions completes pour le developpement assiste par IA avec Claude Code.

[![Quality Check](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](README.md)** | **[Русский](README.ru.md)** | **[Español](README.es.md)** | **[Deutsch](README.de.md)** | **Français** | **[中文](README.zh.md)** | **[日本語](README.ja.md)** | **[Português](README.pt.md)** | **[한국어](README.ko.md)**

> **Nouveau sur Claude Code ?** Lisez d'abord le [guide d'installation etape par etape](howto/fr.md).

---

## A qui s'adresse ce guide

**Developpeurs solo** qui creent des produits avec [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Stacks supportes : **Laravel/PHP**, **Next.js**, **Node.js**, **Python**, **Go**, **Ruby on Rails**.

Sans equipe, vous n'avez pas de revue de code, personne a qui demander conseil sur l'architecture, personne pour verifier la securite. Ce depot comble ces lacunes :

| Probleme | Solution |
|----------|----------|
| Claude oublie les regles a chaque fois | `CLAUDE.md` — instructions qu'il lit au debut de la session |
| Personne a qui demander | `/debug` — debogage systematique au lieu de deviner |
| Pas de revue de code | `/audit code` — Claude verifie selon une checklist |
| Pas d'audit de securite | `/audit security` — injection SQL, XSS, CSRF, authentification |
| Oubli de verifier avant le deploiement | `/verify` — build, types, lint, tests en une commande |

**Contenu :** 24 commandes, 7 audits, 23+ guides, templates pour tous les stacks principaux.

---

## Demarrage rapide

### Premiere installation

Dites a Claude Code :

```text
Install claude-code-toolkit from https://github.com/digitalplanetno/claude-code-toolkit
```

Ou executez dans le terminal :

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

Le script detecte automatiquement le framework (Laravel, Next.js) et copie le template approprie.

### Apres l'installation

Utilisez la commande `/install` pour la reinstallation ou les mises a jour :

```text
/install          # detection automatique du framework
/install laravel  # forcer Laravel
/install nextjs   # forcer Next.js
/install nodejs   # forcer Node.js
/install python   # forcer Python
/install go       # forcer Go
/install rails    # forcer Ruby on Rails
```

Ou via le terminal :

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/update-claude.sh | bash
```

---

## Fonctionnalites principales

### 1. Systeme d'auto-apprentissage

Claude apprend de vos corrections et accumule les connaissances du projet.

**Deux mecanismes :**

| Mecanisme | Ce qu'il fait | Quand l'utiliser |
|-----------|---------------|------------------|
| `/learn` | Sauvegarde une solution **ponctuelle** | Probleme non trivial resolu, contournement trouve |
| **Accumulation de competences** | Accumule les patterns **recurrents** | Claude a ete corrige 2+ fois |

**La difference :**

```text
/learn  → "Comment j'ai resolu le probleme X"     (correction ponctuelle)
skill   → "Comment on fait toujours Y"            (pattern du projet)
```

**Exemple /learn :**

```text
> /learn

Analyse de la session...
Trouve : Correction de connexion Prisma Serverless

Probleme : Timeout de connexion dans Vercel Edge Functions
Solution : Ajouter ?connection_limit=1 a DATABASE_URL

Sauvegarder dans .claude/learned/prisma-serverless.md? → oui
```

**Exemple d'accumulation de competences :**

```text
Utilisateur : cree un endpoint pour les utilisateurs
Claude : [cree l'endpoint]
Utilisateur : non, on utilise Zod pour la validation et AppError pour les erreurs

Claude : Pattern detecte : les endpoints utilisent Zod + AppError
        Sauvegarder comme competence 'backend-endpoints'?
        S'activera sur : endpoint, api, route

Utilisateur : oui

[La prochaine fois, Claude utilise Zod + AppError directement]
```

### 2. Hooks d'auto-activation

**Probleme :** Vous avez 10 competences, mais oubliez de les utiliser.

**Solution :** Le hook intercepte le prompt **AVANT** l'envoi a Claude et recommande le chargement d'une competence.

```text
Prompt utilisateur → Analyse du hook → Scoring → Recommandation
```

**Systeme de scoring :**

| Declencheur | Points | Exemple |
|-------------|--------|---------|
| mot-cle | +2 | "endpoint" dans le prompt |
| intentPattern | +4 | "create.*endpoint" |
| pathPattern | +5 | Fichier `src/api/*` ouvert |

**Exemple :**

```text
Prompt : "cree un endpoint POST pour l'inscription"
Fichier : src/api/auth.controller.ts

RECOMMANDATIONS DE COMPETENCES :
[ELEVE] backend-dev (score: 13)
[ELEVE] security-review (score: 12)

Utilisez l'outil Skill pour charger les directives.
```

### 3. Persistance de la memoire

**Probleme :** La memoire MCP est stockee localement. Changement d'ordinateur — memoire perdue.

**Solution :** Export vers `.claude/memory/` → commit dans git → disponible partout.

```text
.claude/memory/
├── knowledge-graph.json   # Relations entre composants
├── project-context.md     # Contexte du projet
└── decisions-log.md       # Pourquoi on a pris la decision X
```

**Workflow :**

```text
Au debut de session :     Verifier la synchro → Charger la memoire depuis MCP
Apres modifications :     Exporter → Commit .claude/memory/
Sur nouvel ordinateur :   Pull → Importer vers MCP
```

### 4. Debogage systematique (/debug)

**Regle d'or :**

```text
AUCUNE CORRECTION SANS INVESTIGATION DE LA CAUSE RACINE D'ABORD
```

**4 phases :**

| Phase | Que faire | Critere de sortie |
|-------|-----------|-------------------|
| **1. Cause racine** | Lire les erreurs, reproduire, tracer le flux de donnees | Comprendre QUOI et POURQUOI |
| **2. Pattern** | Trouver un exemple fonctionnel, comparer | Differences trouvees |
| **3. Hypothese** | Formuler une theorie, tester UN changement | Confirmee |
| **4. Correction** | Ecrire le test, corriger, verifier | Tests verts |

**Regle des trois corrections :**

```text
Si 3+ corrections n'ont pas fonctionne — STOP !
Ce n'est pas un bug. C'est un probleme architectural.
```

### 5. Workflow structure

**Probleme :** Claude "code tout de suite" au lieu de comprendre la tache.

**Solution :** 3 phases avec restrictions explicites :

| Phase | Acces | Ce qui est autorise |
|-------|-------|---------------------|
| **RECHERCHE** | Lecture seule | Glob, Grep, Read — comprendre le contexte |
| **PLAN** | Scratchpad uniquement | Ecrire le plan dans `.claude/scratchpad/` |
| **EXECUTION** | Complet | Seulement apres confirmation du plan |

```text
Utilisateur : Ajoute la validation email

Claude : Phase 1 : RECHERCHE
        [Lit les fichiers, recherche les patterns]
        Trouve : formulaire dans RegisterForm.tsx, validation via Zod

        Phase 2 : PLAN
        [Cree le plan dans .claude/scratchpad/current-task.md]
        Plan pret. Confirmez pour continuer.

Utilisateur : ok

Claude : Phase 3 : EXECUTION
        Etape 1 : Ajout du schema... OK
        Etape 2 : Integration dans le formulaire... OK
        Etape 3 : Tests... OK
```

---

## Structure apres installation

```text
votre-projet/
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

## Contenu

### Templates (7 options)

| Template | Pour quoi | Caracteristiques |
|----------|-----------|------------------|
| `base/` | Tout projet | Regles universelles |
| `laravel/` | Laravel + Vue/Inertia | Eloquent, migrations, Blade, Pint |
| `nextjs/` | Next.js + TypeScript | App Router, RSC, Tailwind |
| `nodejs/` | Node.js + Express/Fastify | API REST, middleware, validation |
| `python/` | Python + FastAPI/Django | Pydantic, async, typing |
| `go/` | Go + Gin/Echo | Structs, interfaces, goroutines |
| `rails/` | Ruby on Rails + Hotwire | ActiveRecord, Turbo, Stimulus, RSpec |

### Commandes slash (24 au total)

| Commande | Description |
|----------|-------------|
| `/verify` | Verification pre-commit : build, types, lint, tests |
| `/debug [probleme]` | Debogage en 4 phases : cause racine → hypothese → correction → verification |
| `/learn` | Sauvegarder la solution dans `.claude/learned/` |
| `/plan` | Creer un plan dans le scratchpad avant implementation |
| `/audit [type]` | Lancer un audit (security, performance, code, design, database) |
| `/test` | Ecrire des tests pour un module |
| `/refactor` | Refactoring en preservant le comportement |
| `/fix [issue]` | Corriger un probleme specifique |
| `/explain` | Expliquer comment le code fonctionne |
| `/doc` | Generer la documentation |
| `/context-prime` | Charger le contexte du projet au debut de session |
| `/checkpoint` | Sauvegarder la progression dans le scratchpad |
| `/handoff` | Preparer le transfert de tache (resume + prochaines etapes) |
| `/worktree` | Gestion des git worktrees |
| `/install` | Installer claude-guides dans le projet |
| `/migrate` | Assistance pour les migrations de base de donnees |
| `/find-function` | Trouver une fonction par nom/description |
| `/find-script` | Trouver un script dans package.json/composer.json |
| `/tdd` | Workflow de developpement dirige par les tests |
| `/docker` | Gestion des conteneurs Docker et docker-compose |
| `/api` | Conception et documentation des endpoints API |
| `/e2e` | Tests end-to-end avec Playwright/Cypress |
| `/perf` | Analyse et optimisation des performances |
| `/deps` | Gestion et mise a jour des dependances |

### Audits (7 types)

| Audit | Fichier | Ce qu'il verifie |
|-------|---------|------------------|
| **Securite** | `SECURITY_AUDIT.md` | Injection SQL, XSS, CSRF, auth, secrets |
| **Performance** | `PERFORMANCE_AUDIT.md` | N+1, taille du bundle, cache, chargement paresseux |
| **Revue de code** | `CODE_REVIEW.md` | Patterns, lisibilite, SOLID, DRY |
| **Revue design** | `DESIGN_REVIEW.md` | UI/UX, accessibilite, responsive (Playwright MCP) |
| **MySQL** | `MYSQL_PERFORMANCE_AUDIT.md` | performance_schema, index, requetes lentes |
| **PostgreSQL** | `POSTGRES_PERFORMANCE_AUDIT.md` | pg_stat_statements, bloat, connexions |
| **Deploiement** | `DEPLOY_CHECKLIST.md` | Checklist pre-deploiement |

### Composants (23+ guides)

| Composant | Description |
|-----------|-------------|
| `structured-workflow.md` | Approche en 3 phases : Recherche → Plan → Execution |
| `smoke-tests-guide.md` | Tests API minimaux (Laravel/Next.js/Node.js) |
| `hooks-auto-activation.md` | Auto-activation des competences selon le contexte du prompt |
| `skill-accumulation.md` | Auto-apprentissage : Claude accumule les connaissances du projet |
| `modular-skills.md` | Divulgation progressive pour les grands guides |
| `spec-driven-development.md` | Specifications avant le code |
| `mcp-servers-guide.md` | Serveurs MCP recommandes |
| `memory-persistence.md` | Synchronisation memoire MCP avec Git |
| `plan-mode-instructions.md` | Niveaux de reflexion : think → think hard → ultrathink |
| `git-worktrees-guide.md` | Travail parallele sur les branches |
| `devops-highload-checklist.md` | Checklist projets a forte charge |
| `api-health-monitoring.md` | Surveillance des endpoints API |
| `bootstrap-workflow.md` | Workflow nouveau projet |
| `github-actions-guide.md` | Workflows CI/CD avec GitHub Actions |
| `pre-commit-hooks.md` | Configuration des hooks pre-commit |
| `deployment-strategies.md` | Strategies de deploiement (blue-green, canary, rolling) |

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
```

---

## Rate Limit Statusline (Claude Max / Pro)

Surveillez vos limites d'utilisation API directement dans la barre d'etat de Claude Code.

```text
25% | 5h:23% (2h57m) | 7d:80% (1d18h)
 │      │      │          │       │
 │      │      │          │       └─ temps avant reinitialisation hebdomadaire
 │      │      │          └─ utilisation hebdomadaire (fenetre de 7 jours)
 │      │      └─ temps avant reinitialisation de session
 │      └─ utilisation de session (fenetre de 5 heures)
 └─ utilisation de la fenetre de contexte
```

**Couleurs :** sans couleur (<60%), jaune (60-79%), rouge (80-89%), rouge vif (90-100%)

**Prerequis :** macOS, `jq`, Claude Code avec OAuth (abonnement Max ou Pro)

### Installation

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/install-statusline.sh | bash
```

L'installateur verifie les prerequis, telecharge les scripts dans `~/.claude/`, configure `settings.json` et execute un test initial.

Details et personnalisation : [components/rate-limit-statusline.md](components/rate-limit-statusline.md).

---

## Exemples d'utilisation

### /verify — verification pre-commit

```text
> /verify

Execution des verifications...
OK Build : passe
OK TypeScript : aucune erreur
Attention ESLint : 2 avertissements (imports inutilises)
OK Tests : 23 passes

Recommandation : corriger les avertissements lint avant le commit.
```

### /debug — debogage systematique

```text
> /debug L'API retourne 500 sur /api/users

Phase 1 : ANALYSE DE LA CAUSE RACINE
├── Lecture de app/api/users/route.ts
├── Verification des logs
└── Trouve : prisma.user.findMany() sans try/catch

Phase 2 : HYPOTHESE
└── Timeout de connexion base de donnees au demarrage a froid

Phase 3 : CORRECTION
└── Ajout de la gestion d'erreurs + logique de retry

Phase 4 : VERIFICATION
└── Test de l'endpoint — fonctionne
```

### /audit security — audit de securite

```text
> /audit security

RAPPORT D'AUDIT DE SECURITE
===========================

CRITIQUE (1)
├── Injection SQL dans UserController:45
└── Recommandation : utiliser des requetes preparees

MOYEN (2)
├── Pas de rate limiting sur /api/login
└── CORS configure comme Access-Control-Allow-Origin: *

FAIBLE (1)
└── Mode debug dans .env.example
```

---

## Frameworks supportes

| Framework | Template | Competences | Detection automatique |
|-----------|----------|-------------|----------------------|
| Laravel | Dedie | Oui | Fichier `artisan` |
| Next.js | Dedie | Oui | `next.config.*` |
| Node.js | Dedie | Oui | `package.json` (sans next.config) |
| Python | Dedie | Oui | `pyproject.toml` / `requirements.txt` |
| Go | Dedie | Oui | `go.mod` |
| Ruby on Rails | Dedie | Oui | `bin/rails` / `config/application.rb` |
