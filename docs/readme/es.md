# Claude Toolkit

Instrucciones completas para el desarrollo asistido por IA con Claude Code.

[![Quality Check](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](../../README.md)** | **[Русский](ru.md)** | **Español** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

> Lee primero la [guia de instalacion paso a paso](../howto/es.md) completa.

---

## Para Quien es Esto

**Desarrolladores individuales** que construyen productos con [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Stacks soportados: **Laravel/PHP**, **Ruby on Rails**, **Next.js**, **Node.js**, **Python**, **Go**.

**7 plantillas** (base, Laravel, Rails, Next.js, Node.js, Python, Go)

**24 slash commands** | **7 auditorias** | **23+ guias** | Ver la [lista completa de comandos, plantillas, auditorias y componentes](../features.md#slash-commands-24-total).

---

## Inicio Rapido

### 1. Instalacion

El script detecta automaticamente el framework y copia la plantilla apropiada.

Simplemente ejecuta en la terminal en la carpeta del proyecto:

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

**Reinicia Claude!** Para futuras actualizaciones usa el comando `/update-toolkit` para reinstalacion o actualizaciones.

### 2. Security Pack

Incluye una configuracion de seguridad en profundidad. Consulta [components/security-hardening.md](../../components/security-hardening.md) para la guia completa.

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/setup-security.sh | bash
```

### 3. Rate Limit Statusline (Claude Max / Pro)

Muestra los limites de sesion/semanales en la barra de estado de Claude Code. Mas informacion: [components/rate-limit-statusline.md](../../components/rate-limit-statusline.md)

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/install-statusline.sh | bash
```

---

## Caracteristicas Principales

| Caracteristica | Descripcion |
|----------------|-------------|
| **Auto-Aprendizaje** | `/learn` guarda soluciones unicas; la Acumulacion de Habilidades captura patrones recurrentes automaticamente |
| **Hooks de Auto-Activacion** | El hook intercepta prompts, evalua el contexto (palabras clave, intencion, rutas de archivos), recomienda habilidades relevantes |
| **Persistencia de Memoria** | Exporta la memoria MCP a `.claude/memory/`, haz commit a git — disponible en cualquier maquina |
| **Depuracion Sistematica** | `/debug` aplica 4 fases: causa raiz, patron, hipotesis, correccion. Sin adivinanzas |
| **Flujo de Trabajo Estructurado** | 3 fases obligatorias: INVESTIGACION (solo lectura), PLAN (scratchpad), EJECUCION (tras confirmacion) |

Ver [descripciones detalladas y ejemplos](../features.md).

---

## Servidores MCP (recomendados!)

| Servidor | Proposito |
|----------|-----------|
| `context7` | Documentacion de librerias |
| `playwright` | Automatizacion de navegador, testing de UI |
| `memory-bank` | Memoria entre sesiones |
| `sequential-thinking` | Resolucion de problemas paso a paso |
| `memory` | Knowledge Graph (grafo de relaciones) |

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add playwright -- npx @playwright/mcp@latest
claude mcp add memory-bank -- npx -y @allpepper/memory-bank-mcp@latest
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
claude mcp add memory -- npx -y @modelcontextprotocol/server-memory
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
    └── memory/                # Exportacion de memoria MCP
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
