# Claude Guides — Guia Rapida

## Comandos

| Comando | Que hace |
|---------|---------|
| `/plan` | Crear plan de implementacion antes de codificar |
| `/design` | Diseno de arquitectura para features complejas |
| `/debug` | Depuracion sistematica (4 fases) |
| `/verify` | Verificacion pre-commit: build, types, lint, tests |
| `/audit` | Auditoria: security, performance, code, design, db |
| `/test` | Escribir tests para un modulo |
| `/tdd` | Test-Driven Development: primero tests, luego codigo |
| `/fix` | Corregir un problema especifico |
| `/refactor` | Mejorar estructura sin cambiar comportamiento |
| `/explain` | Explicar como funciona el codigo o la arquitectura |
| `/doc` | Generar documentacion |
| `/learn` | Guardar leccion como regla scopeada en `.claude/rules/` (carga automatica via globs) |
| `/context-prime` | Cargar contexto del proyecto al inicio de sesion |
| `/checkpoint` | Guardar progreso en scratchpad |
| `/handoff` | Preparar traspaso de tarea con resumen y proximos pasos |
| `/update-toolkit` | Actualizar Claude Code Toolkit |
| `/worktree` | Gestionar git worktrees para ramas paralelas |
| `/migrate` | Crear o depurar migraciones de base de datos |
| `/find-function` | Encontrar definicion de funcion o clase |
| `/find-script` | Encontrar scripts en package.json, Makefile, etc. |
| `/docker` | Generar Dockerfile y docker-compose |
| `/api` | Disenar REST API, generar OpenAPI spec |
| `/e2e` | Generar tests E2E con Playwright |
| `/perf` | Analisis de rendimiento: N+1, bundle, memoria |
| `/deps` | Auditoria de dependencias: seguridad, licencias, obsoletas |
| `/deploy` | Despliegue seguro con verificaciones pre/post |
| `/fix-prod` | Hotfix de produccion: diagnostico, correccion, verificacion |
| `/rollback-update` | Revertir toolkit a la version anterior |
| `/council` | Revision multi-AI: Gemini + ChatGPT pre-implementacion |
| `/helpme` | Guia rapida (9 idiomas) |

---

## Agentes

Agentes para analisis profundo y enfocado:

| Agente | Como llamar | Proposito |
|--------|------------|----------|
| Code Reviewer | `/agent:code-reviewer` | Revision de codigo contra checklist |
| Test Writer | `/agent:test-writer` | Generacion de tests con enfoque TDD |
| Planner | `/agent:planner` | Dividir tarea en plan con fases |
| Security Auditor | `/agent:security-auditor` | Analisis profundo de seguridad |

---

## Auditorias

Ejecutar con `/audit {tipo}`:

| Tipo | Que verifica |
|------|-------------|
| `security` | Inyeccion SQL, XSS, CSRF, auth, secretos |
| `performance` | Consultas N+1, cache, lazy loading, tamano de bundle |
| `code` | Patrones, legibilidad, SOLID, DRY |
| `design` | UI/UX, accesibilidad, responsive |
| `mysql` | Indices, consultas lentas, performance_schema |
| `postgres` | pg_stat_statements, bloat, conexiones |
| `deploy` | Checklist pre-despliegue |

---

## Skills

Los skills se activan automaticamente segun el contexto:

| Skill | Cuando se activa |
|-------|-----------------|
| Database | Migraciones, indices, consultas |
| API Design | Endpoints REST, OpenAPI, codigos de estado |
| Docker | Contenedores, Dockerfile, compose |
| Testing | Tests, mocks, cobertura |
| Tailwind | Estilos CSS, diseno responsive |
| Observability | Logging, metricas, tracing |
| LLM Patterns | RAG, embeddings, streaming |
| AI Models | Seleccion de modelo, precios, ventanas de contexto |

---

## Flujo de Trabajo

### Tres Fases (obligatorio)

```text
RESEARCH (solo lectura) --> PLAN (solo scratchpad) --> EXECUTE (acceso completo)
```

### Niveles de Pensamiento

| Nivel | Cuando usar |
|-------|------------|
| `think` | Tareas simples, arreglos rapidos |
| `think hard` | Features multi-paso, refactoring |
| `ultrathink` | Decisiones de arquitectura, debug complejo |

---

## Escenarios — Cuando Usar Que

### Encontre un bug

```text
/debug descripcion del bug
```

Claude investiga la causa raiz antes de arreglar. Despues del fix: `/verify`

### Necesito code review

```text
/audit code
```

Para revision completa: `/audit security`, luego `/audit performance`

### Quiero agregar una nueva feature

```text
/plan descripcion de la feature
```

Claude crea un plan en scratchpad. Tras aprobacion, lo ejecuta. Luego: `/verify`

### Necesito escribir tests

```text
/tdd nombre_modulo
```

Primero escribe tests que fallan, luego codigo minimo para pasarlos.

### Antes de desplegar

```text
/verify
/audit security
/audit deploy
```

Los tres para detectar problemas antes de produccion.

### Iniciando nueva sesion

```text
/context-prime
```

Carga el contexto del proyecto para que Claude entienda la base de codigo.

### Traspasar tarea a otro desarrollador

```text
/handoff
```

Crea resumen: que se hizo, estado actual, proximos pasos.

### Refactorizar de forma segura

```text
/refactor codigo_objetivo
```

Claude refactoriza preservando comportamiento. Siempre ejecuta tests despues.

### Entender codigo ajeno

```text
/explain path/to/file.ts
/explain flujo de autenticacion
```

### Trabajo con base de datos

```text
/migrate crear tabla users
/audit mysql
/audit postgres
```

### Problemas de rendimiento

```text
/perf
/audit performance
```

### Verificar dependencias

```text
/deps
```

### Necesito REST API

```text
/api disenar endpoints para users
```

### Configurar Docker

```text
/docker
```

### Tests E2E

```text
/e2e registro y login de usuario
```

---

## Servidores MCP

| Servidor | Proposito |
|----------|----------|
| context7 | Documentacion actualizada de librerias |
| playwright | Automatizacion de navegador, tests UI, capturas |
| sequential-thinking | Resolucion paso a paso |

---

## Consejos Rapidos

- Siempre usa `/plan` antes de features grandes — previene esfuerzo desperdiciado
- Ejecuta `/verify` antes de cada commit — detecta problemas temprano
- Usa `/learn` tras resolver problemas complejos — guarda conocimiento para el futuro
- Inicia sesiones con `/context-prime` — Claude trabaja mejor con contexto
- Usa `/checkpoint` en tareas largas — el progreso se guarda si la sesion cae
- `/debug` es mejor que "simplemente intentar arreglar" — el enfoque sistematico es mas rapido
