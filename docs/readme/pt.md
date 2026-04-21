# Claude Code Toolkit

Conjunto completo de instruções para desenvolvimento assistido por IA com Claude Code.

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](../../README.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **Português** | **[한국어](ko.md)**

> Primeiro leia o [guia de instalação passo a passo](../howto/pt.md) completo.

---

## Para quem é isto

**Solo-desenvolvedores** que criam produtos com [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Stacks compatíveis: **Laravel/PHP**, **Ruby on Rails**, **Next.js**, **Node.js**, **Python**, **Go**.

**30 comandos slash** | **7 auditorias** | **29 guias** | Veja a [lista completa de comandos, modelos, auditorias e componentes](../features.md#slash-commands-30-total).

---

## Início rápido

### 1. Configuração global (uma vez)

#### a) Security Pack

Configuração de segurança em profundidade. Veja [components/security-hardening.md](../../components/security-hardening.md) para o guia completo.

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)
```

#### b) RTK — Otimizador de tokens (recomendado)

[RTK](https://github.com/rtk-ai/rtk) reduz o consumo de tokens em 60-90% nos comandos de desenvolvimento (`git status`, `cargo test`, etc.).

```bash
brew install rtk
rtk init -g
```

> **Nota:** Se RTK e cc-safety-net forem hooks separados, os resultados conflitam.
> O Security Pack (passo 1a) já configura um hook combinado que executa ambos sequencialmente.
> Veja [components/security-hardening.md](../../components/security-hardening.md) para mais detalhes.

#### c) Rate Limit Statusline (Claude Max / Pro, opcional)

Exibe os limites de sessão/semana na barra de status do Claude Code. Mais: [components/rate-limit-statusline.md](../../components/rate-limit-statusline.md)

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-statusline.sh)
```

## Modos de instalação

TK detecta automaticamente se `superpowers` (obra) e `get-shit-done` (gsd-build) estão instalados e
escolhe um dos quatro modos: `standalone`, `complement-sp`, `complement-gsd` ou `complement-full`.
Cada modelo de framework documenta seus plugins base necessários em `## Required Base Plugins` — veja,
por exemplo, [templates/base/CLAUDE.md](../../templates/base/CLAUDE.md). Para a matriz de instalação
completa de 12 células e o guia passo a passo, consulte [docs/INSTALL.md](../INSTALL.md).

### Instalação independente

Você não tem `superpowers` nem `get-shit-done` instalados (ou optou por não usá-los).
TK instala todos os 54 arquivos — a opção padrão completa. Execute no terminal normal
(não dentro do Claude Code!) na pasta do projeto:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
```

Em seguida, inicie o Claude Code nesse diretório. Para futuras atualizações use `/update-toolkit`.

### Instalação complementar

Você tem um ou ambos de `superpowers` (obra) e `get-shit-done` (gsd-build) instalados. TK
os detecta automaticamente e ignora os 7 arquivos que duplicariam a funcionalidade do SP, mantendo as
~47 contribuições exclusivas do TK (Council, modelos CLAUDE.md por framework, biblioteca de componentes,
cheatsheets, skills por framework). Use o mesmo comando de instalação — TK seleciona automaticamente o
modo `complement-*`. Para substituir, passe `--mode standalone` (ou outro nome de modo):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh) --mode complement-full
```

### Atualização do v3.x

Usuários do v3.x que instalaram SP ou GSD após o TK devem executar `scripts/migrate-to-complement.sh` para
remover arquivos duplicados com confirmação por arquivo e um backup completo pré-migração. Veja
[docs/INSTALL.md](../INSTALL.md) para a matriz completa de 12 células e o guia passo a passo.

> **Importante:** O modelo do projeto é somente para `project/.claude/CLAUDE.md`. Não copie para
> `~/.claude/CLAUDE.md` — esse arquivo deve conter apenas regras de segurança globais e preferências
> pessoais (menos de 50 linhas). Veja [components/claude-md-guide.md](../../components/claude-md-guide.md)
> para mais detalhes.

---

## Killer Features

| Função | Descrição |
|--------|-----------|
| **Self-Learning** | `/learn` salva soluções como arquivos de regras com `globs:` — carregados automaticamente apenas para arquivos relevantes |
| **Auto-Activation Hooks** | Hook intercepta prompts, avalia o contexto (palavras-chave, intenção, caminhos de arquivos), recomenda skills relevantes |
| **Knowledge Persistence** | Fatos do projeto em `.claude/rules/` — carregados automaticamente a cada sessão, no git, disponíveis em qualquer máquina |
| **Systematic Debugging** | `/debug` aplica 4 fases: causa raiz → padrão → hipótese → solução. Sem adivinhações |
| **Production Safety** | `/deploy` com verificações pré/pós, `/fix-prod` para hotfixes, deploys incrementais, segurança de workers |
| **Supreme Council** | `/council` envia planos para Gemini + ChatGPT para revisão independente antes de codificar |
| **Structured Workflow** | 3 fases obrigatórias: RESEARCH (somente leitura) → PLAN (rascunho) → EXECUTE (após confirmação) |

Veja [descrições detalhadas e exemplos](../features.md).

---

## Servidores MCP (recomendado!)

### Global (todos os projetos)

| Servidor | Propósito |
|----------|-----------|
| `context7` | Documentação de bibliotecas |
| `playwright` | Automação de navegador, testes de UI |
| `sequential-thinking` | Resolução de problemas passo a passo |
| `sentry` | Monitoramento de erros e investigação de incidentes |

```bash
claude mcp add -s user context7 -- npx -y @upstash/context7-mcp
claude mcp add -s user playwright -- npx @playwright/mcp@latest --browser chromium
claude mcp add -s user sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp
```

### Por projeto (credenciais)

| Servidor | Propósito |
|----------|-----------|
| `dbhub` | Acesso universal a bancos de dados (PostgreSQL, MySQL, MariaDB, SQL Server, SQLite) |

```bash
claude mcp add dbhub -- npx -y @bytebase/dbhub --dsn "postgresql://user:pass@localhost:5432/dbname"
```

> **Segurança:** Use sempre um **usuário de banco de dados somente leitura** — não confie apenas no flag `--readonly` do DBHub ([bypasses conhecidos](https://github.com/bytebase/dbhub/issues/271)). Servidores por projeto vão em `.claude/settings.local.json` (no .gitignore, seguro para credenciais). Veja [mcp-servers-guide.md](../../components/mcp-servers-guide.md) para todos os detalhes.

---

## Estrutura após a instalação

Arquivos marcados com † conflitam com `superpowers` — omitidos nos modos `complement-sp` e `complement-full`.

```text
your-project/
└── .claude/
    ├── CLAUDE.md              # Instruções principais (adapte para seu projeto)
    ├── settings.json          # Hooks, permissões
    ├── commands/              # Comandos slash
    │   ├── verify.md          # † omitido em complement-sp/full
    │   ├── debug.md           # † omitido em complement-sp/full
    │   └── ...
    ├── prompts/               # Auditorias
    │   ├── SECURITY_AUDIT.md
    │   ├── PERFORMANCE_AUDIT.md
    │   ├── CODE_REVIEW.md
    │   ├── DESIGN_REVIEW.md
    │   ├── MYSQL_PERFORMANCE_AUDIT.md
    │   └── POSTGRES_PERFORMANCE_AUDIT.md
    ├── agents/                # Subagentes
    │   ├── code-reviewer.md   # † omitido em complement-sp/full
    │   ├── test-writer.md
    │   └── planner.md
    ├── skills/                # Experiência de frameworks
    │   └── [framework]/SKILL.md
    ├── rules/                 # Fatos do projeto carregados automaticamente
    └── scratchpad/            # Notas de trabalho
```

---

## Frameworks compatíveis

| Framework | Modelo | Skills | Detecção automática |
|-----------|--------|--------|---------------------|
| Laravel | ✅ | ✅ | Arquivo `artisan` |
| Ruby on Rails | ✅ | ✅ | `bin/rails` / `config/application.rb` |
| Next.js | ✅ | ✅ | `next.config.*` |
| Node.js | ✅ | ✅ | `package.json` (sem next.config) |
| Python | ✅ | ✅ | `pyproject.toml` / `requirements.txt` |
| Go | ✅ | ✅ | `go.mod` |

---

## Componentes

Seções de Markdown reutilizáveis para compor arquivos `CLAUDE.md` personalizados. Os componentes são
ativos na raiz do repositório — **não** são instalados em `.claude/`; referencie-os por URL absoluta do GitHub.

**Padrão de orquestração** — veja [components/orchestration-pattern.md](../../components/orchestration-pattern.md)
para o design de orquestrador leve + subagentes robustos que tanto o Council quanto os fluxos de trabalho GSD usam.
Ajuda qualquer comando slash personalizado a escalar além de uma única janela de contexto.
