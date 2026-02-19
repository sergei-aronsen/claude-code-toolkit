# Claude Guides — Referencia Rapida

## Comandos

| Comando | O que faz |
|---------|----------|
| `/plan` | Criar plano de implementacao antes de codificar |
| `/debug` | Depuracao sistematica (4 fases) |
| `/verify` | Verificacao pre-commit: build, types, lint, testes |
| `/audit` | Auditoria: security, performance, code, design, db |
| `/test` | Escrever testes para um modulo |
| `/tdd` | Test-Driven Development: testes primeiro, codigo depois |
| `/fix` | Corrigir um problema especifico |
| `/refactor` | Melhorar estrutura sem alterar comportamento |
| `/explain` | Explicar como o codigo ou arquitetura funciona |
| `/doc` | Gerar documentacao |
| `/learn` | Salvar solucao em `.claude/learned/` para sessoes futuras |
| `/context-prime` | Carregar contexto do projeto no inicio da sessao |
| `/checkpoint` | Salvar progresso no scratchpad |
| `/handoff` | Preparar transferencia de tarefa com resumo e proximos passos |
| `/install` | Instalar claude-guides no projeto |
| `/worktree` | Gerenciar git worktrees para branches paralelas |
| `/migrate` | Criar ou depurar migracoes de banco de dados |
| `/find-function` | Encontrar definicao de funcao ou classe |
| `/find-script` | Encontrar scripts em package.json, Makefile, etc. |
| `/docker` | Gerar Dockerfile e docker-compose |
| `/api` | Projetar REST API, gerar spec OpenAPI |
| `/e2e` | Gerar testes E2E com Playwright |
| `/perf` | Analise de performance: N+1, bundle, memoria |
| `/deps` | Auditoria de dependencias: seguranca, licencas, desatualizadas |

---

## Agentes

Agentes para analise profunda e focada:

| Agente | Como chamar | Proposito |
|--------|------------|----------|
| Code Reviewer | `/agent:code-reviewer` | Revisao de codigo contra checklist |
| Test Writer | `/agent:test-writer` | Geracao de testes com abordagem TDD |
| Planner | `/agent:planner` | Dividir tarefa em plano com fases |
| Security Auditor | `/agent:security-auditor` | Analise profunda de seguranca |

---

## Auditorias

Executar com `/audit {tipo}`:

| Tipo | O que verifica |
|------|---------------|
| `security` | Injecao SQL, XSS, CSRF, auth, segredos |
| `performance` | Consultas N+1, cache, lazy loading, tamanho do bundle |
| `code` | Padroes, legibilidade, SOLID, DRY |
| `design` | UI/UX, acessibilidade, responsivo |
| `mysql` | Indices, consultas lentas, performance_schema |
| `postgres` | pg_stat_statements, bloat, conexoes |
| `deploy` | Checklist pre-deploy |

---

## Skills

Skills ativam automaticamente com base no contexto:

| Skill | Quando ativa |
|-------|-------------|
| Database | Migracoes, indices, consultas |
| API Design | Endpoints REST, OpenAPI, codigos de status |
| Docker | Conteineres, Dockerfile, Compose |
| Testing | Testes, mocks, cobertura |
| Tailwind | Estilos CSS, design responsivo |
| Observability | Logging, metricas, tracing |
| LLM Patterns | RAG, embeddings, streaming |
| AI Models | Selecao de modelo, precos, janelas de contexto |

---

## Fluxo de Trabalho

### Tres Fases (obrigatorio)

```text
RESEARCH (somente leitura) --> PLAN (somente scratchpad) --> EXECUTE (acesso completo)
```

### Niveis de Pensamento

| Nivel | Quando usar |
|-------|------------|
| `think` | Tarefas simples, correcoes rapidas |
| `think hard` | Features multi-etapas, refatoracao |
| `ultrathink` | Decisoes de arquitetura, debug complexo |

---

## Cenarios — Quando Usar o Que

### Encontrei um bug

```text
/debug descricao do bug
```

Claude investiga a causa raiz antes de corrigir. Apos o fix: `/verify`

### Preciso de code review

```text
/audit code
```

Para revisao completa: `/audit security`, depois `/audit performance`

### Quero adicionar uma nova feature

```text
/plan descricao da feature
```

Claude cria um plano no scratchpad. Apos aprovacao, executa. Depois: `/verify`

### Preciso escrever testes

```text
/tdd nome_modulo
```

Primeiro escreve testes que falham, depois codigo minimo para passa-los.

### Antes do deploy

```text
/verify
/audit security
/audit deploy
```

Os tres para detectar problemas antes da producao.

### Iniciando nova sessao

```text
/context-prime
```

Carrega o contexto do projeto para que Claude entenda a base de codigo.

### Transferir tarefa para outro desenvolvedor

```text
/handoff
```

Cria resumo: o que foi feito, estado atual, proximos passos.

### Refatorar com seguranca

```text
/refactor codigo_alvo
```

Claude refatora preservando comportamento. Sempre executa testes depois.

### Entender codigo desconhecido

```text
/explain path/to/file.ts
/explain fluxo de autenticacao
```

### Trabalho com banco de dados

```text
/migrate criar tabela users
/audit mysql
/audit postgres
```

### Problemas de performance

```text
/perf
/audit performance
```

### Verificar dependencias

```text
/deps
```

### Preciso de REST API

```text
/api projetar endpoints para users
```

### Configurar Docker

```text
/docker
```

### Testes E2E

```text
/e2e registro e login de usuario
```

---

## Servidores MCP

| Servidor | Proposito |
|----------|----------|
| context7 | Documentacao atualizada de bibliotecas |
| playwright | Automacao de navegador, testes UI, capturas |
| sequential-thinking | Resolucao passo a passo |

---

## Dicas Rapidas

- Sempre use `/plan` antes de features grandes — previne esforco desperdicado
- Execute `/verify` antes de cada commit — detecta problemas cedo
- Use `/learn` apos resolver problemas complexos — salva conhecimento para o futuro
- Inicie sessoes com `/context-prime` — Claude trabalha melhor com contexto
- Use `/checkpoint` em tarefas longas — progresso salvo se a sessao cair
- `/debug` e melhor que "tentar corrigir" — abordagem sistematica e mais rapida
