# Claude Guides

Instrucciones completas para el desarrollo asistido por IA con Claude Code.

[![Quality Check](https://github.com/digitalplanetno/claude-guides/actions/workflows/quality.yml/badge.svg)](https://github.com/digitalplanetno/claude-guides/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](README.md)** | **[Русский](README.ru.md)** | **Español** | **[Deutsch](README.de.md)** | **[Français](README.fr.md)** | **[中文](README.zh.md)** | **[日本語](README.ja.md)** | **[Português](README.pt.md)** | **[한국어](README.ko.md)**

---

## Para Quién es Esto

**Desarrolladores individuales** que construyen productos con [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Stacks soportados: **Laravel/PHP**, **Next.js**, **Node.js**, **Python**, **Go**, **Ruby on Rails**.

Sin un equipo, no tienes revisión de código, nadie a quien preguntar sobre arquitectura, nadie que verifique la seguridad. Este repositorio llena esos vacíos:

| Problema | Solución |
|----------|----------|
| Claude olvida las reglas cada vez | `CLAUDE.md` — instrucciones que lee al inicio de sesión |
| Nadie a quien preguntar | `/debug` — depuración sistemática en lugar de adivinar |
| Sin revisión de código | `/audit code` — Claude revisa contra una lista de verificación |
| Sin revisión de seguridad | `/audit security` — SQL injection, XSS, CSRF, autenticación |
| Olvido verificar antes de desplegar | `/verify` — build, tipos, lint, tests en un comando |

**Qué incluye:** 24 comandos, 7 auditorías, más de 23 guías, plantillas para todos los stacks principales.

---

## Inicio Rápido

### Primera Instalación

Dile a Claude Code:

```text
Download instructions from https://github.com/digitalplanetno/claude-guides
```

O ejecuta en la terminal:

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-guides/main/scripts/init-claude.sh | bash
```

El script detecta automáticamente el framework (Laravel, Next.js) y copia la plantilla apropiada.

### Después de la Instalación

Usa el comando `/install` para reinstalación o actualizaciones:

```text
/install          # auto-detectar framework
/install laravel  # forzar Laravel
/install nextjs   # forzar Next.js
/install nodejs   # forzar Node.js
/install python   # forzar Python
/install go       # forzar Go
/install rails    # forzar Rails
```

O vía terminal:

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-guides/main/scripts/update-claude.sh | bash
```

---

## Características Principales

### 1. Sistema de Auto-Aprendizaje

Claude aprende de tus correcciones y acumula conocimiento del proyecto.

**Dos mecanismos:**

| Mecanismo | Qué hace | Cuándo usar |
|-----------|----------|-------------|
| `/learn` | Guarda solución de problema **única** | Resolviste un problema no trivial, encontraste un workaround |
| **Acumulación de Habilidades** | Acumula patrones **recurrentes** | Claude notó que fue corregido 2+ veces |

**La diferencia:**

```text
/learn  → "Cómo resolví el problema X"     (solución única)
skill   → "Cómo siempre hacemos Y"         (patrón del proyecto)
```

**Ejemplo /learn:**

```text
> /learn

Analizando sesión...
Encontrado: Corrección de Conexión Serverless de Prisma

Problema: Timeout de conexión en Vercel Edge Functions
Solución: Agregar ?connection_limit=1 a DATABASE_URL

¿Guardar en .claude/learned/prisma-serverless.md? → sí
```

**Ejemplo de Acumulación de Habilidades:**

```text
Usuario: crear endpoint para usuarios
Claude: [crea endpoint]
Usuario: no, usamos Zod para validación y AppError para errores

Claude: Noté patrón: los endpoints usan Zod + AppError
        ¿Guardar como habilidad 'backend-endpoints'?
        Se activará con: endpoint, api, route

Usuario: sí

[La próxima vez Claude usa Zod + AppError directamente]
```

### 2. Hooks de Auto-Activación

**Problema:** Tienes 10 habilidades, pero olvidas usarlas.

**Solución:** El hook intercepta el prompt **ANTES** de enviarlo a Claude y recomienda cargar una habilidad.

```text
Prompt del usuario → Hook analiza → Puntuación → Recomendación
```

**Sistema de puntuación:**

| Disparador | Puntos | Ejemplo |
|------------|--------|---------|
| keyword | +2 | "endpoint" en el prompt |
| intentPattern | +4 | "create.*endpoint" |
| pathPattern | +5 | Archivo `src/api/*` está abierto |

**Ejemplo:**

```text
Prompt: "crear endpoint POST para registro"
Archivo: src/api/auth.controller.ts

RECOMENDACIONES DE HABILIDADES:
[ALTO] backend-dev (puntuación: 13)
[ALTO] security-review (puntuación: 12)

Usa la herramienta Skill para cargar las guías.
```

### 3. Persistencia de Memoria

**Problema:** La memoria MCP se almacena localmente. Te mudas a otra computadora — memoria perdida.

**Solución:** Exportar a `.claude/memory/` → commit a git → disponible en todas partes.

```text
.claude/memory/
├── knowledge-graph.json   # Relaciones de componentes
├── project-context.md     # Contexto del proyecto
└── decisions-log.md       # Por qué tomamos la decisión X
```

**Flujo de trabajo:**

```text
Al inicio de sesión:    Verificar sincronización → Cargar memoria desde MCP
Después de cambios:     Exportar → Commit .claude/memory/
En nueva computadora:   Pull → Importar a MCP
```

### 4. Depuración Sistemática (/debug)

**Regla de Hierro:**

```text
NO HAY CORRECCIONES SIN INVESTIGACIÓN DE CAUSA RAÍZ PRIMERO
```

**4 fases:**

| Fase | Qué hacer | Criterio de salida |
|------|-----------|-------------------|
| **1. Causa Raíz** | Leer errores, reproducir, rastrear flujo de datos | Entender QUÉ y POR QUÉ |
| **2. Patrón** | Encontrar ejemplo funcional, comparar | Encontrar diferencias |
| **3. Hipótesis** | Formular teoría, probar UN cambio | Confirmado |
| **4. Corrección** | Escribir test, corregir, verificar | Tests verdes |

**Regla de tres correcciones:**

```text
Si 3+ correcciones no funcionaron — ¡PARA!
Esto no es un bug. Es un problema arquitectónico.
```

### 5. Flujo de Trabajo Estructurado

**Problema:** Claude a menudo "codifica directamente" en lugar de entender la tarea.

**Solución:** 3 fases con restricciones explícitas:

| Fase | Acceso | Qué está permitido |
|------|--------|-------------------|
| **INVESTIGACIÓN** | Solo lectura | Glob, Grep, Read — entender contexto |
| **PLAN** | Solo scratchpad | Escribir plan en `.claude/scratchpad/` |
| **EJECUTAR** | Completo | Solo después de confirmar el plan |

```text
Usuario: Agregar validación de email

Claude: Fase 1: INVESTIGACIÓN
        [Lee archivos, busca patrones]
        Encontrado: formulario en RegisterForm.tsx, validación vía Zod

        Fase 2: PLAN
        [Crea plan en .claude/scratchpad/current-task.md]
        Plan listo. Confirma para proceder.

Usuario: ok

Claude: Fase 3: EJECUTAR
        Paso 1: Agregando esquema...
        Paso 2: Integrando en formulario...
        Paso 3: Tests...
```

---

## Estructura Después de la Instalación

```text
tu-proyecto/
└── .claude/
    ├── CLAUDE.md              # Instrucciones principales (adaptar para tu proyecto)
    ├── settings.json          # Hooks, permisos
    ├── commands/              # Comandos slash
    │   ├── verify.md
    │   ├── debug.md
    │   └── ...
    ├── prompts/               # Auditorías
    │   ├── SECURITY_AUDIT.md
    │   ├── PERFORMANCE_AUDIT.md
    │   ├── CODE_REVIEW.md
    │   ├── DESIGN_REVIEW.md
    │   ├── MYSQL_PERFORMANCE_AUDIT.md
    │   └── POSTGRES_PERFORMANCE_AUDIT.md
    ├── agents/                # Subagentes
    │   ├── code-reviewer.md
    │   ├── test-writer.md
    │   └── planner.md
    ├── skills/                # Experiencia del framework
    │   └── [framework]/SKILL.md
    ├── scratchpad/            # Notas de trabajo
    └── memory/                # Exportación de memoria MCP
```

---

## Qué Incluye

### Plantillas (7 opciones)

| Plantilla | Para qué | Características |
|-----------|----------|-----------------|
| `base/` | Cualquier proyecto | Reglas universales |
| `laravel/` | Laravel + Vue/Inertia | Eloquent, migraciones, Blade, Pint |
| `nextjs/` | Next.js + TypeScript | App Router, RSC, Tailwind |
| `nodejs/` | Node.js + TypeScript | Express, Fastify, APIs REST |
| `python/` | Python | FastAPI, Django, Flask |
| `go/` | Go | Gin, Echo, Chi |
| `rails/` | Ruby on Rails + Hotwire | ActiveRecord, Turbo, Stimulus, RSpec |

### Comandos Slash (24 en total)

| Comando | Descripción |
|---------|-------------|
| `/verify` | Verificación pre-commit: build, tipos, lint, tests |
| `/debug [problema]` | Depuración de 4 fases: causa raíz → hipótesis → corrección → verificar |
| `/learn` | Guardar solución de problema en `.claude/learned/` |
| `/plan` | Crear plan en scratchpad antes de implementar |
| `/audit [tipo]` | Ejecutar auditoría (security, performance, code, design, database) |
| `/test` | Escribir tests para módulo |
| `/refactor` | Refactorización preservando comportamiento |
| `/fix [issue]` | Corregir problema específico |
| `/explain` | Explicar cómo funciona el código |
| `/doc` | Generar documentación |
| `/context-prime` | Cargar contexto del proyecto al inicio de sesión |
| `/checkpoint` | Guardar progreso en scratchpad |
| `/handoff` | Preparar traspaso de tarea (resumen + próximos pasos) |
| `/worktree` | Gestión de git worktrees |
| `/install` | Instalar claude-guides en el proyecto |
| `/migrate` | Asistencia para migración de base de datos |
| `/find-function` | Encontrar función por nombre/descripción |
| `/find-script` | Encontrar script en package.json/composer.json |
| `/tdd` | Flujo de trabajo de Desarrollo Guiado por Tests |
| `/docker` | Generar Dockerfile y docker-compose |
| `/api` | Generar endpoints de API con validación |
| `/e2e` | Escribir tests end-to-end |
| `/perf` | Análisis y optimización de rendimiento |
| `/deps` | Auditar y actualizar dependencias |

### Auditorías (7 tipos)

| Auditoría | Archivo | Qué verifica |
|-----------|---------|--------------|
| **Seguridad** | `SECURITY_AUDIT.md` | SQL injection, XSS, CSRF, autenticación, secretos |
| **Rendimiento** | `PERFORMANCE_AUDIT.md` | N+1, tamaño del bundle, caché, lazy loading |
| **Revisión de Código** | `CODE_REVIEW.md` | Patrones, legibilidad, SOLID, DRY |
| **Revisión de Diseño** | `DESIGN_REVIEW.md` | UI/UX, accesibilidad, responsive (Playwright MCP) |
| **MySQL** | `MYSQL_PERFORMANCE_AUDIT.md` | performance_schema, índices, queries lentas |
| **PostgreSQL** | `POSTGRES_PERFORMANCE_AUDIT.md` | pg_stat_statements, bloat, conexiones |
| **Deploy** | `DEPLOY_CHECKLIST.md` | Lista de verificación pre-deploy |

### Componentes (más de 23 guías)

| Componente | Descripción |
|------------|-------------|
| `structured-workflow.md` | Enfoque de 3 fases: Investigación → Plan → Ejecutar |
| `smoke-tests-guide.md` | Tests mínimos de API (Laravel/Next.js/Node.js) |
| `hooks-auto-activation.md` | Auto-activación de habilidades por contexto del prompt |
| `skill-accumulation.md` | Auto-aprendizaje: Claude acumula conocimiento del proyecto |
| `modular-skills.md` | Revelación progresiva para guías grandes |
| `spec-driven-development.md` | Especificaciones antes del código |
| `mcp-servers-guide.md` | Servidores MCP recomendados |
| `memory-persistence.md` | Sincronización de memoria MCP con Git |
| `plan-mode-instructions.md` | Niveles de pensamiento: think → think hard → ultrathink |
| `git-worktrees-guide.md` | Trabajo paralelo en ramas |
| `devops-highload-checklist.md` | Lista de verificación para proyectos de alta carga |
| `api-health-monitoring.md` | Monitoreo de endpoints de API |
| `bootstrap-workflow.md` | Flujo de trabajo para nuevos proyectos |
| `github-actions-guide.md` | Configuración de CI/CD con GitHub Actions |
| `pre-commit-hooks.md` | Configuración de hooks de pre-commit |
| `deployment-strategies.md` | Estrategias de despliegue (blue-green, canary, rolling) |

---

## Servidores MCP (recomendados)

| Servidor | Propósito |
|----------|-----------|
| `context7` | Documentación de librerías |
| `playwright` | Automatización de navegador, testing de UI |
| `memory-bank` | Memoria entre sesiones |
| `sequential-thinking` | Resolución de problemas paso a paso |
| `memory` | Knowledge Graph (grafo de relaciones) |

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add playwright -- npx @playwright/mcp@latest
```

---

## Ejemplos de Uso

### /verify — verificación pre-commit

```text
> /verify

Ejecutando verificaciones...
Build: pasado
TypeScript: sin errores
ESLint: 2 advertencias (imports no usados)
Tests: 23 pasados

Recomendación: corregir advertencias de lint antes del commit.
```

### /debug — depuración sistemática

```text
> /debug API devuelve 500 en /api/users

Fase 1: ANÁLISIS DE CAUSA RAÍZ
├── Leyendo app/api/users/route.ts
├── Verificando logs
└── Encontrado: prisma.user.findMany() sin try/catch

Fase 2: HIPÓTESIS
└── Timeout de conexión a base de datos en cold start

Fase 3: CORRECCIÓN
└── Agregando manejo de errores + lógica de reintentos

Fase 4: VERIFICAR
└── Probando endpoint — funciona
```

### /audit security — auditoría de seguridad

```text
> /audit security

REPORTE DE AUDITORÍA DE SEGURIDAD
=================================

CRÍTICO (1)
├── SQL Injection en UserController:45
└── Recomendación: usar prepared statements

MEDIO (2)
├── Sin rate limiting en /api/login
└── CORS configurado como Access-Control-Allow-Origin: *

BAJO (1)
└── Modo debug en .env.example
```

---

## Frameworks Soportados

| Framework | Plantilla | Habilidades | Auto-detección |
|-----------|-----------|-------------|----------------|
| Laravel | Dedicada | Si | archivo `artisan` |
| Next.js | Dedicada | Si | `next.config.*` |
| Node.js | Dedicada | Si | `package.json` (sin next.config) |
| Python | Dedicada | Si | `pyproject.toml` / `requirements.txt` |
| Go | Dedicada | Si | `go.mod` |
| Ruby on Rails | ✅ Dedicado | ✅ | bin/rails / config/application.rb |
