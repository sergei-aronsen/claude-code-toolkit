# Primeros pasos con Claude Code Toolkit

> Guia completa para principiantes: de cero a desarrollo productivo con Claude Code

**[English](en.md)** | **[Русский](ru.md)** | **Español** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

---

## Requisitos previos

Asegurate de tener instalado:

- **Node.js** (verificar: `node --version`)
- **Claude Code** (verificar: `claude --version`)

Si Claude Code aun no esta instalado:

```bash
npm install -g @anthropic-ai/claude-code
```

---

## Dos niveles de configuracion

| Nivel | Que incluye | Cuando |
|-------|-------------|--------|
| **Global** | Reglas de seguridad + hooks + plugins | Una vez por maquina |
| **Por proyecto** | Comandos, skills, plantillas | Una vez por proyecto |

---

## Paso 1: Configuracion global (una vez por maquina)

Esto instala las reglas de seguridad, el hook combinado (safety-net + soporte RTK) y los plugins oficiales de Anthropic. Se hace **una vez** y funciona para **todos** los proyectos.

Abre tu terminal habitual (no Claude Code):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)
```

**Que sucede:**

- Se crea `~/.claude/CLAUDE.md` — reglas de seguridad globales. Claude Code lee este archivo **en cada inicio en cualquier proyecto**. Es una instruccion como "nunca hagas inyeccion SQL, pregunta antes de operaciones peligrosas"
- Se instala `cc-safety-net` — bloquea comandos destructivos (`rm -rf /`, `git push --force`, etc.)
- Se configura un hook combinado (safety-net + RTK secuencial, sin conflictos paralelos)
- Se habilitan los plugins oficiales de Anthropic (code-review, commit-commands, security-guidance, frontend-design)

**Verifica que todo funciona:**

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/verify-install.sh)
```

Eso es todo. La parte global esta lista. **No necesitas repetir esto nunca mas**.

---

## Paso 2: Crea tu proyecto

Por ejemplo, un proyecto Laravel:

```bash
cd ~/Projects
composer create-project laravel/laravel my-app
cd my-app
git init
```

O Next.js:

```bash
cd ~/Projects
npx create-next-app@latest my-app
cd my-app
```

O si ya tienes un proyecto — simplemente navega a su carpeta:

```bash
cd ~/Projects/my-app
```

---

## Paso 3: Instala el Toolkit en el proyecto

**En tu terminal habitual** (no dentro de Claude Code), desde la carpeta del proyecto, ejecuta:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
```

El script **detecta automaticamente** tu framework (Laravel, Next.js, Python, Go, etc.) y crea:

```text
my-app/
└── .claude/
    ├── CLAUDE.md              ← Instrucciones para Claude (PARA TU PROYECTO)
    ├── settings.json          ← Configuracion, hooks
    ├── commands/              ← 24 comandos slash
    │   ├── debug.md           ← /debug — depuracion sistematica
    │   ├── plan.md            ← /plan — planificacion antes de codificar
    │   ├── verify.md          ← /verify — verificacion antes del commit
    │   ├── audit.md           ← /audit — auditoria de seguridad/rendimiento
    │   ├── test.md            ← /test — escritura de tests
    │   └── ...                ← ~19 comandos mas
    ├── prompts/               ← Plantillas de auditoria
    ├── agents/                ← Sub-agentes (code-reviewer, test-writer)
    ├── skills/                ← Experiencia en frameworks
    ├── cheatsheets/           ← Hojas de referencia rapida (9 idiomas)
    ├── memory/                ← Memoria entre sesiones
    └── scratchpad/            ← Notas de trabajo
```

**Para especificar el framework explicitamente:**

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh) laravel
```

---

## Paso 4: Configura CLAUDE.md para tu proyecto

Este es el archivo mas importante. Abre `.claude/CLAUDE.md` en tu editor y completalo:

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

Claude **lee este archivo en cada inicio** en este proyecto. Cuanto mejor lo completes, mas inteligente sera Claude.

---

## Paso 5: Haz commit de .claude en Git

```bash
git add .claude/
git commit -m "feat: add Claude Code toolkit configuration"
```

Ahora la configuracion esta guardada en el repositorio. Si clonas el proyecto en otra maquina, el toolkit ya estara alli.

---

## Paso 6: Inicia Claude Code y trabaja

```bash
claude
```

Claude Code se inicia y carga automaticamente:

1. **Global** `~/.claude/CLAUDE.md` (reglas de seguridad — del Paso 1)
2. **Proyecto** `.claude/CLAUDE.md` (tus instrucciones — del Paso 4)
3. Todos los comandos de `.claude/commands/`

Ahora puedes trabajar:

```text
> Create a REST API for product management: CRUD, pagination, search
```

---

## Comandos utiles dentro de Claude Code

| Comando | Que hace |
|---------|----------|
| `/plan` | Primero piensa, luego codifica (Investigar → Planificar → Ejecutar) |
| `/debug problema` | Depuracion sistematica en 4 fases |
| `/audit security` | Auditoria de seguridad |
| `/audit` | Revision de codigo |
| `/verify` | Verificacion antes del commit (build + lint + tests) |
| `/test` | Escribir tests |
| `/learn` | Guardar la solucion de un problema para referencia futura |
| `/helpme` | Hoja de referencia de todos los comandos |

---

## Vista general visual — El camino completo

```text
┌─────────────────────────────────────────────────────┐
│  UNA VEZ POR MAQUINA (Paso 1)                       │
│                                                     │
│  Terminal:                                          │
│  $ bash <(curl ... setup-security.sh)                │
│                                                     │
│  Resultado:                                         │
│  ~/.claude/CLAUDE.md      ← reglas de seguridad     │
│  ~/.claude/settings.json  ← hook combinado + plugins │
│  ~/.claude/hooks/pre-bash.sh ← safety-net + RTK     │
│  cc-safety-net            ← paquete npm             │
└─────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  PARA CADA PROYECTO (Pasos 2-5)                     │
│                                                     │
│  Terminal:                                          │
│  $ cd ~/Projects/my-app                             │
│  $ bash <(curl ... init-claude.sh)                   │
│  $ # editar .claude/CLAUDE.md                       │
│  $ git add .claude/ && git commit                   │
│                                                     │
│  Resultado:                                         │
│  .claude/                 ← comandos, skills,       │
│                              prompts, agents        │
└─────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  TRABAJO (Paso 6)                                   │
│                                                     │
│  $ claude                                           │
│  > /plan add authentication                         │
│  > /debug why 500 on /api/users                     │
│  > /verify                                          │
│  > /audit security                                  │
└─────────────────────────────────────────────────────┘
```

---

## Actualizacion del Toolkit

Cuando se publiquen nuevos comandos o plantillas:

```bash
cd ~/Projects/my-app
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/update-claude.sh)
```

O dentro de Claude Code:

```text
> /install
```

---

## Solucion de problemas

| Problema | Solucion |
|----------|----------|
| `cc-safety-net: command not found` | Ejecuta `npm install -g cc-safety-net` |
| Claude no detecta el Toolkit | Verifica que `.claude/CLAUDE.md` exista en la raiz del proyecto |
| Los comandos no estan disponibles | Vuelve a ejecutar `init-claude.sh` o revisa la carpeta `.claude/commands/` |
| Safety-net bloquea un comando legitimo | Ejecuta el comando manualmente en la terminal fuera de Claude Code |
| RTK no reescribe los comandos | Asegurate de tener un solo hook combinado en settings.json, no hooks separados |
