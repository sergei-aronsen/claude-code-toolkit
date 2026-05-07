# Claude Code Toolkit

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-6.4.0-blue.svg)](../../CHANGELOG.md)

**[English](../../README.md)** | **[Русский](ru.md)** | **Español** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

---

## Qué es

Una capa fina sobre [**Superpowers**](https://github.com/obra/superpowers) (brainstorming, subagentes, TDD, depuración) y [**Get Shit Done**](https://github.com/gsd-build/get-shit-done) (Spec → Plan → Execute) que cierra los huecos que esos plugins dejan abiertos para los desarrolladores en solitario.

**Para:** fundadores en solitario y equipos de ingeniería de una sola persona que envían productos reales con [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

**Stacks soportados:** Laravel · Rails · Next.js · Node.js · Python · Go.

## Huecos que cierra

| Hueco                                | Lo que añade el toolkit                                                                                                                            |
|--------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------|
| **Validación multi-IA de planes**    | `/council` — envía tu plan a Gemini y ChatGPT en paralelo para revisión independiente. Funciona con CLI (`gemini`, `codex`) o claves API directas. Personas, caché por hash, control de coste, locale ru. |
| **Contexto por framework**           | 7 plantillas `CLAUDE.md` listas (base + 6 stacks), autodetectadas vía `artisan` / `next.config` / `go.mod` / `pyproject.toml` / `package.json`.    |
| **Red de seguridad en producción**   | `cc-safety-net` bloquea comandos destructivos (`rm -rf /`, `git reset --hard`, etc.) en PreToolUse — incluso ofuscados. Integrado en el instalador. |
| **Control de coste de tokens**       | RTK reescribe la salida verbosa de comandos dev (`git status`, test runners) — ahorro del 60-90% en tokens. Hook combinado con `cc-safety-net`.    |
| **Cost routing**                     | `better-model` enruta tareas simples a modelos más baratos. Auto-instalado e integrado en el ciclo de vida de la instalación.                      |
| **Búsqueda de código por símbolos**  | [Serena](https://github.com/oraios/serena) (LSP, MIT, local) + ripgrep + claude-context (vector semántico). Stack Layer-3 por defecto.             |
| **Multi-CLI bridges**                | Auto-sincroniza `CLAUDE.md` con `GEMINI.md` (Gemini CLI) y `AGENTS.md` (OpenAI Codex). Detección de drift en cada instalación.                     |
| **Catálogo de integraciones**        | Instalador TUI para 24 servidores MCP + 8 CLIs complementarios en 10 categorías (Backend / Pagos / Workspace / Project Management / …). Scope por fila. |
| **Visibilidad de límites (Pro/Max)** | La statusline muestra el uso por sesión/semanal — ves cuándo te vas a chocar contra el muro.                                                       |
| **Dashboard de dependencias (v6.2)** | `/update-deps` — TUI interactivo que lista cada dependencia rastreada (Layer 1/2/3) con installed-vs-latest. Eliges qué actualizar.                |
| **Guía post-install (v6.3)**         | Genera una página HTML local (`.claude/setup-guide.html`) con tutorial por MCP (API-key) y por componente — solo secciones para lo que instalaste. |

El valor central es la curaduría. Todo es opt-in vía checkboxes TUI — nada se fuerza.

## Instalación

Un comando. Ejecútalo en una terminal normal **dentro** de la carpeta de tu proyecto (no dentro de Claude Code):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

El instalador muestra una checklist TUI (Toolkit, Security, RTK, Statusline, Council, Bridges, Integrations) y detecta si `superpowers` y `get-shit-done` ya están instalados. Si lo están, omite los archivos que esos plugins ya proporcionan y solo instala las ~47 contribuciones únicas del toolkit.

Para usuarios de Claude Desktop — instalación vía marketplace:

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

Guía paso a paso completa: [docs/howto/es.md](../howto/es.md).

## Después de instalar

| Comando            | Qué hace                                                                       |
|--------------------|--------------------------------------------------------------------------------|
| `/update-toolkit`  | Descarga contenido fresco del toolkit a `.claude/` preservando ediciones locales. |
| `/update-deps`     | Abre el dashboard de dependencias (Layer 1/2/3 + MCP). Eliges qué actualizar.  |
| `/council`         | Envía un plan a Gemini + ChatGPT para revisión independiente.                  |
| `/learn`           | Guarda la decisión actual como regla scoped para sesiones futuras.             |
| `/audit`           | Ejecuta una de las 7 auditorías por framework (security, performance, etc.).   |
| `/debug`           | Depurador sistemático de 4 fases: root-cause → pattern → hypothesis → fix.     |
| `/setup-guide`     | Regenera la guía HTML local de configuración para los MCP/componentes.         |

Lista completa de comandos: [docs/features.md](../features.md).

## Arquitectura

El toolkit v6.2 es una **capa fina** organizada en tres niveles:

- **Layer 1** — contenido del toolkit (plantillas, slash commands, componentes, skills, agentes)
- **Layer 2** — plugins base gratuitos (Superpowers, Get Shit Done, ru-text)
- **Layer 3** — herramientas externas opcionales (cc-safety-net, RTK, Serena, claude-context, better-model)

Diagrama completo: [docs/architecture.md](../architecture.md).
Para fundadores en solitario / no-desarrolladores: [docs/non-programmer-mode.md](../non-programmer-mode.md).

## Catálogo de servidores MCP

El flag `--integrations` (o `/integrations` después de la primera instalación) abre una checklist TUI con 24 servidores en 10 categorías. Eliges solo lo que tu proyecto necesita.

| Categoría              | Servidores                                                                             |
|------------------------|----------------------------------------------------------------------------------------|
| **docs-research**      | `context7` · `firecrawl` · `notebooklm`                                                |
| **backend**            | `aws-cloudwatch-logs` · `aws-cost-explorer` · `cloudflare` · `dbhub` · `supabase`      |
| **payments**           | `stripe`                                                                               |
| **email**              | `resend` · `mailgun`                                                                   |
| **workspace**          | `calendly` · `notion`                                                                  |
| **project-management** | `jira` · `linear` · `youtrack`                                                         |
| **communication**      | `slack` · `telegram`                                                                   |
| **design**             | `figma`                                                                                |
| **dev-tools**          | `magic` · `openrouter` · `serena` · `claude-context` · `playwright`                    |
| **monitoring**         | `sentry` · `datadog` · `posthog`                                                       |

Cada servidor se instala con elección de scope por fila (`[U]` user / `[P]` project / `[L]` local). El scope project escribe credenciales en `<project>/.env` (modo 0600) con auto-`.gitignore`; `.mcp.json` solo lleva la forma `${VAR}`. Más: [docs/INTEGRATIONS.md](../INTEGRATIONS.md).

## Licencia

MIT — ver [LICENSE](../../LICENSE).
