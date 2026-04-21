# Claude Code Toolkit

使用 Claude Code 进行 AI 辅助开发的综合指南。

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](../../README.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **中文** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

> 请先阅读完整的[分步安装指南](../howto/zh.md)。

---

## 适用人群

使用 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 构建产品的**独立开发者**。

支持的技术栈：**Laravel/PHP**、**Ruby on Rails**、**Next.js**、**Node.js**、**Python**、**Go**。

**30 个斜杠命令** | **7 种审计** | **29 个指南** | 查看[命令、模板、审计和组件的完整列表](../features.md#slash-commands-30-total)。

---

## 快速开始

### 1. 全局设置（仅需一次）

#### a) Security Pack

纵深防御安全设置。完整指南请参阅 [components/security-hardening.md](../../components/security-hardening.md)。

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)
```

#### b) RTK — Token 优化器（推荐）

[RTK](https://github.com/rtk-ai/rtk) 在开发命令（`git status`、`cargo test` 等）上减少 60-90% 的 Token 消耗。

```bash
brew install rtk
rtk init -g
```

> **注意：** 如果 RTK 和 cc-safety-net 是独立的钩子，它们的结果会冲突。
> Security Pack（步骤 1a）已配置组合钩子，按顺序运行两者。
> 详情请参阅 [components/security-hardening.md](../../components/security-hardening.md)。

#### c) Rate Limit Statusline（Claude Max / Pro，可选）

在 Claude Code 状态栏中显示会话/周限额。更多信息：[components/rate-limit-statusline.md](../../components/rate-limit-statusline.md)

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-statusline.sh)
```

## 安装模式

TK 会自动检测是否安装了 `superpowers`（obra）和 `get-shit-done`（gsd-build），并
选择四种模式之一：`standalone`、`complement-sp`、`complement-gsd` 或 `complement-full`。
每个框架模板在 `## Required Base Plugins` 中说明所需的基础插件 — 例如
[templates/base/CLAUDE.md](../../templates/base/CLAUDE.md)。完整的 12 格安装矩阵
和分步说明请参阅 [docs/INSTALL.md](../INSTALL.md)。

### 独立安装

您未安装 `superpowers` 或 `get-shit-done`（或已明确选择不使用）。
TK 将安装全部 54 个文件 — 完整的默认配置。在常规终端（不是在
Claude Code 内部！）中，从项目文件夹运行：

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
```

然后在该项目目录中启动 Claude Code。后续更新请使用 `/update-toolkit`。

### 补充安装

您已安装 `superpowers`（obra）和/或 `get-shit-done`（gsd-build）中的一个或两个。TK
会自动检测并跳过与 SP 功能重复的 7 个文件，保留约 47 个 TK 独有贡献
（Council、框架 CLAUDE.md 模板、组件库、cheatsheets、框架专属技能）。
使用相同的安装命令 — TK 自动选择 `complement-*` 模式。如需覆盖，可传入
`--mode standalone`（或其他模式名称）：

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh) --mode complement-full
```

### 从 v3.x 升级

在安装 TK 后再安装 SP 或 GSD 的 v3.x 用户，应运行 `scripts/migrate-to-complement.sh` 以
逐文件确认的方式删除重复文件，并在迁移前进行完整备份。完整的 12 格矩阵和分步说明请参阅
[docs/INSTALL.md](../INSTALL.md)。

> **重要：** 项目模板仅适用于 `project/.claude/CLAUDE.md`。请勿将其复制到
> `~/.claude/CLAUDE.md` — 该文件应仅包含全局安全规则和个人偏好设置（不超过 50 行）。
> 详情请参阅 [components/claude-md-guide.md](../../components/claude-md-guide.md)。

---

## 核心亮点

| 功能 | 描述 |
|------|------|
| **自学习** | `/learn` 将解决方案保存为带 `globs:` 的规则文件 — 仅对相关文件自动加载 |
| **自动激活钩子** | 钩子拦截提示，评估上下文（关键词、意图、文件路径），推荐相关技能 |
| **知识持久化** | 项目事实存储在 `.claude/rules/` — 每次会话自动加载，提交到 git，在任何机器上可用 |
| **系统化调试** | `/debug` 强制执行 4 个阶段：根因 → 模式 → 假设 → 修复。不靠猜测 |
| **生产安全** | `/deploy` 带预/后检查，`/fix-prod` 用于热修复，增量部署，worker 安全 |
| **Supreme Council** | `/council` 将计划发送给 Gemini + ChatGPT，在编码前进行独立审查 |
| **结构化工作流** | 3 个必经阶段：研究（只读） → 计划（草稿本） → 执行（确认后） |

查看[详细描述和示例](../features.md)。

---

## MCP 服务器（推荐！）

### 全局（所有项目）

| 服务器 | 用途 |
|--------|------|
| `context7` | 库文档 |
| `playwright` | 浏览器自动化、UI 测试 |
| `sequential-thinking` | 逐步问题解决 |
| `sentry` | 错误监控与问题排查 |

```bash
claude mcp add -s user context7 -- npx -y @upstash/context7-mcp
claude mcp add -s user playwright -- npx @playwright/mcp@latest --browser chromium
claude mcp add -s user sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp
```

### 每个项目（凭据）

| 服务器 | 用途 |
|--------|------|
| `dbhub` | 通用数据库访问（PostgreSQL、MySQL、MariaDB、SQL Server、SQLite） |

```bash
claude mcp add dbhub -- npx -y @bytebase/dbhub --dsn "postgresql://user:pass@localhost:5432/dbname"
```

> **安全：** 请始终使用**只读数据库用户** — 不要仅依赖 DBHub 应用层的 `--readonly` 标志（[已知绕过方式](https://github.com/bytebase/dbhub/issues/271)）。每个项目的服务器配置存入 `.claude/settings.local.json`（已加入 .gitignore，凭据安全）。完整详情请参阅 [mcp-servers-guide.md](../../components/mcp-servers-guide.md)。

---

## 安装后的结构

带 † 标记的文件与 `superpowers` 冲突 — 在 `complement-sp` 和 `complement-full` 模式下省略。

```text
your-project/
└── .claude/
    ├── CLAUDE.md              # 主要指令（根据项目调整）
    ├── settings.json          # 钩子、权限
    ├── commands/              # 斜杠命令
    │   ├── verify.md          # † 在 complement-sp/full 中省略
    │   ├── debug.md           # † 在 complement-sp/full 中省略
    │   └── ...
    ├── prompts/               # 审计
    │   ├── SECURITY_AUDIT.md
    │   ├── PERFORMANCE_AUDIT.md
    │   ├── CODE_REVIEW.md
    │   ├── DESIGN_REVIEW.md
    │   ├── MYSQL_PERFORMANCE_AUDIT.md
    │   └── POSTGRES_PERFORMANCE_AUDIT.md
    ├── agents/                # 子代理
    │   ├── code-reviewer.md   # † 在 complement-sp/full 中省略
    │   ├── test-writer.md
    │   └── planner.md
    ├── skills/                # 框架专业知识
    │   └── [framework]/SKILL.md
    ├── rules/                 # 自动加载的项目信息
    └── scratchpad/            # 工作笔记
```

---

## 支持的框架

| 框架 | 模板 | 技能 | 自动检测 |
|------|------|------|----------|
| Laravel | ✅ | ✅ | `artisan` 文件 |
| Ruby on Rails | ✅ | ✅ | `bin/rails` / `config/application.rb` |
| Next.js | ✅ | ✅ | `next.config.*` |
| Node.js | ✅ | ✅ | `package.json`（不含 next.config） |
| Python | ✅ | ✅ | `pyproject.toml` / `requirements.txt` |
| Go | ✅ | ✅ | `go.mod` |

---

## 组件

用于组合自定义 `CLAUDE.md` 文件的可复用 Markdown 片段。组件是仓库根目录的资源 —
它们**不会**安装到 `.claude/` 中；请通过绝对 GitHub URL 引用它们。

**编排模式** — 请参阅 [components/orchestration-pattern.md](../../components/orchestration-pattern.md)
了解 Council 和 GSD 工作流均采用的精简编排器 + 重量级子代理设计。
它可帮助任何自定义斜杠命令突破单个上下文窗口的限制。
