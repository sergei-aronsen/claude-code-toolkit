# Primeiros Passos com o Claude Code Toolkit

> Guia completo para iniciantes: do zero ao desenvolvimento produtivo com Claude Code

**[English](en.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **Português** | **[한국어](ko.md)**

---

## Pre-requisitos

Certifique-se de que tem instalado:

- **Node.js** (verificar: `node --version`)
- **Claude Code** (verificar: `claude --version`)

Se o Claude Code ainda nao estiver instalado:

```bash
npm install -g @anthropic-ai/claude-code
```

---

## Dois Niveis de Configuracao

| Nivel | O que | Quando |
|-------|-------|--------|
| **Global** | Regras de seguranca + hooks + plugins | Uma vez por maquina |
| **Por projeto** | Comandos, skills, templates | Uma vez por projeto |

---

## Passo 1: Configuracao Global (uma vez por maquina)

Isto instala as regras de seguranca, o hook combinado (safety-net + suporte RTK) e os plugins oficiais da Anthropic. Feito **uma vez**, funciona para **todos** os projetos.

Abra o seu terminal normal (nao o Claude Code):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)
```

**O que acontece:**

- `~/.claude/CLAUDE.md` e criado — regras de seguranca globais. O Claude Code le este ficheiro **a cada inicio em qualquer projeto**. E uma instrucao como "nunca faca SQL injection, nao use eval(), pergunte antes de operacoes perigosas"
- `cc-safety-net` e instalado — bloqueia comandos destrutivos (`rm -rf /`, `git push --force`, etc.)
- Um hook combinado e configurado (safety-net + RTK sequencial, sem conflitos paralelos)
- Os plugins oficiais da Anthropic sao ativados (code-review, commit-commands, security-guidance, frontend-design)

**Verificar que tudo esta a funcionar:**

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/verify-install.sh)
```

E isso. A parte global esta concluida. **Nunca precisara de repetir isto**.

---

## Passo 2: Criar o Seu Projeto

Por exemplo, um projeto Laravel:

```bash
cd ~/Projects
composer create-project laravel/laravel my-app
cd my-app
git init
```

Ou Next.js:

```bash
cd ~/Projects
npx create-next-app@latest my-app
cd my-app
```

Ou se ja tem um projeto — basta navegar ate a sua pasta:

```bash
cd ~/Projects/my-app
```

---

## Passo 3: Instalar o Toolkit no Projeto

**No seu terminal normal** (nao dentro do Claude Code), a partir da pasta do projeto, execute:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
```

O script **deteta automaticamente** o seu framework (Laravel, Next.js, Python, Go, etc.) e cria:

```text
my-app/
└── .claude/
    ├── CLAUDE.md              ← Instrucoes para o Claude (PARA O SEU PROJETO)
    ├── settings.json          ← Definicoes, hooks
    ├── commands/              ← 24 slash commands
    │   ├── debug.md           ← /debug — depuracao sistematica
    │   ├── plan.md            ← /plan — planeamento antes de programar
    │   ├── verify.md          ← /verify — verificacao pre-commit
    │   ├── audit.md           ← /audit — auditoria de seguranca/desempenho
    │   ├── test.md            ← /test — escrita de testes
    │   └── ...                ← ~19 mais comandos
    ├── prompts/               ← Templates de auditoria
    ├── agents/                ← Sub-agentes (code-reviewer, test-writer)
    ├── skills/                ← Especialidade em frameworks
    ├── cheatsheets/           ← Cheatsheets (9 linguagens)
    ├── memory/                ← Memoria entre sessoes
    └── scratchpad/            ← Notas de trabalho
```

**Para especificar o framework explicitamente:**

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh) laravel
```

---

## Passo 4: Configurar o CLAUDE.md para o Seu Projeto

Este e o ficheiro mais importante. Abra `.claude/CLAUDE.md` no seu editor e preencha-o:

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

O Claude **le este ficheiro a cada inicio** neste projeto. Quanto melhor o preencher — mais inteligente o Claude sera.

---

## Passo 5: Fazer Commit de .claude no Git

```bash
git add .claude/
git commit -m "feat: add Claude Code toolkit configuration"
```

Agora a configuracao esta guardada no repositorio. Se clonar o projeto noutra maquina — o toolkit ja estara la.

---

## Passo 6: Iniciar o Claude Code e Trabalhar

```bash
claude
```

O Claude Code inicia e carrega automaticamente:

1. **Global** `~/.claude/CLAUDE.md` (regras de seguranca — do Passo 1)
2. **Projeto** `.claude/CLAUDE.md` (as suas instrucoes — do Passo 4)
3. Todos os comandos de `.claude/commands/`

Agora pode trabalhar:

```text
> Create a REST API for product management: CRUD, pagination, search
```

---

## Comandos Uteis Dentro do Claude Code

| Comando | O Que Faz |
|---------|-----------|
| `/plan` | Pensar primeiro, programar depois (Pesquisa → Plano → Execucao) |
| `/debug problema` | Depuracao sistematica em 4 fases |
| `/audit security` | Auditoria de seguranca |
| `/audit` | Revisao de codigo |
| `/verify` | Verificacao pre-commit (build + lint + testes) |
| `/test` | Escrever testes |
| `/learn` | Guardar solucao de problema para referencia futura |
| `/helpme` | Cheatsheet de todos os comandos |

---

## Visao Geral Visual — O Caminho Completo

```text
┌─────────────────────────────────────────────────────┐
│  UMA VEZ POR MAQUINA (Passo 1)                      │
│                                                     │
│  Terminal:                                          │
│  $ bash <(curl ... setup-security.sh)                │
│                                                     │
│  Resultado:                                         │
│  ~/.claude/CLAUDE.md      ← regras de seguranca     │
│  ~/.claude/settings.json  ← hook combinado + plugins │
│  ~/.claude/hooks/pre-bash.sh ← safety-net + RTK     │
│  cc-safety-net            ← npm package             │
└─────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  PARA CADA PROJETO (Passos 2-5)                     │
│                                                     │
│  Terminal:                                          │
│  $ cd ~/Projects/my-app                             │
│  $ bash <(curl ... init-claude.sh)                   │
│  $ # editar .claude/CLAUDE.md                       │
│  $ git add .claude/ && git commit                   │
│                                                     │
│  Resultado:                                         │
│  .claude/                 ← comandos, skills,       │
│                              prompts, agentes       │
└─────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  TRABALHO (Passo 6)                                  │
│                                                     │
│  $ claude                                           │
│  > /plan add authentication                         │
│  > /debug why 500 on /api/users                     │
│  > /verify                                          │
│  > /audit security                                  │
└─────────────────────────────────────────────────────┘
```

---

## Atualizar o Toolkit

Quando novos comandos ou templates sao lancados:

```bash
cd ~/Projects/my-app
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/update-claude.sh)
```

Ou dentro do Claude Code:

```text
> /install
```

---

## Resolucao de Problemas

| Problema | Solucao |
|----------|---------|
| `cc-safety-net: command not found` | Execute `npm install -g cc-safety-net` |
| Toolkit nao detetado pelo Claude | Verifique que `.claude/CLAUDE.md` existe na raiz do projeto |
| Comandos nao disponiveis | Execute novamente `init-claude.sh` ou verifique a pasta `.claude/commands/` |
| Safety-net bloqueia um comando legitimo | Execute o comando manualmente no terminal fora do Claude Code |
| RTK nao reescreve os comandos | Certifique-se de ter um unico hook combinado em settings.json, nao hooks separados |
