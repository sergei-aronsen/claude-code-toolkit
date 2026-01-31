# Claude Guides

Instruções completas para desenvolvimento assistido por IA com Claude Code.

[![Quality Check](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](../../README.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **Português** | **[한국어](ko.md)**

> **Novo no Claude Code?** Leia primeiro o [guia de instalacao passo a passo](../howto/pt.md).

---

## Para Quem e Este Guia

**Desenvolvedores solo** construindo produtos com [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Stacks suportadas: **Laravel/PHP**, **Next.js**, **Node.js**, **Python**, **Go**, **Ruby on Rails**.

Sem uma equipe, voce nao tem revisao de codigo, ninguem para perguntar sobre arquitetura, ninguem para verificar seguranca. Este repositorio preenche essas lacunas:

| Problema | Solucao |
|----------|---------|
| Claude esquece regras toda vez | `CLAUDE.md` — instrucoes que ele le no inicio da sessao |
| Ninguem para perguntar | `/debug` — depuracao sistematica ao inves de adivinhar |
| Sem revisao de codigo | `/audit code` — Claude revisa contra checklist |
| Sem revisao de seguranca | `/audit security` — SQL injection, XSS, CSRF, autenticacao |
| Esquece de verificar antes do deploy | `/verify` — build, tipos, lint, testes em um comando |

**O que tem dentro:** 24 comandos, 7 auditorias, 23+ guias, templates para todas as principais stacks.

---

## Inicio Rapido

### Primeira Instalacao

Diga ao Claude Code:

```text
Install claude-code-toolkit from https://github.com/digitalplanetno/claude-code-toolkit
```

Ou execute no terminal:

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

O script detecta automaticamente o framework (Laravel, Next.js) e copia o template apropriado.

### Apos a Instalacao

Use o comando `/install` para reinstalacao ou atualizacoes:

```text
/install          # detectar framework automaticamente
/install laravel  # forcar Laravel
/install nextjs   # forcar Next.js
/install nodejs   # forcar Node.js
/install python   # forcar Python
/install go       # forcar Go
/install rails    # forcar Rails
```

### Atualizacao

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/update-claude.sh | bash
```

---

## Recursos Principais

### 1. Sistema de Auto-Aprendizado

Claude aprende com suas correcoes e acumula conhecimento do projeto.

**Dois mecanismos:**

| Mecanismo | O que faz | Quando usar |
|-----------|-----------|-------------|
| `/learn` | Salva solucao de problema **unica** | Resolveu problema nao-trivial, encontrou workaround |
| **Acumulo de Skills** | Acumula padroes **recorrentes** | Claude notou que foi corrigido 2+ vezes |

**A diferenca:**

```text
/learn  → "Como resolvi o problema X"     (correcao unica)
skill   → "Como sempre fazemos Y"         (padrao do projeto)
```

**Exemplo /learn:**

```text
> /learn

Analisando sessao...
Encontrado: Correcao de Conexao Prisma Serverless

Problema: Timeout de conexao em Vercel Edge Functions
Solucao: Adicionar ?connection_limit=1 ao DATABASE_URL

Salvar em .claude/learned/prisma-serverless.md? → sim
```

**Exemplo de Acumulo de Skill:**

```text
Usuario: criar endpoint para usuarios
Claude: [cria endpoint]
Usuario: nao, usamos Zod para validacao e AppError para erros

Claude: Notei padrao: endpoints usam Zod + AppError
        Salvar como skill 'backend-endpoints'?
        Sera ativado em: endpoint, api, route

Usuario: sim

[Proxima vez Claude usa Zod + AppError imediatamente]
```

### 2. Hooks de Auto-Ativacao

**Problema:** Voce tem 10 skills, mas esquece de usa-las.

**Solucao:** Hook intercepta o prompt **ANTES** de enviar ao Claude e recomenda carregar uma skill.

```text
Prompt do usuario → Hook analisa → Pontuacao → Recomendacao
```

**Sistema de pontuacao:**

| Gatilho | Pontos | Exemplo |
|---------|--------|---------|
| keyword | +2 | "endpoint" no prompt |
| intentPattern | +4 | "criar.*endpoint" |
| pathPattern | +5 | Arquivo `src/api/*` esta aberto |

**Exemplo:**

```text
Prompt: "criar endpoint POST para registro"
Arquivo: src/api/auth.controller.ts

RECOMENDACOES DE SKILL:
[ALTO] backend-dev (pontuacao: 13)
[ALTO] security-review (pontuacao: 12)

Use a ferramenta Skill para carregar as diretrizes.
```

### 3. Persistencia de Memoria

**Problema:** Memoria MCP e armazenada localmente. Mudou para outro computador — memoria perdida.

**Solucao:** Exportar para `.claude/memory/` → commit no git → disponivel em qualquer lugar.

```text
.claude/memory/
├── knowledge-graph.json   # Relacionamentos de componentes
├── project-context.md     # Contexto do projeto
└── decisions-log.md       # Por que tomamos a decisao X
```

**Fluxo de trabalho:**

```text
No inicio da sessao:    Verificar sincronizacao → Carregar memoria do MCP
Apos mudancas:          Exportar → Commit .claude/memory/
Em novo computador:     Pull → Importar para MCP
```

### 4. Depuracao Sistematica (/debug)

**Lei de Ferro:**

```text
NENHUMA CORRECAO SEM INVESTIGACAO DE CAUSA RAIZ PRIMEIRO
```

**4 fases:**

| Fase | O que fazer | Criterio de saida |
|------|-------------|-------------------|
| **1. Causa Raiz** | Ler erros, reproduzir, rastrear fluxo de dados | Entender O QUE e POR QUE |
| **2. Padrao** | Encontrar exemplo funcionando, comparar | Encontrou diferencas |
| **3. Hipotese** | Formular teoria, testar UMA mudanca | Confirmada |
| **4. Correcao** | Escrever teste, corrigir, verificar | Testes verdes |

**Regra das tres correcoes:**

```text
Se 3+ correcoes nao funcionaram — PARE!
Isso nao e um bug. Isso e um problema arquitetural.
```

### 5. Fluxo de Trabalho Estruturado

**Problema:** Claude frequentemente "codifica direto" ao inves de entender a tarefa.

**Solucao:** 3 fases com restricoes explicitas:

| Fase | Acesso | O que e permitido |
|------|--------|-------------------|
| **PESQUISA** | Somente leitura | Glob, Grep, Read — entender contexto |
| **PLANO** | Somente scratchpad | Escrever plano em `.claude/scratchpad/` |
| **EXECUCAO** | Completo | Somente apos confirmacao do plano |

```text
Usuario: Adicionar validacao de email

Claude: Fase 1: PESQUISA
        [Le arquivos, busca padroes]
        Encontrado: formulario em RegisterForm.tsx, validacao via Zod

        Fase 2: PLANO
        [Cria plano em .claude/scratchpad/current-task.md]
        Plano pronto. Confirme para prosseguir.

Usuario: ok

Claude: Fase 3: EXECUCAO
        Passo 1: Adicionando schema...
        Passo 2: Integrando no formulario...
        Passo 3: Testes...
```

---

## Estrutura Apos Instalacao

```text
seu-projeto/
└── .claude/
    ├── CLAUDE.md              # Instrucoes principais (adapte para seu projeto)
    ├── settings.json          # Hooks, permissoes
    ├── commands/              # Comandos slash
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
    ├── skills/                # Expertise de framework
    │   └── [framework]/SKILL.md
    ├── scratchpad/            # Notas de trabalho
    └── memory/                # Exportacao de memoria MCP
```

---

## O Que Esta Incluido

### Templates (7 opcoes)

| Template | Para que | Recursos |
|----------|----------|----------|
| `base/` | Qualquer projeto | Regras universais |
| `laravel/` | Laravel + Vue/Inertia | Eloquent, migrations, Blade, Pint |
| `nextjs/` | Next.js + TypeScript | App Router, RSC, Tailwind |
| `nodejs/` | Node.js + Express/Fastify | REST API, middlewares, validacao |
| `python/` | Python + FastAPI/Django | Typing, async, ORM |
| `go/` | Go + Gin/Echo | Modules, interfaces, concorrencia |
| `rails/` | Ruby on Rails + Hotwire | ActiveRecord, Turbo, Stimulus, RSpec |

### Comandos Slash (24 no total)

| Comando | Descricao |
|---------|-----------|
| `/verify` | Verificacao pre-commit: build, tipos, lint, testes |
| `/debug [problema]` | Depuracao em 4 fases: causa raiz → hipotese → correcao → verificacao |
| `/learn` | Salvar solucao de problema em `.claude/learned/` |
| `/plan` | Criar plano no scratchpad antes da implementacao |
| `/audit [tipo]` | Executar auditoria (security, performance, code, design, database) |
| `/test` | Escrever testes para modulo |
| `/refactor` | Refatoracao preservando comportamento |
| `/fix [issue]` | Corrigir issue especifica |
| `/explain` | Explicar como o codigo funciona |
| `/doc` | Gerar documentacao |
| `/context-prime` | Carregar contexto do projeto no inicio da sessao |
| `/checkpoint` | Salvar progresso no scratchpad |
| `/handoff` | Preparar transferencia de tarefa (resumo + proximos passos) |
| `/worktree` | Gerenciamento de git worktrees |
| `/install` | Instalar claude-guides no projeto |
| `/migrate` | Assistencia com migracao de banco de dados |
| `/find-function` | Encontrar funcao por nome/descricao |
| `/find-script` | Encontrar script em package.json/composer.json |
| `/tdd` | Fluxo de trabalho Test-Driven Development |
| `/docker` | Configurar Docker e docker-compose |
| `/api` | Gerar endpoints de API com documentacao |
| `/e2e` | Configurar e executar testes end-to-end |
| `/perf` | Analise e otimizacao de performance |
| `/deps` | Gerenciar e atualizar dependencias |

### Auditorias (7 tipos)

| Auditoria | Arquivo | O que verifica |
|-----------|---------|----------------|
| **Seguranca** | `SECURITY_AUDIT.md` | SQL injection, XSS, CSRF, autenticacao, secrets |
| **Performance** | `PERFORMANCE_AUDIT.md` | N+1, tamanho do bundle, caching, lazy loading |
| **Revisao de Codigo** | `CODE_REVIEW.md` | Padroes, legibilidade, SOLID, DRY |
| **Revisao de Design** | `DESIGN_REVIEW.md` | UI/UX, acessibilidade, responsivo (Playwright MCP) |
| **MySQL** | `MYSQL_PERFORMANCE_AUDIT.md` | performance_schema, indices, queries lentas |
| **PostgreSQL** | `POSTGRES_PERFORMANCE_AUDIT.md` | pg_stat_statements, bloat, conexoes |
| **Deploy** | `DEPLOY_CHECKLIST.md` | Checklist pre-deploy |

### Componentes (23+ guias)

| Componente | Descricao |
|------------|-----------|
| `structured-workflow.md` | Abordagem em 3 fases: Pesquisa → Plano → Execucao |
| `smoke-tests-guide.md` | Testes minimos de API (Laravel/Next.js/Node.js) |
| `hooks-auto-activation.md` | Auto-ativacao de skills por contexto do prompt |
| `skill-accumulation.md` | Auto-aprendizado: Claude acumula conhecimento do projeto |
| `modular-skills.md` | Divulgacao progressiva para diretrizes grandes |
| `spec-driven-development.md` | Especificacoes antes do codigo |
| `mcp-servers-guide.md` | Servidores MCP recomendados |
| `memory-persistence.md` | Sincronizacao de memoria MCP com Git |
| `plan-mode-instructions.md` | Niveis de pensamento: think → think hard → ultrathink |
| `git-worktrees-guide.md` | Trabalho paralelo em branches |
| `devops-highload-checklist.md` | Checklist para projetos de alta carga |
| `api-health-monitoring.md` | Monitoramento de endpoints de API |
| `bootstrap-workflow.md` | Fluxo de trabalho para novo projeto |
| `github-actions-guide.md` | Configuracao de CI/CD com GitHub Actions |
| `pre-commit-hooks.md` | Configuracao de hooks pre-commit |
| `deployment-strategies.md` | Estrategias de deploy (blue-green, canary, rolling) |

---

## Servidores MCP (recomendados!)

| Servidor | Proposito |
|----------|-----------|
| `context7` | Documentacao de bibliotecas |
| `playwright` | Automacao de navegador, testes de UI |
| `memory-bank` | Memoria entre sessoes |
| `sequential-thinking` | Resolucao de problemas passo a passo |
| `memory` | Knowledge Graph (grafo de relacionamentos) |

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add playwright -- npx @playwright/mcp@latest
```

---

## Rate Limit Statusline (Claude Max / Pro)

Monitore seus limites de uso da API diretamente na barra de status do Claude Code.

```text
25% | 5h:23% (2h57m) | 7d:80% (1d18h)
 │      │      │          │       │
 │      │      │          │       └─ tempo ate reinicio semanal
 │      │      │          └─ uso semanal (janela de 7 dias)
 │      │      └─ tempo ate reinicio da sessao
 │      └─ uso da sessao (janela de 5 horas)
 └─ uso da janela de contexto
```

**Cores:** sem cor (<60%), amarelo (60-79%), vermelho (80-89%), vermelho brilhante (90-100%)

**Requisitos:** macOS, `jq`, Claude Code com OAuth (assinatura Max ou Pro)

### Instalacao

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/install-statusline.sh | bash
```

O instalador verifica pre-requisitos, baixa scripts para `~/.claude/`, configura `settings.json` e executa um teste inicial.

Detalhes e personalizacao: [components/rate-limit-statusline.md](components/rate-limit-statusline.md).

---

## Exemplos de Uso

### /verify — verificacao pre-commit

```text
> /verify

Executando verificacoes...
Build: passou
TypeScript: sem erros
ESLint: 2 avisos (imports nao utilizados)
Testes: 23 passaram

Recomendacao: corrigir avisos de lint antes do commit.
```

### /debug — depuracao sistematica

```text
> /debug API retorna 500 em /api/users

Fase 1: ANALISE DE CAUSA RAIZ
├── Lendo app/api/users/route.ts
├── Verificando logs
└── Encontrado: prisma.user.findMany() sem try/catch

Fase 2: HIPOTESE
└── Timeout de conexao com banco de dados em cold start

Fase 3: CORRECAO
└── Adicionando tratamento de erro + logica de retry

Fase 4: VERIFICACAO
└── Testando endpoint — funciona
```

### /audit security — auditoria de seguranca

```text
> /audit security

RELATORIO DE AUDITORIA DE SEGURANCA
====================================

CRITICO (1)
├── SQL Injection em UserController:45
└── Recomendacao: usar prepared statements

MEDIO (2)
├── Sem rate limiting em /api/login
└── CORS configurado como Access-Control-Allow-Origin: *

BAIXO (1)
└── Modo debug em .env.example
```

---

## Frameworks Suportados

| Framework | Template | Skills | Auto-deteccao |
|-----------|----------|--------|---------------|
| Laravel | Dedicado | Sim | arquivo `artisan` |
| Next.js | Dedicado | Sim | `next.config.*` |
| Node.js | Dedicado | Sim | `package.json` (sem next.config) |
| Python | Dedicado | Sim | `pyproject.toml` / `requirements.txt` |
| Go | Dedicado | Sim | `go.mod` |
| Ruby on Rails | Dedicado | Sim | `bin/rails` / `config/application.rb` |
