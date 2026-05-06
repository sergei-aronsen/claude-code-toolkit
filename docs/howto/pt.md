# Instalação e uso do Claude Code Toolkit

> O caminho completo, do zero ao desenvolvimento produtivo com Claude Code, em um só lugar.

**[English](en.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **Português** | **[한국어](ko.md)**

---

## Pré-requisitos

Garanta que tem instalado:

- **Node.js** — `node --version` (20.x ou mais novo recomendado)
- **Claude Code** — `claude --version`
- **git** — para commitar `.claude/` no seu repo
- **jq** — necessário ao instalador para mergear `settings.json` (`brew install jq` / `apt install jq`)

Se Claude Code ainda não está instalado:

```bash
npm install -g @anthropic-ai/claude-code
```

---

## Instalação

`cd` na pasta do projeto num **terminal normal** (não dentro do Claude Code) e rode:

```bash
cd ~/Projects/my-app
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

O instalador abre um checklist TUI com todos os componentes:

```text
[x] toolkit              ← conteúdo do toolkit (.claude/ no projeto)
[x] security             ← security pack global + cc-safety-net
[ ] rtk                  ← reescrever saída verbosa de comandos dev (-60-90% tokens)
[ ] statusline           ← uso por sessão/semana na status bar
[ ] council              ← /council = validação de planos com Gemini + ChatGPT
[ ] gemini-bridge        ← auto-sync CLAUDE.md → GEMINI.md
[ ] codex-bridge         ← auto-sync CLAUDE.md → AGENTS.md
[ ] mcp-servers (24)     ← checklist TUI para integrações (Stripe, Sentry, dbhub, …)
[ ] skills (22)          ← skills do marketplace (i18n, shadcn, stripe, …)
```

`Espaço` para alternar, `↑/↓` para mover, `Enter` para instalar o que está marcado.

O instalador detecta seu framework (Laravel, Next.js, Python, Go, …) por arquivos signatura e entrega o template `CLAUDE.md` adequado. Se `superpowers` e `get-shit-done` já estão instalados, o toolkit pula os arquivos que esses plugins já fornecem e instala apenas as ~47 contribuições únicas.

Quando termina, abre uma página HTML local em `.claude/setup-guide.html` com instruções passo-a-passo para cada MCP instalado (onde pegar a API key, qual env var setar, como testar).

---

## Commit e começar a trabalhar

```bash
git add .claude/ CLAUDE.md
git commit -m "chore: add Claude Code toolkit configuration"
claude
```

Claude Code inicia e carrega automaticamente:

1. O `~/.claude/CLAUDE.md` global (security rules — instaladas pelo script)
2. O `CLAUDE.md` do projeto (adaptado ao seu stack — pode estender com detalhes project-specific)
3. Cada comando de `.claude/commands/` e skill do marketplace

---

## Comandos úteis

| Comando            | O que faz                                                                      |
|--------------------|--------------------------------------------------------------------------------|
| `/update-toolkit`  | Pega conteúdo fresco do toolkit preservando edições locais do `CLAUDE.md`.     |
| `/update-deps`     | Dashboard de dependências (Layer 1/2/3 + MCP). Escolhe o que atualizar.        |
| `/council plano`   | Envia um plano para Gemini + ChatGPT para review independente.                 |
| `/learn`           | Salva a decisão atual como regra scoped para sessões futuras.                  |
| `/audit security`  | Uma das 7 auditorias por framework.                                            |
| `/debug problema`  | Debugger sistemático de 4 fases.                                              |
| `/setup-guide`     | Regenera o guia HTML local de configuração.                                    |
| `/helpme`          | Cheatsheet completo de comandos.                                               |

---

## Diagrama visual

```text
┌────────────────────────────────────────────────────────┐
│  INSTALAÇÃO (uma vez por projeto)                      │
│                                                        │
│  $ cd ~/Projects/my-app                                │
│  $ bash <(curl -sSL …/install.sh)                      │
│  → checklist TUI → Espaço/Enter                        │
│                                                        │
│  Resultado:                                            │
│   ~/.claude/CLAUDE.md       ← security rules           │
│   .claude/                  ← comandos, skills, agents │
│   CLAUDE.md                 ← template para seu stack  │
│   .claude/setup-guide.html  ← guia de API de MCPs      │
└────────────────────────────────────────────────────────┘
                       │
                       ▼
┌────────────────────────────────────────────────────────┐
│  TRABALHO DIÁRIO                                       │
│                                                        │
│  $ claude                                              │
│  > /plan adicionar autenticação                        │
│  > /debug 500 em /api/users                            │
│  > /audit security                                     │
│  > /council meu plano de migração de DB                │
└────────────────────────────────────────────────────────┘
```

---

## Atualização

```bash
cd ~/Projects/my-app
# Dentro do Claude Code:
> /update-toolkit   # conteúdo do toolkit
> /update-deps      # todas as dependências (TUI com checkboxes)
```

`/update-deps` mostra a lista TUI completa com installed-vs-latest. Você escolhe o que atualizar; o resto fica como está.

---

## Claude Desktop

Usuários do Desktop instalam via marketplace:

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

Você ganha três sub-plugins: `tk-skills` (22 skills), `tk-commands` (29 comandos), `tk-framework-rules` (7 fragmentos de CLAUDE.md). Detalhes: [docs/CLAUDE_DESKTOP.md](../CLAUDE_DESKTOP.md).

---

## Resolução de problemas

| Problema                                            | Solução                                                                                   |
|-----------------------------------------------------|-------------------------------------------------------------------------------------------|
| `cc-safety-net: command not found` após instalar    | `npm install -g cc-safety-net`, depois `bash <(curl …/scripts/install-hooks.sh)`          |
| RTK não reescreve os comandos                       | `~/.claude/settings.json` tem que ter **um único** hook combinado, não dois separados     |
| Claude não vê os comandos do projeto                | Reinicie `claude` da mesma pasta onde está `.claude/`                                     |
| safety-net bloqueia um comando que você precisa     | Rode manualmente num terminal normal (ou temporariamente `TK_NO_SAFETY=1`)                |
| O instalador trava no TUI                           | `Ctrl-C`, reinicie; no macOS `bash` 3.2 as setas podem precisar de `--no-tui-fallback`    |
| `setup-guide.html` não abre                         | `open .claude/setup-guide.html` (macOS) / `xdg-open` (Linux). Ou rode `/setup-guide`.     |
