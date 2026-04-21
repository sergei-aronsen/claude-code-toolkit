# Claude Code Toolkit

Conjunto completo de instrucciones para el desarrollo asistido por IA con Claude Code.

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](../../README.md)** | **[Русский](ru.md)** | **Español** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

> Primero lea la [guía de instalación paso a paso](../howto/es.md) completa.

---

## Para quién es esto

**Solo-desarrolladores** que crean productos con [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Stacks compatibles: **Laravel/PHP**, **Ruby on Rails**, **Next.js**, **Node.js**, **Python**, **Go**.

**30 comandos slash** | **7 auditorías** | **29 guías** | Vea la [lista completa de comandos, plantillas, auditorías y componentes](../features.md#slash-commands-30-total).

---

## Inicio rápido

### 1. Configuración global (una vez)

#### a) Security Pack

Configuración de seguridad en profundidad. Vea [components/security-hardening.md](../../components/security-hardening.md) para la guía completa.

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)
```

#### b) RTK — Optimizador de tokens (recomendado)

[RTK](https://github.com/rtk-ai/rtk) reduce el consumo de tokens un 60-90% en comandos de desarrollo (`git status`, `cargo test`, etc.).

```bash
brew install rtk
rtk init -g
```

> **Nota:** Si RTK y cc-safety-net son hooks separados, sus resultados entran en conflicto.
> El Security Pack (paso 1a) ya configura un hook combinado que ejecuta ambos de forma secuencial.
> Vea [components/security-hardening.md](../../components/security-hardening.md) para más detalles.

#### c) Rate Limit Statusline (Claude Max / Pro, opcional)

Muestra los límites de sesión/semana en la barra de estado de Claude Code. Más información: [components/rate-limit-statusline.md](../../components/rate-limit-statusline.md)

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-statusline.sh)
```

## Modos de instalación

TK detecta automáticamente si `superpowers` (obra) y `get-shit-done` (gsd-build) están instalados y
elige uno de cuatro modos: `standalone`, `complement-sp`, `complement-gsd` o `complement-full`.
Cada plantilla de framework documenta sus plugins base requeridos en `## Required Base Plugins` — vea,
por ejemplo, [templates/base/CLAUDE.md](../../templates/base/CLAUDE.md). Para la matriz de instalación
completa de 12 celdas y la guía paso a paso, consulte [docs/INSTALL.md](../INSTALL.md).

### Instalación independiente

No tiene `superpowers` ni `get-shit-done` instalados (o ha optado por no usarlos).
TK instala los 54 archivos completos — la opción predeterminada completa. Ejecute en su terminal
habitual (¡no dentro de Claude Code!) en la carpeta del proyecto:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
```

Luego inicie Claude Code en ese directorio del proyecto. Para futuras actualizaciones utilice `/update-toolkit`.

### Instalación complementaria

Tiene uno o ambos de `superpowers` (obra) y `get-shit-done` (gsd-build) instalados. TK
los detecta automáticamente y omite los 7 archivos que duplicarían la funcionalidad de SP, conservando las
~47 contribuciones únicas de TK (Council, plantillas CLAUDE.md por framework, biblioteca de componentes,
cheatsheets, skills por framework). Use el mismo comando de instalación — TK selecciona automáticamente
el modo `complement-*`. Para anularlo, pase `--mode standalone` (u otro nombre de modo):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh) --mode complement-full
```

### Actualización desde v3.x

Los usuarios de v3.x que instalaron SP o GSD después de TK deben ejecutar `scripts/migrate-to-complement.sh` para
eliminar archivos duplicados con confirmación por archivo y una copia de seguridad completa previa a la migración.
Vea [docs/INSTALL.md](../INSTALL.md) para la matriz completa de 12 celdas y la guía paso a paso.

> **Importante:** La plantilla del proyecto es solo para `project/.claude/CLAUDE.md`. No la copie en
> `~/.claude/CLAUDE.md` — ese archivo debe contener únicamente reglas de seguridad globales y preferencias
> personales (menos de 50 líneas). Vea [components/claude-md-guide.md](../../components/claude-md-guide.md)
> para más detalles.

---

## Killer Features

| Función | Descripción |
|---------|-------------|
| **Self-Learning** | `/learn` guarda soluciones como archivos de reglas con `globs:` — cargados automáticamente solo para archivos relevantes |
| **Auto-Activation Hooks** | Hook intercepta prompts, evalúa el contexto (palabras clave, intención, rutas de archivos), recomienda skills relevantes |
| **Knowledge Persistence** | Hechos del proyecto en `.claude/rules/` — cargados automáticamente en cada sesión, en git, disponibles en cualquier máquina |
| **Systematic Debugging** | `/debug` aplica 4 fases: causa raíz → patrón → hipótesis → solución. Sin suposiciones |
| **Production Safety** | `/deploy` con verificaciones pre/post, `/fix-prod` para hotfixes, despliegues incrementales, seguridad de workers |
| **Supreme Council** | `/council` envía planes a Gemini + ChatGPT para revisión independiente antes de codificar |
| **Structured Workflow** | 3 fases obligatorias: RESEARCH (solo lectura) → PLAN (borrador) → EXECUTE (tras confirmación) |

Vea [descripciones detalladas y ejemplos](../features.md).

---

## Servidores MCP (¡recomendado!)

### Global (todos los proyectos)

| Servidor | Propósito |
|----------|-----------|
| `context7` | Documentación de bibliotecas |
| `playwright` | Automatización de navegador, pruebas de UI |
| `sequential-thinking` | Resolución de problemas paso a paso |
| `sentry` | Monitoreo de errores e investigación de incidencias |

```bash
claude mcp add -s user context7 -- npx -y @upstash/context7-mcp
claude mcp add -s user playwright -- npx @playwright/mcp@latest --browser chromium
claude mcp add -s user sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp
```

### Por proyecto (credenciales)

| Servidor | Propósito |
|----------|-----------|
| `dbhub` | Acceso universal a bases de datos (PostgreSQL, MySQL, MariaDB, SQL Server, SQLite) |

```bash
claude mcp add dbhub -- npx -y @bytebase/dbhub --dsn "postgresql://user:pass@localhost:5432/dbname"
```

> **Seguridad:** Utilice siempre un **usuario de base de datos de solo lectura** — no confíe únicamente en el flag `--readonly` de DBHub ([bypasses conocidos](https://github.com/bytebase/dbhub/issues/271)). Los servidores por proyecto van en `.claude/settings.local.json` (en .gitignore, seguro para credenciales). Vea [mcp-servers-guide.md](../../components/mcp-servers-guide.md) para todos los detalles.

---

## Estructura después de la instalación

Los archivos marcados con † entran en conflicto con `superpowers` — omitidos en los modos `complement-sp` y `complement-full`.

```text
your-project/
└── .claude/
    ├── CLAUDE.md              # Instrucciones principales (adapte para su proyecto)
    ├── settings.json          # Hooks, permisos
    ├── commands/              # Comandos slash
    │   ├── verify.md          # † omitido en complement-sp/full
    │   ├── debug.md           # † omitido en complement-sp/full
    │   └── ...
    ├── prompts/               # Auditorías
    │   ├── SECURITY_AUDIT.md
    │   ├── PERFORMANCE_AUDIT.md
    │   ├── CODE_REVIEW.md
    │   ├── DESIGN_REVIEW.md
    │   ├── MYSQL_PERFORMANCE_AUDIT.md
    │   └── POSTGRES_PERFORMANCE_AUDIT.md
    ├── agents/                # Subagentes
    │   ├── code-reviewer.md   # † omitido en complement-sp/full
    │   ├── test-writer.md
    │   └── planner.md
    ├── skills/                # Experiencia de frameworks
    │   └── [framework]/SKILL.md
    ├── rules/                 # Hechos del proyecto cargados automáticamente
    └── scratchpad/            # Notas de trabajo
```

---

## Frameworks compatibles

| Framework | Plantilla | Skills | Detección automática |
|-----------|-----------|--------|----------------------|
| Laravel | ✅ | ✅ | Archivo `artisan` |
| Ruby on Rails | ✅ | ✅ | `bin/rails` / `config/application.rb` |
| Next.js | ✅ | ✅ | `next.config.*` |
| Node.js | ✅ | ✅ | `package.json` (sin next.config) |
| Python | ✅ | ✅ | `pyproject.toml` / `requirements.txt` |
| Go | ✅ | ✅ | `go.mod` |

---

## Componentes

Secciones de Markdown reutilizables para componer archivos `CLAUDE.md` personalizados. Los componentes son
activos en la raíz del repositorio — **no** se instalan en `.claude/`; refiérase a ellos por URL absoluta de GitHub.

**Patrón de orquestación** — vea [components/orchestration-pattern.md](../../components/orchestration-pattern.md)
para el diseño de orquestador ligero + subagentes robustos que usan tanto Council como los flujos de trabajo GSD.
Ayuda a cualquier comando slash personalizado a escalar más allá de una única ventana de contexto.
