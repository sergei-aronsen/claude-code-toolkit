# Claude Code Toolkit

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-6.2.0-blue.svg)](../../CHANGELOG.md)

**[English](../../README.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **中文** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

---

## 这是什么

一个建立在 [**Superpowers**](https://github.com/obra/superpowers)（头脑风暴、子代理、TDD、调试）和 [**Get Shit Done**](https://github.com/gsd-build/get-shit-done)（Spec → Plan → Execute）之上的薄层覆盖，弥补这些插件为单兵开发者留下的空缺。

**面向：** 使用 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 交付真实产品的独立创始人和单人工程团队。

**支持的技术栈：** Laravel · Rails · Next.js · Node.js · Python · Go。

## 弥补哪些空缺

| 空缺                              | toolkit 增加了什么                                                                                                                              |
|-----------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------|
| **多 AI 计划验证**                | `/council` —— 把你的计划同时发给 Gemini 和 ChatGPT 做独立评审。可走 CLI（`gemini`、`codex`）或直接 API 密钥。Persona 叠加、按 hash 缓存、成本闸门、ru locale。 |
| **框架上下文**                    | 7 个现成 `CLAUDE.md` 模板（base + 6 个栈），通过 `artisan` / `next.config` / `go.mod` / `pyproject.toml` / `package.json` 自动检测。              |
| **生产安全网**                    | `cc-safety-net` 在 PreToolUse 拦截破坏性命令（`rm -rf /`、`git reset --hard` 等）—— 即使被混淆。已接入安装器。                                  |
| **Token 成本控制**                | RTK 重写冗长的开发命令输出（`git status`、测试运行器）—— 节省 60-90% token。与 `cc-safety-net` 共用合并 hook。                                   |
| **成本路由**                      | `better-model` 把简单任务路由到更便宜的模型。自动安装并集成进安装生命周期。                                                                       |
| **基于符号的代码搜索**            | [Serena](https://github.com/oraios/serena)（LSP，MIT，本地）+ ripgrep + claude-context（语义向量）。默认 Layer-3 检索栈。                       |
| **多 CLI 桥接**                   | 自动同步 `CLAUDE.md` 到 `GEMINI.md`（Gemini CLI）和 `AGENTS.md`（OpenAI Codex）。每次安装做漂移检测。                                            |
| **集成目录**                      | TUI 安装器，覆盖 24 个 MCP 服务器 + 8 个配套 CLI，分 10 个类别（Backend / Payments / Workspace / Project Management / …）。每行可选 scope。       |
| **额度可见性（Pro/Max）**         | Statusline 显示会话/周用量 —— 你能看到什么时候要撞墙。                                                                                          |
| **依赖看板（v6.2）**              | `/update-deps` —— 交互式 TUI 列出所有被追踪的依赖（Layer 1/2/3）和 installed-vs-latest。你挑选要更新的项。                                       |
| **安装后引导（v6.3）**            | 生成本地 HTML 页面 (`.claude/setup-guide.html`)，包含每个 MCP 的 API key 上手和组件配置 —— 只列你实际安装了的部分。                              |

核心价值是策展。一切都通过 TUI 复选框 opt-in —— 不强加任何东西。

## 安装

一条命令。在项目目录里的**普通终端**（不要在 Claude Code 内）执行：

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

安装器展示一个 TUI 检查列表（Toolkit、Security、RTK、Statusline、Council、Bridges、Integrations），并检测 `superpowers` 和 `get-shit-done` 是否已安装。如已安装，它会跳过那些插件已经提供的文件，只装 toolkit 独有的 ~47 项贡献。

Claude Desktop 用户 —— 通过 marketplace 安装：

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

完整分步指南：[docs/howto/zh.md](../howto/zh.md)。

## 安装后

| 命令               | 作用                                                                          |
|--------------------|-------------------------------------------------------------------------------|
| `/update-toolkit`  | 把最新 toolkit 内容拉到 `.claude/`，保留你的本地修改。                         |
| `/update-deps`     | 打开依赖看板（Layer 1/2/3 + MCP），选择要更新哪些。                           |
| `/council`         | 把方案发给 Gemini + ChatGPT 做独立评审。                                       |
| `/learn`           | 把当前决策保存为 scoped rule，供未来会话使用。                                 |
| `/audit`           | 运行 7 套框架感知审计中的一套（安全、性能等）。                                |
| `/debug`           | 4 阶段系统化调试器：root-cause → pattern → hypothesis → fix。                  |
| `/setup-guide`     | 重新生成本地 HTML 安装引导（针对已装 MCP/组件）。                              |

完整命令清单：[docs/features.md](../features.md)。

## 架构

Toolkit v6.2 是一个**薄层覆盖**，分三层：

- **Layer 1** —— toolkit 内容（模板、slash 命令、组件、skill、agent）
- **Layer 2** —— 免费基础插件（Superpowers、Get Shit Done、ru-text）
- **Layer 3** —— 可选外部工具（cc-safety-net、RTK、Serena、claude-context、better-model）

完整图：[docs/architecture.md](../architecture.md)。
独立创始人 / 非开发者：[docs/non-programmer-mode.md](../non-programmer-mode.md)。

## MCP 服务器目录

`--integrations` flag（或首次安装后用 `/integrations`）打开一个 TUI 检查列表，含 24 个服务器，分 10 类。你只挑项目需要的。

| 类别                   | 服务器                                                                                 |
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

每个服务器安装时按行选择 scope（`[U]` user / `[P]` project / `[L]` local）。project scope 把凭证写入 `<project>/.env`（mode 0600）并自动加 `.gitignore`；`.mcp.json` 只保留 `${VAR}` 替换形式。详情：[docs/INTEGRATIONS.md](../INTEGRATIONS.md)。

## 许可

MIT —— 见 [LICENSE](../../LICENSE)。
