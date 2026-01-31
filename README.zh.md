# Claude Guides

Claude Code AI 辅助开发的综合指南。

[![Quality Check](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](README.md)** | **[Русский](README.ru.md)** | **[Español](README.es.md)** | **[Deutsch](README.de.md)** | **[Français](README.fr.md)** | **中文** | **[日本語](README.ja.md)** | **[Português](README.pt.md)** | **[한국어](README.ko.md)**

> **第一次使用 Claude Code？** 请先阅读[分步安装指南](howto/zh.md)。

---

## 适用人群

**独立开发者**使用 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 构建产品。

支持的技术栈：**Laravel/PHP**、**Next.js**、**Node.js**、**Python**、**Go**、**Ruby on Rails**。

没有团队意味着没有代码审查，没有人可以咨询架构问题，没有人检查安全性。本仓库填补了这些空白：

| 问题 | 解决方案 |
|---------|----------|
| Claude 每次都忘记规则 | `CLAUDE.md` — 会话开始时读取的指令 |
| 没有人可以咨询 | `/debug` — 系统化调试而非猜测 |
| 没有代码审查 | `/audit code` — Claude 根据检查清单审查代码 |
| 没有安全审查 | `/audit security` — SQL 注入、XSS、CSRF、认证检查 |
| 部署前忘记检查 | `/verify` — 构建、类型、lint、测试一键完成 |

**内容概览：** 24 个命令，7 种审计，23+ 指南，所有主流技术栈模板。

---

## 快速开始

### 首次安装

告诉 Claude Code：

```text
Download instructions from https://github.com/digitalplanetno/claude-code-toolkit
```

或在终端运行：

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

脚本会自动检测框架（Laravel、Next.js）并复制相应模板。

### 安装后

使用 `/install` 命令重新安装或更新：

```text
/install          # 自动检测框架
/install laravel  # 强制使用 Laravel
/install nextjs   # 强制使用 Next.js
/install nodejs   # 强制使用 Node.js
/install python   # 强制使用 Python
/install go       # 强制使用 Go
/install rails    # 强制使用 Rails
```

或通过终端更新：

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/update-claude.sh | bash
```

---

## 核心功能

### 1. 自学习系统

Claude 从您的纠正中学习并积累项目知识。

**两种机制：**

| 机制 | 作用 | 使用场景 |
|-----------|--------------|-------------|
| `/learn` | 保存**一次性**问题解决方案 | 解决了非常规问题，找到了变通方法 |
| **技能积累** | 积累**重复出现的**模式 | Claude 注意到被纠正了 2 次以上 |

**区别：**

```text
/learn  → "我如何解决问题 X"     (一次性修复)
skill   → "我们总是这样做 Y"      (项目模式)
```

**/learn 示例：**

```text
> /learn

分析会话...
发现：Prisma Serverless 连接修复

问题：Vercel Edge Functions 中连接超时
解决方案：在 DATABASE_URL 中添加 ?connection_limit=1

保存到 .claude/learned/prisma-serverless.md? → yes
```

**技能积累示例：**

```text
用户：创建用户端点
Claude：[创建端点]
用户：不对，我们使用 Zod 进行验证，AppError 处理错误

Claude：发现模式：端点使用 Zod + AppError
        保存为技能 'backend-endpoints'？
        触发条件：endpoint, api, route

用户：是

[下次 Claude 直接使用 Zod + AppError]
```

### 2. 自动激活钩子

**问题：** 您有 10 个技能，但忘记使用它们。

**解决方案：** 钩子在发送给 Claude **之前**拦截提示并推荐加载技能。

```text
用户提示 → 钩子分析 → 评分 → 推荐
```

**评分系统：**

| 触发器 | 分数 | 示例 |
|---------|--------|---------|
| 关键词 | +2 | 提示中的 "endpoint" |
| 意图模式 | +4 | "create.*endpoint" |
| 路径模式 | +5 | 打开的文件 `src/api/*` |

**示例：**

```text
提示："create POST endpoint for registration"
文件：src/api/auth.controller.ts

⚠️ 技能推荐：
🟢 [高] backend-dev (分数: 13)
🟢 [高] security-review (分数: 12)

👉 使用 Skill 工具加载指南。
```

### 3. 记忆持久化

**问题：** MCP 记忆存储在本地。换一台电脑——记忆丢失。

**解决方案：** 导出到 `.claude/memory/` → 提交到 git → 随处可用。

```text
.claude/memory/
├── knowledge-graph.json   # 组件关系
├── project-context.md     # 项目上下文
└── decisions-log.md       # 为什么做出决策 X
```

**工作流程：**

```text
会话开始时：    检查同步 → 从 MCP 加载记忆
更改后：        导出 → 提交 .claude/memory/
在新电脑上：    拉取 → 导入到 MCP
```

### 4. 系统化调试 (/debug)

**铁律：**

```text
没有根本原因调查就不要修复
```

**4 个阶段：**

| 阶段 | 做什么 | 退出标准 |
|-------|------------|---------------|
| **1. 根因** | 阅读错误，复现，追踪数据流 | 理解是什么和为什么 |
| **2. 模式** | 找到工作示例，比较 | 找到差异 |
| **3. 假设** | 形成理论，测试一个更改 | 已确认 |
| **4. 修复** | 写测试，修复，验证 | 测试通过 |

**三次修复规则：**

```text
如果 3 次以上修复都没用——停下来！
这不是 bug。这是架构问题。
```

### 5. 结构化工作流

**问题：** Claude 经常"直接写代码"而不是先理解任务。

**解决方案：** 3 个阶段，有明确限制：

| 阶段 | 权限 | 允许的操作 |
|-------|--------|----------------|
| **研究** | 只读 | Glob, Grep, Read — 理解上下文 |
| **计划** | 仅草稿本 | 在 `.claude/scratchpad/` 中写计划 |
| **执行** | 完全权限 | 仅在计划确认后 |

```text
用户：添加邮箱验证

Claude：阶段 1：研究
        [读取文件，搜索模式]
        发现：表单在 RegisterForm.tsx，通过 Zod 验证

        阶段 2：计划
        [在 .claude/scratchpad/current-task.md 中创建计划]
        计划就绪。确认后继续。

用户：ok

Claude：阶段 3：执行
        步骤 1：添加 schema... ✅
        步骤 2：集成到表单... ✅
        步骤 3：测试... ✅
```

---

## 安装后的结构

```text
your-project/
└── .claude/
    ├── CLAUDE.md              # 主要指令（根据项目调整）
    ├── settings.json          # 钩子、权限
    ├── commands/              # 斜杠命令
    │   ├── verify.md
    │   ├── debug.md
    │   └── ...
    ├── prompts/               # 审计
    │   ├── SECURITY_AUDIT.md
    │   ├── PERFORMANCE_AUDIT.md
    │   ├── CODE_REVIEW.md
    │   ├── DESIGN_REVIEW.md
    │   ├── MYSQL_PERFORMANCE_AUDIT.md
    │   └── POSTGRES_PERFORMANCE_AUDIT.md
    ├── agents/                # 子代理
    │   ├── code-reviewer.md
    │   ├── test-writer.md
    │   └── planner.md
    ├── skills/                # 框架专业知识
    │   └── [framework]/SKILL.md
    ├── scratchpad/            # 工作笔记
    └── memory/                # MCP 记忆导出
```

---

## 内容详情

### 模板（7 种选择）

| 模板 | 用途 | 特点 |
|----------|----------|----------|
| `base/` | 任何项目 | 通用规则 |
| `laravel/` | Laravel + Vue/Inertia | Eloquent, migrations, Blade, Pint |
| `nextjs/` | Next.js + TypeScript | App Router, RSC, Tailwind |
| `nodejs/` | Node.js + TypeScript | Express/Fastify, ESM, Testing |
| `python/` | Python | FastAPI, Django, Poetry/UV |
| `go/` | Go | 标准库、模块、测试 |
| `rails/` | Ruby on Rails + Hotwire | ActiveRecord, Turbo, Stimulus, RSpec |

### 斜杠命令（共 24 个）

| 命令 | 描述 |
|---------|-------------|
| `/verify` | 提交前检查：构建、类型、lint、测试 |
| `/debug [problem]` | 4 阶段调试：根因 → 假设 → 修复 → 验证 |
| `/learn` | 保存问题解决方案到 `.claude/learned/` |
| `/plan` | 实现前在草稿本中创建计划 |
| `/audit [type]` | 运行审计（安全、性能、代码、设计、数据库） |
| `/test` | 为模块编写测试 |
| `/refactor` | 保持行为的重构 |
| `/fix [issue]` | 修复特定问题 |
| `/explain` | 解释代码如何工作 |
| `/doc` | 生成文档 |
| `/context-prime` | 会话开始时加载项目上下文 |
| `/checkpoint` | 保存进度到草稿本 |
| `/handoff` | 准备任务交接（摘要 + 下一步） |
| `/worktree` | Git worktrees 管理 |
| `/install` | 安装 claude-guides 到项目 |
| `/migrate` | 数据库迁移辅助 |
| `/find-function` | 按名称/描述查找函数 |
| `/find-script` | 在 package.json/composer.json 中查找脚本 |
| `/tdd` | 测试驱动开发工作流 |
| `/docker` | Docker 配置和优化 |
| `/api` | API 设计和端点创建 |
| `/e2e` | 端到端测试设置 |
| `/perf` | 性能分析和优化 |
| `/deps` | 依赖管理和更新 |

### 审计（7 种类型）

| 审计 | 文件 | 检查内容 |
|-------|------|----------------|
| **安全** | `SECURITY_AUDIT.md` | SQL 注入、XSS、CSRF、认证、密钥 |
| **性能** | `PERFORMANCE_AUDIT.md` | N+1、bundle 大小、缓存、懒加载 |
| **代码审查** | `CODE_REVIEW.md` | 模式、可读性、SOLID、DRY |
| **设计审查** | `DESIGN_REVIEW.md` | UI/UX、可访问性、响应式（Playwright MCP） |
| **MySQL** | `MYSQL_PERFORMANCE_AUDIT.md` | performance_schema、索引、慢查询 |
| **PostgreSQL** | `POSTGRES_PERFORMANCE_AUDIT.md` | pg_stat_statements、膨胀、连接 |
| **部署** | `DEPLOY_CHECKLIST.md` | 部署前检查清单 |

### 组件（23+ 指南）

| 组件 | 描述 |
|-----------|-------------|
| `structured-workflow.md` | 3 阶段方法：研究 → 计划 → 执行 |
| `smoke-tests-guide.md` | 最小 API 测试（Laravel/Next.js/Node.js） |
| `hooks-auto-activation.md` | 根据提示上下文自动激活技能 |
| `skill-accumulation.md` | 自学习：Claude 积累项目知识 |
| `modular-skills.md` | 大型指南的渐进式披露 |
| `spec-driven-development.md` | 先规范后代码 |
| `mcp-servers-guide.md` | 推荐的 MCP 服务器 |
| `memory-persistence.md` | MCP 记忆与 Git 同步 |
| `plan-mode-instructions.md` | 思考级别：think → think hard → ultrathink |
| `git-worktrees-guide.md` | 分支并行工作 |
| `devops-highload-checklist.md` | 高负载项目检查清单 |
| `api-health-monitoring.md` | API 端点监控 |
| `bootstrap-workflow.md` | 新项目工作流 |
| `github-actions-guide.md` | GitHub Actions CI/CD 配置 |
| `pre-commit-hooks.md` | 预提交钩子设置 |
| `deployment-strategies.md` | 部署策略和最佳实践 |

---

## MCP 服务器（推荐！）

| 服务器 | 用途 |
|--------|---------|
| `context7` | 库文档 |
| `playwright` | 浏览器自动化，UI 测试 |
| `memory-bank` | 会话间记忆 |
| `sequential-thinking` | 逐步问题解决 |
| `memory` | 知识图谱（关系图） |

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add playwright -- npx @playwright/mcp@latest
```

---

## Rate Limit Statusline (Claude Max / Pro)

直接在 Claude Code 状态栏中监控 API 使用限额。

```text
25% | 5h:23% (2h57m) | 7d:80% (1d18h)
 │      │      │          │       │
 │      │      │          │       └─ 周限额重置倒计时
 │      │      │          └─ 周使用量（7天窗口）
 │      │      └─ 会话重置倒计时
 │      └─ 会话使用量（5小时窗口）
 └─ 上下文窗口使用量
```

**颜色编码：** 无色（<60%）、黄色（60-79%）、红色（80-89%）、亮红色（90-100%）

**要求：** macOS、`jq`、带 OAuth 的 Claude Code（Max 或 Pro 订阅）

### 安装

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/install-statusline.sh | bash
```

安装器会检查依赖、下载脚本到 `~/.claude/`、配置 `settings.json` 并运行初始检测。

详情和自定义：[components/rate-limit-statusline.md](components/rate-limit-statusline.md)。

---

## 使用示例

### /verify — 提交前检查

```text
> /verify

运行检查...
✅ 构建：通过
✅ TypeScript：无错误
⚠️ ESLint：2 个警告（未使用的导入）
✅ 测试：23 个通过

建议：提交前修复 lint 警告。
```

### /debug — 系统化调试

```text
> /debug API 在 /api/users 返回 500

阶段 1：根因分析
├── 读取 app/api/users/route.ts
├── 检查日志
└── 发现：prisma.user.findMany() 没有 try/catch

阶段 2：假设
└── 冷启动时数据库连接超时

阶段 3：修复
└── 添加错误处理 + 重试逻辑

阶段 4：验证
└── 测试端点 — 正常工作
```

### /audit security — 安全审计

```text
> /audit security

安全审计报告
=====================

🔴 严重 (1)
├── UserController:45 中的 SQL 注入
└── 建议：使用预处理语句

🟡 中等 (2)
├── /api/login 没有速率限制
└── CORS 配置为 Access-Control-Allow-Origin: *

🟢 低 (1)
└── .env.example 中的调试模式
```

---

## 支持的框架

| 框架 | 模板 | 技能 | 自动检测 |
|-----------|----------|--------|----------------|
| Laravel | ✅ 专用 | ✅ | `artisan` 文件 |
| Next.js | ✅ 专用 | ✅ | `next.config.*` |
| Node.js | ✅ 专用 | ✅ | `package.json`（无 next.config） |
| Python | ✅ 专用 | ✅ | `pyproject.toml` / `requirements.txt` |
| Go | ✅ 专用 | ✅ | `go.mod` |
| Ruby on Rails | ✅ 专用 | ✅ | `bin/rails` / `config/application.rb` |
