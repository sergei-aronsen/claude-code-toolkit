# Claude Code Toolkit

Instrucciones completas para el desarrollo asistido por IA con Claude Code.

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](../../README.md)** | **[Русский](ru.md)** | **Español** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

> Lee primero la [guia de instalacion paso a paso](../howto/es.md) completa.

---

## Para Quien es Esto

**Desarrolladores individuales** que construyen productos con [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Stacks soportados: **Laravel/PHP**, **Ruby on Rails**, **Next.js**, **Node.js**, **Python**, **Go**.

**7 plantillas** (basic, Laravel, Rails, Next.js, Node.js, Python, Go)

**29 slash commands** | **7 auditorias** | **30 guias** | Ver la [lista completa de comandos, plantillas, auditorias y componentes](../features.md#slash-commands-29-total).

---

## Inicio Rapido

### 1. Configuracion Global (una vez)

#### a) Security Pack

Configuracion de seguridad en profundidad. Consulta [components/security-hardening.md](../../components/security-hardening.md) para la guia completa.

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)
```

#### b) RTK — Optimizador de Tokens (recomendado)

[RTK](https://github.com/rtk-ai/rtk) reduce el consumo de tokens en un 60-90% en comandos de desarrollo (`git status`, `cargo test`, etc.).

```bash
brew install rtk
rtk init -g
```

> **Nota:** El Security Pack (paso 1a) ya configura un hook combinado que ejecuta safety-net y RTK secuencialmente.
> Ver [components/security-hardening.md](../../components/security-hardening.md) para detalles.

#### c) Rate Limit Statusline (Claude Max / Pro, opcional)

Muestra los limites de sesion/semanales en la barra de estado de Claude Code. Mas informacion: [components/rate-limit-statusline.md](../../components/rate-limit-statusline.md)

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-statusline.sh)
```

### 2. Instalacion (por proyecto)

El instalador:

- Te pedira **seleccionar tu stack** (auto-deteccion recomendada)
- Instalara el toolkit (comandos, agentes, prompts, skills)
- Configurara **Supreme Council** (revision multi-IA con Gemini + ChatGPT)
- Te guiara en la configuracion de claves API

Ejecuta en tu terminal habitual (no dentro de Claude Code) en la carpeta del proyecto:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
```

**Inicia Claude Code!** Para futuras actualizaciones usa el comando `/update-toolkit`.

---

## Caracteristicas Principales

| Caracteristica | Descripcion |
|----------------|-------------|
| **Auto-Aprendizaje** | `/learn` guarda soluciones unicas; la Acumulacion de Habilidades captura patrones recurrentes automaticamente |
| **Hooks de Auto-Activacion** | El hook intercepta prompts, evalua el contexto (palabras clave, intencion, rutas de archivos), recomienda habilidades relevantes |
| **Persistencia del Conocimiento** | Hechos del proyecto en `.claude/rules/` — carga automatica en cada sesion, commit a git, disponible en cualquier maquina |
| **Depuracion Sistematica** | `/debug` aplica 4 fases: causa raiz, patron, hipotesis, correccion. Sin adivinanzas |
| **Seguridad en Produccion** | `/deploy` con verificaciones pre/post, `/fix-prod` para hotfixes, despliegues incrementales |
| **Supreme Council** | `/council` envia planes a Gemini + ChatGPT para revision independiente antes de codificar |
| **Flujo de Trabajo Estructurado** | 3 fases obligatorias: INVESTIGACION (solo lectura), PLAN (scratchpad), EJECUCION (tras confirmacion) |

Ver [descripciones detalladas y ejemplos](../features.md).

---

## Servidores MCP (recomendados!)

| Servidor | Proposito |
|----------|-----------|
| `context7` | Documentacion de librerias |
| `playwright` | Automatizacion de navegador, testing de UI |
| `sequential-thinking` | Resolucion de problemas paso a paso |

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add playwright -- npx @playwright/mcp@latest
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
```

---

## Estructura Despues de la Instalacion

```text
your-project/
└── .claude/
    ├── CLAUDE.md              # Instrucciones principales (adapta para tu proyecto)
    ├── settings.json          # Hooks, permisos
    ├── commands/              # Slash commands
    │   ├── verify.md
    │   ├── debug.md
    │   └── ...
    ├── prompts/               # Auditorias
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
    └── rules/                 # Datos del proyecto (carga automatica)
```

---

## Frameworks Soportados

| Framework | Plantilla | Skills | Auto-deteccion |
|-----------|-----------|--------|----------------|
| Laravel | ✅ | ✅ | archivo `artisan` |
| Ruby on Rails | ✅ | ✅ | `bin/rails` / `config/application.rb` |
| Next.js | ✅ | ✅ | `next.config.*` |
| Node.js | ✅ | ✅ | `package.json` (sin next.config) |
| Python | ✅ | ✅ | `pyproject.toml` / `requirements.txt` |
| Go | ✅ | ✅ | `go.mod` |
