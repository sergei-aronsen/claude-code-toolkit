# Claude Guides — Kurzreferenz

## Befehle

| Befehl | Was er tut |
|--------|-----------|
| `/plan` | Implementierungsplan vor dem Coden erstellen |
| `/debug` | Systematisches Debugging (4 Phasen) |
| `/verify` | Pre-Commit-Check: Build, Types, Lint, Tests |
| `/audit` | Audit: Security, Performance, Code, Design, DB |
| `/test` | Tests fuer ein Modul schreiben |
| `/tdd` | Test-Driven Development: erst Tests, dann Code |
| `/fix` | Ein bestimmtes Problem beheben |
| `/refactor` | Struktur verbessern ohne Verhalten zu aendern |
| `/explain` | Code oder Architektur erklaeren |
| `/doc` | Dokumentation generieren |
| `/learn` | Lektion als Scoped Rule in `.claude/rules/` speichern (automatisch via globs) |
| `/context-prime` | Projektkontext zu Sessionbeginn laden |
| `/checkpoint` | Fortschritt im Scratchpad speichern |
| `/handoff` | Aufgabenuebergabe mit Zusammenfassung und naechsten Schritten |
| `/install` | claude-guides im Projekt installieren |
| `/worktree` | Git Worktrees fuer parallele Branches verwalten |
| `/migrate` | Datenbankmigrationen erstellen oder debuggen |
| `/find-function` | Funktions- oder Klassendefinition finden |
| `/find-script` | Scripts in package.json, Makefile etc. finden |
| `/docker` | Dockerfile und docker-compose generieren |
| `/api` | REST API entwerfen, OpenAPI-Spec generieren |
| `/e2e` | E2E-Tests mit Playwright generieren |
| `/perf` | Performance-Analyse: N+1, Bundle, Speicher |
| `/deps` | Dependency-Audit: Sicherheit, Lizenzen, veraltet |
| `/deploy` | Sicheres Deployment mit Pre/Post-Checks |
| `/fix-prod` | Production-Hotfix: Diagnose, Fix, Verifikation |
| `/rollback-update` | Toolkit auf vorherige Version zuruecksetzen |
| `/council` | Multi-AI-Review: Gemini + ChatGPT vor Implementierung |

---

## Agenten

Agenten fuer tiefgehende, fokussierte Analyse:

| Agent | Aufruf | Zweck |
|-------|--------|-------|
| Code Reviewer | `/agent:code-reviewer` | Code-Review gegen Checkliste |
| Test Writer | `/agent:test-writer` | Testgenerierung mit TDD-Ansatz |
| Planner | `/agent:planner` | Aufgabe in Plan mit Phasen aufteilen |
| Security Auditor | `/agent:security-auditor` | Tiefgehende Sicherheitsanalyse |

---

## Audits

Ausfuehren mit `/audit {typ}`:

| Typ | Was geprueft wird |
|-----|------------------|
| `security` | SQL-Injection, XSS, CSRF, Auth, Secrets |
| `performance` | N+1-Queries, Caching, Lazy Loading, Bundle-Groesse |
| `code` | Patterns, Lesbarkeit, SOLID, DRY |
| `design` | UI/UX, Barrierefreiheit, Responsive |
| `mysql` | Indizes, langsame Queries, performance_schema |
| `postgres` | pg_stat_statements, Bloat, Verbindungen |
| `deploy` | Pre-Deployment-Checkliste |

---

## Skills

Skills aktivieren sich automatisch basierend auf dem Kontext:

| Skill | Aktiviert bei |
|-------|--------------|
| Database | Migrationen, Indizes, Queries |
| API Design | REST-Endpoints, OpenAPI, Statuscodes |
| Docker | Container, Dockerfile, Compose |
| Testing | Tests, Mocks, Coverage |
| Tailwind | CSS-Styling, Responsive Design |
| Observability | Logging, Metriken, Tracing |
| LLM Patterns | RAG, Embeddings, Streaming |
| AI Models | Modellauswahl, Preise, Kontextfenster |

---

## Arbeitsablauf

### Drei Phasen (obligatorisch)

```text
RESEARCH (nur lesen) --> PLAN (nur Scratchpad) --> EXECUTE (voller Zugriff)
```

### Denkniveaus

| Niveau | Wann verwenden |
|--------|---------------|
| `think` | Einfache Aufgaben, schnelle Fixes |
| `think hard` | Mehrstufige Features, Refactoring |
| `ultrathink` | Architekturentscheidungen, komplexes Debugging |

---

## Szenarien — Wann Was Verwenden

### Einen Bug gefunden

```text
/debug Beschreibung des Bugs
```

Claude untersucht die Ursache vor der Behebung. Nach dem Fix: `/verify`

### Code-Review noetig

```text
/audit code
```

Fuer vollstaendiges Review: `/audit security`, dann `/audit performance`

### Neues Feature hinzufuegen

```text
/plan Beschreibung des Features
```

Claude erstellt einen Plan im Scratchpad. Nach Genehmigung wird er ausgefuehrt. Dann: `/verify`

### Tests schreiben

```text
/tdd modulname
```

Schreibt zuerst fehlschlagende Tests, dann minimalen Code zum Bestehen.

### Vor dem Deployment

```text
/verify
/audit security
/audit deploy
```

Alle drei, um Probleme vor der Produktion zu erkennen.

### Neue Session starten

```text
/context-prime
```

Laedt den Projektkontext, damit Claude die Codebasis sofort versteht.

### Aufgabe uebergeben

```text
/handoff
```

Erstellt Zusammenfassung: was wurde gemacht, aktueller Stand, naechste Schritte.

### Sicher refaktorisieren

```text
/refactor zielcode
```

Claude refaktorisiert unter Beibehaltung des Verhaltens. Fuehrt immer Tests danach aus.

### Fremden Code verstehen

```text
/explain path/to/file.ts
/explain Authentifizierungsfluss
```

### Datenbankarbeit

```text
/migrate Users-Tabelle erstellen
/audit mysql
/audit postgres
```

### Performance-Probleme

```text
/perf
/audit performance
```

### Dependencies pruefen

```text
/deps
```

### REST API benoetigt

```text
/api Endpoints fuer Users entwerfen
```

### Docker einrichten

```text
/docker
```

### E2E-Tests

```text
/e2e Registrierung und Login
```

---

## MCP-Server

| Server | Zweck |
|--------|-------|
| context7 | Aktuelle Bibliotheksdokumentation |
| playwright | Browser-Automatisierung, UI-Tests, Screenshots |
| sequential-thinking | Schrittweise Problemloesung |

---

## Schnelle Tipps

- Immer `/plan` vor grossen Features verwenden — verhindert verschwendeten Aufwand
- `/verify` vor jedem Commit ausfuehren — erkennt Probleme frueh
- `/learn` nach kniffligen Loesungen verwenden — speichert Wissen fuer die Zukunft
- Sessions mit `/context-prime` beginnen — Claude arbeitet besser mit Kontext
- `/checkpoint` bei langen Aufgaben verwenden — Fortschritt wird gespeichert
- `/debug` ist besser als "einfach mal versuchen" — systematisch ist schneller
