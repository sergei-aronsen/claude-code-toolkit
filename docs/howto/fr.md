# Premiers pas avec Claude Code Toolkit

> Guide complet pour debutants : de zero a un developpement productif avec Claude Code

**[English](en.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **Français** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

---

## Prerequis

Assurez-vous d'avoir installe :

- **Node.js** (verifier : `node --version`)
- **Claude Code** (verifier : `claude --version`)

Si Claude Code n'est pas encore installe :

```bash
npm install -g @anthropic-ai/claude-code
```

---

## Deux niveaux de configuration

| Niveau | Quoi | Quand |
|--------|------|-------|
| **Global** | Regles de securite + hooks + plugins | Une fois par machine |
| **Par projet** | Commandes, competences, modeles | Une fois par projet |

---

## Etape 1 : Configuration globale (une fois par machine)

Cela installe les regles de securite, le hook combine (safety-net + support RTK) et les plugins officiels Anthropic. A faire **une seule fois**, fonctionne pour **tous** les projets.

Ouvrez votre terminal habituel (pas Claude Code) :

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)
```

**Ce qui se passe :**

- `~/.claude/CLAUDE.md` est cree -- regles de securite globales. Claude Code lit ce fichier **a chaque lancement dans n'importe quel projet**. C'est une instruction du type "ne jamais faire d'injection SQL, ne pas utiliser eval(), demander avant les operations dangereuses"
- `cc-safety-net` est installe -- bloque les commandes destructrices (`rm -rf /`, `git push --force`, etc.)
- Un hook combine est configure (safety-net + RTK sequentiel, sans conflits paralleles)
- Les plugins officiels Anthropic sont actives (code-review, commit-commands, security-guidance, frontend-design)

**Verifier que tout fonctionne :**

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/verify-install.sh)
```

C'est tout. La partie globale est terminee. Vous n'avez **plus jamais besoin de repeter cette etape**.

---

## Etape 2 : Creer votre projet

Par exemple, un projet Laravel :

```bash
cd ~/Projects
composer create-project laravel/laravel my-app
cd my-app
git init
```

Ou Next.js :

```bash
cd ~/Projects
npx create-next-app@latest my-app
cd my-app
```

Ou si vous avez deja un projet -- naviguez simplement vers son dossier :

```bash
cd ~/Projects/my-app
```

---

## Etape 3 : Installer le Toolkit dans le projet

**Dans votre terminal habituel** (pas dans Claude Code), depuis le dossier du projet, executez :

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
```

Le script **detecte automatiquement** votre framework (Laravel, Next.js, Python, Go, etc.) et cree :

```text
my-app/
└── .claude/
    ├── CLAUDE.md              ← Instructions pour Claude (POUR VOTRE PROJET)
    ├── settings.json          ← Parametres, hooks
    ├── commands/              ← 24 commandes slash
    │   ├── debug.md           ← /debug — debogage systematique
    │   ├── plan.md            ← /plan — planification avant le codage
    │   ├── verify.md          ← /verify — verification avant commit
    │   ├── audit.md           ← /audit — audit securite/performance
    │   ├── test.md            ← /test — ecriture de tests
    │   └── ...                ← ~19 autres commandes
    ├── prompts/               ← Modeles d'audit
    ├── agents/                ← Sous-agents (code-reviewer, test-writer)
    ├── skills/                ← Expertise framework
    ├── cheatsheets/           ← Aide-memoire (9 langages)
    ├── memory/                ← Memoire entre les sessions
    └── scratchpad/            ← Notes de travail
```

**Pour specifier le framework explicitement :**

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh) laravel
```

---

## Etape 4 : Configurer CLAUDE.md pour votre projet

C'est le fichier le plus important. Ouvrez `.claude/CLAUDE.md` dans votre editeur et remplissez-le :

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

Claude **lit ce fichier a chaque lancement** dans ce projet. Mieux vous le remplissez, plus Claude sera intelligent.

---

## Etape 5 : Commiter .claude dans Git

```bash
git add .claude/
git commit -m "feat: add Claude Code toolkit configuration"
```

Maintenant la configuration est sauvegardee dans le depot. Si vous clonez le projet sur une autre machine, le toolkit sera deja present.

---

## Etape 6 : Lancer Claude Code et travailler

```bash
claude
```

Claude Code demarre et charge automatiquement :

1. **Global** `~/.claude/CLAUDE.md` (regles de securite -- de l'etape 1)
2. **Projet** `.claude/CLAUDE.md` (vos instructions -- de l'etape 4)
3. Toutes les commandes de `.claude/commands/`

Maintenant vous pouvez travailler :

```text
> Create a REST API for product management: CRUD, pagination, search
```

---

## Commandes utiles dans Claude Code

| Commande | Ce qu'elle fait |
|----------|-----------------|
| `/plan` | Reflechir d'abord, coder ensuite (Recherche → Plan → Execution) |
| `/debug probleme` | Debogage systematique en 4 phases |
| `/audit security` | Audit de securite |
| `/audit` | Revue de code |
| `/verify` | Verification avant commit (build + lint + tests) |
| `/test` | Ecrire des tests |
| `/learn` | Sauvegarder la solution d'un probleme pour reference future |
| `/helpme` | Aide-memoire de toutes les commandes |

---

## Vue d'ensemble visuelle -- Le parcours complet

```text
┌─────────────────────────────────────────────────────┐
│  UNE FOIS PAR MACHINE (Etape 1)                     │
│                                                     │
│  Terminal :                                         │
│  $ bash <(curl ... setup-security.sh)                │
│                                                     │
│  Resultat :                                         │
│  ~/.claude/CLAUDE.md      ← regles de securite      │
│  ~/.claude/settings.json  ← hook combine + plugins    │
│  ~/.claude/hooks/pre-bash.sh ← safety-net + RTK      │
│  cc-safety-net            ← package npm              │
└─────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  POUR CHAQUE PROJET (Etapes 2-5)                    │
│                                                     │
│  Terminal :                                         │
│  $ cd ~/Projects/my-app                             │
│  $ bash <(curl ... init-claude.sh)                   │
│  $ # editer .claude/CLAUDE.md                       │
│  $ git add .claude/ && git commit                   │
│                                                     │
│  Resultat :                                         │
│  .claude/                 ← commandes, competences, │
│                              modeles, agents         │
└─────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  TRAVAIL (Etape 6)                                  │
│                                                     │
│  $ claude                                           │
│  > /plan add authentication                         │
│  > /debug why 500 on /api/users                     │
│  > /verify                                          │
│  > /audit security                                  │
└─────────────────────────────────────────────────────┘
```

---

## Mise a jour du Toolkit

Lorsque de nouvelles commandes ou de nouveaux modeles sont publies :

```bash
cd ~/Projects/my-app
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/update-claude.sh)
```

Ou depuis Claude Code :

```text
> /install
```

---

## Depannage

| Probleme | Solution |
|----------|----------|
| `cc-safety-net: command not found` | Executez `npm install -g cc-safety-net` |
| Toolkit non detecte par Claude | Verifiez que `.claude/CLAUDE.md` existe a la racine du projet |
| Commandes non disponibles | Relancez `init-claude.sh` ou verifiez le dossier `.claude/commands/` |
| Safety-net bloque une commande legitime | Executez la commande manuellement dans le terminal en dehors de Claude Code |
| RTK ne reecrit pas les commandes | Assurez-vous d'avoir un seul hook combine dans settings.json, pas des hooks separes |
