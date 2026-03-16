# Claude Guides — 快速参考

## 命令

| 命令 | 功能 |
|------|------|
| `/plan` | 编码前创建实施计划 |
| `/design` | 复杂功能的架构设计 |
| `/debug` | 系统化调试（4个阶段） |
| `/verify` | 提交前检查：构建、类型、lint、测试 |
| `/audit` | 审计：安全、性能、代码、设计、数据库 |
| `/test` | 为模块编写测试 |
| `/tdd` | 测试驱动开发：先写测试，再写代码 |
| `/fix` | 修复特定问题 |
| `/refactor` | 改善结构而不改变行为 |
| `/explain` | 解释代码或架构的工作原理 |
| `/doc` | 生成文档 |
| `/learn` | 将经验保存为 `.claude/rules/` 中的作用域规则文件（通过 globs 自动加载） |
| `/context-prime` | 会话开始时加载项目上下文 |
| `/checkpoint` | 将进度保存到暂存区 |
| `/handoff` | 准备任务交接，包含摘要和后续步骤 |
| `/update-toolkit` | 更新 Claude Code Toolkit |
| `/worktree` | 管理 git worktrees 以并行处理分支 |
| `/migrate` | 创建或调试数据库迁移 |
| `/find-function` | 查找函数或类定义 |
| `/find-script` | 在 package.json、Makefile 等中查找脚本 |
| `/docker` | 生成 Dockerfile 和 docker-compose |
| `/api` | 设计 REST API，生成 OpenAPI 规范 |
| `/e2e` | 使用 Playwright 生成端到端测试 |
| `/perf` | 性能分析：N+1、包大小、内存 |
| `/deps` | 依赖审计：安全性、许可证、过期版本 |
| `/deploy` | 安全部署：部署前后检查与验证 |
| `/fix-prod` | 生产热修复：诊断、修复、验证 |
| `/rollback-update` | 回滚工具包到上一版本 |
| `/council` | 多AI审查：Gemini + ChatGPT 实施前检查 |
| `/helpme` | 快速参考（9种语言） |

---

## 代理

用于深入、专注分析的代理：

| 代理 | 调用方式 | 用途 |
|------|---------|------|
| Code Reviewer | `/agent:code-reviewer` | 按检查清单审查代码 |
| Test Writer | `/agent:test-writer` | 使用 TDD 方法生成测试 |
| Planner | `/agent:planner` | 将任务分解为阶段计划 |
| Security Auditor | `/agent:security-auditor` | 深度安全分析 |

---

## 审计

通过 `/audit {类型}` 执行：

| 类型 | 检查内容 |
|------|---------|
| `security` | SQL注入、XSS、CSRF、认证、密钥 |
| `performance` | N+1查询、缓存、懒加载、包大小 |
| `code` | 模式、可读性、SOLID、DRY |
| `design` | UI/UX、无障碍性、响应式 |
| `mysql` | 索引、慢查询、performance_schema |
| `postgres` | pg_stat_statements、膨胀、连接 |
| `deploy` | 部署前检查清单 |

---

## 技能

技能根据上下文自动激活（关键词、文件模式）：

| 技能 | 激活时机 |
|------|---------|
| Database | 迁移、索引、查询 |
| API Design | REST 端点、OpenAPI、状态码 |
| Docker | 容器、Dockerfile、Compose |
| Testing | 测试、Mock、覆盖率 |
| Tailwind | CSS 样式、响应式设计 |
| Observability | 日志、指标、链路追踪 |
| LLM Patterns | RAG、嵌入、流式传输 |
| AI Models | 模型选择、定价、上下文窗口 |

---

## 工作流程

### 三个阶段（必须遵循）

```text
研究（只读）--> 计划（仅暂存区）--> 执行（完全访问）
```

### 思考级别

| 级别 | 使用场景 |
|------|---------|
| `think` | 简单任务、快速修复 |
| `think hard` | 多步骤功能、重构 |
| `ultrathink` | 架构决策、复杂调试 |

---

## 场景 — 何时使用什么

### 发现了 bug

```text
/debug bug 描述
```

Claude 先调查根本原因再修复。修复后：`/verify`

### 需要代码审查

```text
/audit code
```

完整审查：`/audit security`，然后 `/audit performance`

### 想添加新功能

```text
/plan 功能描述
```

Claude 在暂存区创建计划。批准后执行。然后：`/verify`

### 需要编写测试

```text
/tdd 模块名
```

先写失败的测试，然后写最少的代码使其通过。

### 部署前

```text
/verify
/audit security
/audit deploy
```

三个都运行，在问题到达生产环境前发现它们。

### 开始新会话

```text
/context-prime
```

加载项目上下文，让 Claude 从一开始就理解代码库。

### 交接任务给其他开发者

```text
/handoff
```

创建摘要：完成了什么、当前状态、后续步骤。

### 安全重构

```text
/refactor 目标代码
```

Claude 在保持行为的同时重构。之后总是运行测试。

### 理解陌生代码

```text
/explain path/to/file.ts
/explain 认证流程
```

### 数据库工作

```text
/migrate 创建 users 表
/audit mysql
/audit postgres
```

### 性能问题

```text
/perf
/audit performance
```

### 检查依赖

```text
/deps
```

### 需要 REST API

```text
/api 为 users 设计端点
```

### 配置 Docker

```text
/docker
```

### 端到端测试

```text
/e2e 用户注册和登录
```

---

## MCP 服务器

| 服务器 | 用途 |
|--------|------|
| context7 | 最新的库文档 |
| playwright | 浏览器自动化、UI 测试、截图 |
| sequential-thinking | 逐步问题解决 |

---

## 快速提示

- 大功能前始终使用 `/plan` — 防止浪费精力
- 每次提交前运行 `/verify` — 尽早发现问题
- 解决复杂问题后使用 `/learn` — 为未来会话保存知识
- 用 `/context-prime` 开始会话 — Claude 有上下文时工作更好
- 长任务中使用 `/checkpoint` — 会话中断时进度得以保存
- `/debug` 比"直接尝试修复"更好 — 系统化方法更快
