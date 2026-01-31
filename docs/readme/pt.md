# Claude Toolkit

Instruções completas para desenvolvimento assistido por IA com Claude Code.

[![Quality Check](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](../../README.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **Português** | **[한국어](ko.md)**

> Leia primeiro o [guia de instalação passo a passo](../howto/pt.md).

---

## Para Quem é Este Guia

**Desenvolvedores solo** construindo produtos com [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Stacks suportadas: **Laravel/PHP**, **Ruby on Rails**, **Next.js**, **Node.js**, **Python**, **Go**.

**7 templates** (basic, Laravel, Rails, Next.js, Node.js, Python, Go)

**24 slash commands** | **7 auditorias** | **23+ guias** Veja a [lista completa de comandos, templates, auditorias e componentes](../features.md#slash-commands-24-total).

---

## Início Rápido

### 1. Instalação

O script detecta automaticamente o framework (Laravel, Next.js) e copia o template apropriado.

Basta executar no terminal na pasta do projeto:

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

**Reinicie o Claude!** Para futuras atualizações use o comando `/update-toolkit` para reinstalação ou atualizações.

### 2. Security Pack

Inclui uma configuração de segurança em profundidade. Veja [components/security-hardening.md](../../components/security-hardening.md) para o guia completo.

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/setup-security.sh | bash
```

### 3. Rate Limit Statusline (Claude Max / Pro)

Mostra os limites de sessão/semanais na barra de status do Claude Code. Mais: [components/rate-limit-statusline.md](../../components/rate-limit-statusline.md)

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/install-statusline.sh | bash
```

---

## Recursos Principais

| Recurso | Descrição |
|---------|-----------|
| **Auto-Aprendizado** | `/learn` salva soluções únicas; Acúmulo de Skills captura padrões recorrentes automaticamente |
| **Hooks de Auto-Ativação** | Hook intercepta prompts, pontua contexto (palavras-chave, intenção, caminhos de arquivos), recomenda skills relevantes |
| **Persistência de Memória** | Exportar memória MCP para `.claude/memory/`, commit no git — disponível em qualquer máquina |
| **Depuração Sistemática** | `/debug` aplica 4 fases: causa raiz → padrão → hipótese → correção. Sem adivinhação |
| **Fluxo de Trabalho Estruturado** | 3 fases obrigatórias: PESQUISA (somente leitura) → PLANO (scratchpad) → EXECUÇÃO (após confirmação) |

Veja [descrições detalhadas e exemplos](../features.md).

---

## Servidores MCP (recomendados!)

| Servidor | Propósito |
|----------|-----------|
| `context7` | Documentação de bibliotecas |
| `playwright` | Automação de navegador, testes de UI |
| `memory-bank` | Memória entre sessões |
| `sequential-thinking` | Resolução de problemas passo a passo |
| `memory` | Knowledge Graph (grafo de relacionamentos) |

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add playwright -- npx @playwright/mcp@latest
claude mcp add memory-bank -- npx -y @anthropic/memory-bank-mcp
claude mcp add sequential-thinking -- npx -y @anthropic/sequential-thinking-mcp
claude mcp add memory -- npx -y @anthropic/memory-mcp
```

---

## Estrutura Após Instalação

```text
seu-projeto/
└── .claude/
    ├── CLAUDE.md              # Instruções principais (adapte para seu projeto)
    ├── settings.json          # Hooks, permissões
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
    └── memory/                # Exportação de memória MCP
```

---

## Frameworks Suportados

| Framework | Template | Skills | Auto-detecção |
|-----------|----------|--------|---------------|
| Laravel | ✅ | ✅ | arquivo `artisan` |
| Ruby on Rails | ✅ | ✅ | `bin/rails` / `config/application.rb` |
| Next.js | ✅ | ✅ | `next.config.*` |
| Node.js | ✅ | ✅ | `package.json` (sem next.config) |
| Python | ✅ | ✅ | `pyproject.toml` / `requirements.txt` |
| Go | ✅ | ✅ | `go.mod` |
