# Claude Guides — Reference Rapide

## Commandes

| Commande | Ce qu'elle fait |
|----------|----------------|
| `/plan` | Creer un plan d'implementation avant de coder |
| `/debug` | Debogage systematique (4 phases) |
| `/verify` | Verification pre-commit : build, types, lint, tests |
| `/audit` | Audit : security, performance, code, design, db |
| `/test` | Ecrire des tests pour un module |
| `/tdd` | Test-Driven Development : tests d'abord, code ensuite |
| `/fix` | Corriger un probleme specifique |
| `/refactor` | Ameliorer la structure sans changer le comportement |
| `/explain` | Expliquer le fonctionnement du code ou de l'architecture |
| `/doc` | Generer de la documentation |
| `/learn` | Sauvegarder la solution dans `.claude/learned/` pour les sessions futures |
| `/context-prime` | Charger le contexte du projet en debut de session |
| `/checkpoint` | Sauvegarder la progression dans le scratchpad |
| `/handoff` | Preparer le transfert de tache avec resume et prochaines etapes |
| `/install` | Installer claude-guides dans votre projet |
| `/worktree` | Gerer les git worktrees pour les branches paralleles |
| `/migrate` | Creer ou deboguer les migrations de base de donnees |
| `/find-function` | Trouver la definition d'une fonction ou classe |
| `/find-script` | Trouver les scripts dans package.json, Makefile, etc. |
| `/docker` | Generer Dockerfile et docker-compose |
| `/api` | Concevoir une API REST, generer la spec OpenAPI |
| `/e2e` | Generer des tests E2E avec Playwright |
| `/perf` | Analyse de performance : N+1, bundle, memoire |
| `/deps` | Audit des dependances : securite, licences, obsoletes |

---

## Agents

Agents pour une analyse approfondie et ciblee :

| Agent | Comment appeler | Objectif |
|-------|----------------|---------|
| Code Reviewer | `/agent:code-reviewer` | Revue de code contre checklist |
| Test Writer | `/agent:test-writer` | Generation de tests avec approche TDD |
| Planner | `/agent:planner` | Decouper la tache en plan avec phases |
| Security Auditor | `/agent:security-auditor` | Analyse approfondie de securite |

---

## Audits

Executer avec `/audit {type}` :

| Type | Ce qui est verifie |
|------|-------------------|
| `security` | Injection SQL, XSS, CSRF, auth, secrets |
| `performance` | Requetes N+1, cache, lazy loading, taille du bundle |
| `code` | Patterns, lisibilite, SOLID, DRY |
| `design` | UI/UX, accessibilite, responsive |
| `mysql` | Index, requetes lentes, performance_schema |
| `postgres` | pg_stat_statements, bloat, connexions |
| `deploy` | Checklist pre-deploiement |

---

## Skills

Les skills s'activent automatiquement selon le contexte :

| Skill | S'active quand |
|-------|---------------|
| Database | Migrations, index, requetes |
| API Design | Endpoints REST, OpenAPI, codes de statut |
| Docker | Conteneurs, Dockerfile, Compose |
| Testing | Tests, mocks, couverture |
| Tailwind | Styles CSS, design responsive |
| Observability | Logging, metriques, tracing |
| LLM Patterns | RAG, embeddings, streaming |
| AI Models | Selection de modele, prix, fenetres de contexte |

---

## Flux de Travail

### Trois Phases (obligatoire)

```text
RESEARCH (lecture seule) --> PLAN (scratchpad seul) --> EXECUTE (acces complet)
```

### Niveaux de Reflexion

| Niveau | Quand utiliser |
|--------|---------------|
| `think` | Taches simples, corrections rapides |
| `think hard` | Features multi-etapes, refactoring |
| `ultrathink` | Decisions d'architecture, debug complexe |

---

## Scenarios — Quand Utiliser Quoi

### J'ai trouve un bug

```text
/debug description du bug
```

Claude investigue la cause racine avant de corriger. Apres le fix : `/verify`

### J'ai besoin d'une revue de code

```text
/audit code
```

Pour une revue complete : `/audit security`, puis `/audit performance`

### Je veux ajouter une nouvelle feature

```text
/plan description de la feature
```

Claude cree un plan dans le scratchpad. Apres approbation, il l'execute. Ensuite : `/verify`

### J'ai besoin d'ecrire des tests

```text
/tdd nom_module
```

Ecrit d'abord des tests qui echouent, puis le code minimal pour les faire passer.

### Avant le deploiement

```text
/verify
/audit security
/audit deploy
```

Les trois pour detecter les problemes avant la production.

### Demarrer une nouvelle session

```text
/context-prime
```

Charge le contexte du projet pour que Claude comprenne la base de code.

### Transferer la tache a un autre developpeur

```text
/handoff
```

Cree un resume : ce qui a ete fait, etat actuel, prochaines etapes.

### Refactoriser en securite

```text
/refactor code_cible
```

Claude refactorise en preservant le comportement. Execute toujours les tests apres.

### Comprendre du code inconnu

```text
/explain path/to/file.ts
/explain flux d'authentification
```

### Travail avec la base de donnees

```text
/migrate creer table users
/audit mysql
/audit postgres
```

### Problemes de performance

```text
/perf
/audit performance
```

### Verifier les dependances

```text
/deps
```

### API REST necessaire

```text
/api concevoir endpoints pour users
```

### Configurer Docker

```text
/docker
```

### Tests E2E

```text
/e2e inscription et connexion utilisateur
```

---

## Serveurs MCP

| Serveur | Objectif |
|---------|---------|
| context7 | Documentation actualisee des bibliotheques |
| playwright | Automatisation navigateur, tests UI, captures |
| memory-bank | Memoire persistante entre sessions |
| sequential-thinking | Resolution etape par etape |
| memory | Graphe de connaissances pour les relations |

---

## Conseils Rapides

- Toujours utiliser `/plan` avant les grosses features — evite le gaspillage d'effort
- Executer `/verify` avant chaque commit — detecte les problemes tot
- Utiliser `/learn` apres les solutions complexes — sauvegarde les connaissances
- Commencer les sessions avec `/context-prime` — Claude travaille mieux avec du contexte
- Utiliser `/checkpoint` lors des longues taches — la progression est sauvegardee
- `/debug` est mieux que "essayer de corriger" — l'approche systematique est plus rapide
