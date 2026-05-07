# Claude Code Toolkit

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-6.4.0-blue.svg)](../../CHANGELOG.md)

**[English](../../README.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **Português** | **[한국어](ko.md)**

---

## O que é

Uma camada fina sobre [**Superpowers**](https://github.com/obra/superpowers) (brainstorming, subagentes, TDD, debug) e [**Get Shit Done**](https://github.com/gsd-build/get-shit-done) (Spec → Plan → Execute), que fecha as lacunas que esses plugins deixam para desenvolvedores solos.

**Para:** founders solos e times de engenharia de uma pessoa só que enviam produtos reais com [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

**Stacks suportados:** Laravel · Rails · Next.js · Node.js · Python · Go.

## Lacunas que fecha

| Lacuna                                | O que o toolkit adiciona                                                                                                                          |
|---------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| **Validação multi-IA de planos**      | `/council` — envia teu plano para Gemini e ChatGPT em paralelo para review independente. Funciona via CLI (`gemini`, `codex`) ou chaves API diretas. Persona overlays, cache por hash, cost gate, locale ru. |
| **Contexto por framework**            | 7 templates `CLAUDE.md` prontos (base + 6 stacks), auto-detectados via `artisan` / `next.config` / `go.mod` / `pyproject.toml` / `package.json`.  |
| **Rede de segurança em produção**     | `cc-safety-net` bloqueia comandos destrutivos (`rm -rf /`, `git reset --hard`, etc.) no PreToolUse — mesmo ofuscados. Integrado no instalador.    |
| **Controle de custo de tokens**       | RTK reescreve a saída verbosa de comandos dev (`git status`, test runners) — economia de 60-90% em tokens. Hook combinado com `cc-safety-net`.    |
| **Cost routing**                      | `better-model` roteia tarefas simples para modelos mais baratos. Auto-instalado e integrado no ciclo de vida da instalação.                       |
| **Busca de código por símbolos**      | [Serena](https://github.com/oraios/serena) (LSP, MIT, local) + ripgrep + claude-context (vetor semântico). Stack Layer-3 padrão.                  |
| **Multi-CLI bridges**                 | Auto-sync de `CLAUDE.md` para `GEMINI.md` (Gemini CLI) e `AGENTS.md` (OpenAI Codex). Detecção de drift em cada instalação.                        |
| **Catálogo de integrações**           | Instalador TUI para 24 servidores MCP + 8 CLIs companion em 10 categorias (Backend / Payments / Workspace / Project Management / …). Scope por linha. |
| **Visibilidade de limites (Pro/Max)** | A statusline mostra uso por sessão/semana — você vê quando vai bater no muro.                                                                     |
| **Dashboard de dependências (v6.2)**  | `/update-deps` — TUI interativo listando cada dependência rastreada (Layer 1/2/3) com installed-vs-latest. Você escolhe o que atualizar.         |
| **Guia pós-instalação (v6.3)**        | Gera uma página HTML local (`.claude/setup-guide.html`) com walkthrough por MCP (chave API) e por componente — só seções para o que está instalado. |

O valor central é curadoria. Tudo é opt-in via checkboxes TUI — nada é forçado.

## Instalação

Um comando. Execute num terminal normal **dentro** da pasta do projeto (não dentro do Claude Code):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

O instalador mostra um checklist TUI (Toolkit, Security, RTK, Statusline, Council, Bridges, Integrations) e detecta se `superpowers` e `get-shit-done` já estão instalados. Se estiverem, ele pula os arquivos que esses plugins já fornecem e instala apenas as ~47 contribuições únicas do toolkit.

Para usuários do Claude Desktop — instalação via marketplace:

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

Guia passo-a-passo completo: [docs/howto/pt.md](../howto/pt.md).

## Depois da instalação

| Comando            | O que faz                                                                      |
|--------------------|--------------------------------------------------------------------------------|
| `/update-toolkit`  | Baixa conteúdo fresco do toolkit para `.claude/` preservando edições locais.   |
| `/update-deps`     | Abre o dashboard de dependências (Layer 1/2/3 + MCP). Escolhe o que atualizar. |
| `/council`         | Envia um plano para Gemini + ChatGPT para review independente.                 |
| `/learn`           | Salva a decisão atual como regra scoped para sessões futuras.                  |
| `/audit`           | Roda um dos 7 audits por framework (security, performance, etc.).             |
| `/debug`           | Debugger sistemático de 4 fases: root-cause → pattern → hypothesis → fix.      |
| `/setup-guide`     | Regenera o guia HTML local de configuração para os MCPs/componentes.           |

Lista completa de comandos: [docs/features.md](../features.md).

## Arquitetura

O toolkit v6.2 é uma **camada fina** organizada em três layers:

- **Layer 1** — conteúdo do toolkit (templates, slash commands, componentes, skills, agentes)
- **Layer 2** — plugins base gratuitos (Superpowers, Get Shit Done, ru-text)
- **Layer 3** — ferramentas externas opcionais (cc-safety-net, RTK, Serena, claude-context, better-model)

Diagrama completo: [docs/architecture.md](../architecture.md).
Para founders solos / não-desenvolvedores: [docs/non-programmer-mode.md](../non-programmer-mode.md).

## Catálogo de servidores MCP

O flag `--integrations` (ou `/integrations` depois da primeira instalação) abre um checklist TUI com 24 servidores em 10 categorias. Você pega só o que o projeto precisa.

| Categoria              | Servidores                                                                             |
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

Cada servidor instala com escolha de scope por linha (`[U]` user / `[P]` project / `[L]` local). O scope project escreve credenciais em `<project>/.env` (modo 0600) com auto-`.gitignore`; `.mcp.json` carrega só a forma `${VAR}`. Mais: [docs/INTEGRATIONS.md](../INTEGRATIONS.md).

## Licença

MIT — ver [LICENSE](../../LICENSE).
