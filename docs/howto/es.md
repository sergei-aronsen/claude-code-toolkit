# Instalación y uso de Claude Code Toolkit

> El recorrido completo, de cero a desarrollo productivo con Claude Code, en un solo lugar.

**[English](en.md)** | **[Русский](ru.md)** | **Español** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

---

## Prerrequisitos

Asegúrate de tener:

- **Node.js** — `node --version` (se recomienda 20.x o superior)
- **Claude Code** — `claude --version`
- **git** — para hacer commit de `.claude/` en tu repo
- **jq** — el instalador lo necesita para mergear `settings.json` (`brew install jq` / `apt install jq`)

Si Claude Code aún no está instalado:

```bash
npm install -g @anthropic-ai/claude-code
```

---

## Instalación

`cd` a la carpeta de tu proyecto en una **terminal normal** (no dentro de Claude Code) y ejecuta:

```bash
cd ~/Projects/my-app
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

El instalador abre una checklist TUI con todos los componentes:

```text
[x] toolkit              ← contenido del toolkit (.claude/ en el proyecto)
[x] security             ← security pack global + cc-safety-net
[ ] rtk                  ← reescribir salida verbosa de comandos dev (-60-90% tokens)
[ ] statusline           ← uso por sesión/semanal en la barra de estado
[ ] council              ← /council = validación de planes con Gemini + ChatGPT
[ ] gemini-bridge        ← auto-sync CLAUDE.md → GEMINI.md
[ ] codex-bridge         ← auto-sync CLAUDE.md → AGENTS.md
[ ] mcp-servers (24)     ← checklist TUI para integraciones (Stripe, Sentry, dbhub, …)
[ ] skills (22)          ← skills de marketplace (i18n, shadcn, stripe, …)
```

`Espacio` para alternar, `↑/↓` para moverte, `Enter` para instalar lo marcado.

El instalador detecta tu framework (Laravel, Next.js, Python, Go, …) por archivos signatura y entrega el template `CLAUDE.md` adecuado. Si `superpowers` y `get-shit-done` ya están instalados, el toolkit omite los archivos que esos plugins ya proporcionan e instala solo las ~47 contribuciones únicas.

Al terminar, se abre una página HTML local en `.claude/setup-guide.html` con instrucciones paso-a-paso para cada MCP instalado (dónde obtener la API key, qué env var setear, cómo testear).

---

## Commit y empezar a trabajar

```bash
git add .claude/ CLAUDE.md
git commit -m "chore: add Claude Code toolkit configuration"
claude
```

Claude Code arranca y carga automáticamente:

1. El `~/.claude/CLAUDE.md` global (security rules — instaladas por el script)
2. El `CLAUDE.md` del proyecto (adaptado a tu stack — puedes extender con detalles project-specific)
3. Cada comando de `.claude/commands/` y skill del marketplace

---

## Comandos útiles

| Comando            | Qué hace                                                                       |
|--------------------|--------------------------------------------------------------------------------|
| `/update-toolkit`  | Trae contenido fresco del toolkit preservando ediciones locales de `CLAUDE.md`. |
| `/update-deps`     | Dashboard de dependencias (Layer 1/2/3 + MCP). Eliges qué actualizar.          |
| `/council plan`    | Envía un plan a Gemini + ChatGPT para review independiente.                    |
| `/learn`           | Guarda la decisión actual como regla scoped para sesiones futuras.             |
| `/audit security`  | Una de las 7 auditorías por framework.                                         |
| `/debug problema`  | Depurador sistemático de 4 fases.                                              |
| `/setup-guide`     | Regenera la guía HTML local de configuración.                                  |
| `/helpme`          | Cheatsheet completo de comandos.                                               |

---

## Diagrama visual

```text
┌────────────────────────────────────────────────────────┐
│  INSTALACIÓN (una vez por proyecto)                    │
│                                                        │
│  $ cd ~/Projects/my-app                                │
│  $ bash <(curl -sSL …/install.sh)                      │
│  → checklist TUI → Espacio/Enter                       │
│                                                        │
│  Resultado:                                            │
│   ~/.claude/CLAUDE.md       ← security rules           │
│   .claude/                  ← comandos, skills, agents │
│   CLAUDE.md                 ← template para tu stack   │
│   .claude/setup-guide.html  ← guía API de MCPs         │
└────────────────────────────────────────────────────────┘
                       │
                       ▼
┌────────────────────────────────────────────────────────┐
│  TRABAJO DIARIO                                        │
│                                                        │
│  $ claude                                              │
│  > /plan agregar autenticación                         │
│  > /debug 500 en /api/users                            │
│  > /audit security                                     │
│  > /council mi plan de migración de DB                 │
└────────────────────────────────────────────────────────┘
```

---

## Actualizar

```bash
cd ~/Projects/my-app
# Dentro de Claude Code:
> /update-toolkit   # contenido del toolkit
> /update-deps      # todas las dependencias (TUI con checkboxes)
```

`/update-deps` muestra la lista TUI completa con installed-vs-latest. Eliges qué bumpear, lo demás se queda igual.

---

## Claude Desktop

Los usuarios de Desktop instalan vía marketplace:

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

Obtienes tres sub-plugins: `tk-skills` (22 skills), `tk-commands` (29 comandos), `tk-framework-rules` (7 fragmentos de CLAUDE.md). Detalles: [docs/CLAUDE_DESKTOP.md](../CLAUDE_DESKTOP.md).

---

## Resolución de problemas

| Problema                                            | Solución                                                                                  |
|-----------------------------------------------------|-------------------------------------------------------------------------------------------|
| `cc-safety-net: command not found` tras instalar    | `npm install -g cc-safety-net`, luego `bash <(curl …/scripts/install-hooks.sh)`           |
| RTK no reescribe los comandos                       | `~/.claude/settings.json` debe tener **un único** hook combinado, no dos separados        |
| Claude no ve los comandos del proyecto              | Reinicia `claude` desde la misma carpeta donde está `.claude/`                            |
| safety-net bloquea un comando que necesitas         | Ejecútalo manualmente en una terminal normal (o temporalmente `TK_NO_SAFETY=1`)           |
| El instalador se cuelga en el TUI                   | `Ctrl-C`, reintenta; en macOS `bash` 3.2 las flechas pueden requerir `--no-tui-fallback`  |
| `setup-guide.html` no se abre                       | `open .claude/setup-guide.html` (macOS) / `xdg-open` (Linux). O ejecuta `/setup-guide`.   |
