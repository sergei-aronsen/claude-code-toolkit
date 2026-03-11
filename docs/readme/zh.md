# Claude Code Toolkit

使用 Claude Code 进行 AI 辅助开发的综合指南。

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](../../README.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **中文** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

> 请先阅读完整的[分步安装指南](../howto/zh.md)。

---

## 适用人群

**独立开发者**使用 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 构建产品。

支持的技术栈：**Laravel/PHP**、**Ruby on Rails**、**Next.js**、**Node.js**、**Python**、**Go**。

**7 个模板**（基础、Laravel、Rails、Next.js、Node.js、Python、Go）

**29 个斜杠命令** | **7 种审计** | **30 指南** | 查看[命令、模板、审计和组件的完整列表](../features.md#slash-commands-29-total)。

---

## 快速开始

### 1. 全局设置（仅需一次）

#### a) Security Pack

纵深防御安全设置。完整指南请参阅 [components/security-hardening.md](../../components/security-hardening.md)。

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh | bash
```

#### b) RTK — Token 优化器（推荐）

[RTK](https://github.com/rtk-ai/rtk) 在开发命令（`git status`、`cargo test` 等）上减少 60-90% 的 Token 消耗。

```bash
brew install rtk
rtk init -g
```

> **注意：** Security Pack（步骤 1a）已配置组合钩子，按顺序运行 safety-net 和 RTK。
> 详情请参阅 [components/security-hardening.md](../../components/security-hardening.md)。

#### c) Rate Limit Statusline（Claude Max / Pro，可选）

在 Claude Code 状态栏中显示会话/周限额。更多信息：[components/rate-limit-statusline.md](../../components/rate-limit-statusline.md)

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-statusline.sh | bash
```

### 2. 安装（每个项目）

安装程序将：

- 让你**选择技术栈**（推荐自动检测）
- 安装工具包（命令、代理、提示、技能）
- 设置 **Supreme Council**（Gemini + ChatGPT 多AI审查）
- 引导你完成 API 密钥配置

在项目文件夹的终端中运行：

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

**重启 Claude！** 后续更新请使用 `/update-toolkit` 命令。

---

## 核心亮点

| 功能 | 描述 |
|---------|-------------|
| **自学习** | `/learn` 保存一次性解决方案；技能积累自动捕获重复出现的模式 |
| **自动激活钩子** | 钩子拦截提示，评估上下文（关键词、意图、文件路径），推荐相关技能 |
| **知识持久化** | 项目事实存储在 `.claude/rules/` — 每次会话自动加载，提交到 git，在任何机器上可用 |
| **系统化调试** | `/debug` 强制执行 4 个阶段：根因 → 模式 → 假设 → 修复。不靠猜测 |
| **生产安全** | `/deploy` 带预/后检查，`/fix-prod` 用于热修复，增量部署 |
| **Supreme Council** | `/council` 将计划发送给 Gemini + ChatGPT，在编码前进行独立审查 |
| **结构化工作流** | 3 个必经阶段：研究（只读） → 计划（草稿本） → 执行（确认后） |

查看[详细描述和示例](../features.md)。

---

## MCP 服务器（推荐！）

| 服务器 | 用途 |
|--------|---------|
| `context7` | 库文档 |
| `playwright` | 浏览器自动化，UI 测试 |
| `sequential-thinking` | 逐步问题解决 |

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add playwright -- npx @playwright/mcp@latest
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
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

## 支持的框架

| 框架 | 模板 | 技能 | 自动检测 |
|-----------|----------|--------|----------------|
| Laravel | ✅ | ✅ | `artisan` 文件 |
| Ruby on Rails | ✅ | ✅ | `bin/rails` / `config/application.rb` |
| Next.js | ✅ | ✅ | `next.config.*` |
| Node.js | ✅ | ✅ | `package.json`（不含 next.config） |
| Python | ✅ | ✅ | `pyproject.toml` / `requirements.txt` |
| Go | ✅ | ✅ | `go.mod` |
