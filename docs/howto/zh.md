# 安装与使用 Claude Code Toolkit

> 从零到 Claude Code 高效开发的完整路径，集中在一处。

**[English](en.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **中文** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

---

## 前置条件

确认已安装：

- **Node.js** —— `node --version`（建议 20.x 或更新）
- **Claude Code** —— `claude --version`
- **git** —— 把 `.claude/` 提交到仓库
- **jq** —— 安装器需要它来合并 `settings.json`（`brew install jq` / `apt install jq`）

如果 Claude Code 还没装：

```bash
npm install -g @anthropic-ai/claude-code
```

---

## 安装

`cd` 到项目目录里的**普通终端**（不要在 Claude Code 内）执行：

```bash
cd ~/Projects/my-app
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

安装器打开一个 TUI 检查列表，列出所有组件：

```text
[x] toolkit              ← toolkit 内容（项目里的 .claude/）
[x] security             ← 全局 security pack + cc-safety-net
[ ] rtk                  ← 重写冗长的开发命令输出（-60-90% token）
[ ] statusline           ← 状态栏显示会话/周用量
[ ] council              ← /council = Gemini + ChatGPT 计划验证
[ ] gemini-bridge        ← 自动同步 CLAUDE.md → GEMINI.md
[ ] codex-bridge         ← 自动同步 CLAUDE.md → AGENTS.md
[ ] mcp-servers (24)     ← 集成 TUI 检查列表（Stripe、Sentry、dbhub、…）
[ ] skills (22)          ← marketplace skill（i18n、shadcn、stripe、…）
```

`空格`切换、`↑/↓`移动、`回车`安装已勾选项。

安装器按特征文件检测你的框架（Laravel、Next.js、Python、Go 等）并提供匹配的 `CLAUDE.md` 模板。如果 `superpowers` 和 `get-shit-done` 已安装，toolkit 会跳过那些插件已经提供的文件，只装 toolkit 独有的 ~47 项贡献。

完成后会自动打开本地 HTML 页面 `.claude/setup-guide.html`，包含每个已装 MCP 的分步说明（去哪拿 API key、要设哪个 env 变量、如何测试）。

---

## 提交并开始工作

```bash
git add .claude/ CLAUDE.md
git commit -m "chore: add Claude Code toolkit configuration"
claude
```

Claude Code 启动并自动加载：

1. 全局 `~/.claude/CLAUDE.md`（安全规则 —— 由脚本安装）
2. 项目 `CLAUDE.md`（按你的栈匹配 —— 你可以追加项目专属细节）
3. `.claude/commands/` 里的每条命令和 marketplace 的 skill

---

## 常用命令

| 命令               | 作用                                                                          |
|--------------------|-------------------------------------------------------------------------------|
| `/update-toolkit`  | 拉取最新 toolkit 内容，保留 `CLAUDE.md` 的本地修改。                           |
| `/update-deps`     | 依赖看板（Layer 1/2/3 + MCP），选择要更新的项。                               |
| `/council 计划`    | 把方案发给 Gemini + ChatGPT 做独立评审。                                       |
| `/learn`           | 把当前决策保存为 scoped rule，供未来会话使用。                                 |
| `/audit security`  | 7 套框架感知审计中的一套。                                                    |
| `/debug 问题`      | 4 阶段系统化调试器。                                                          |
| `/setup-guide`     | 重新生成本地 HTML 安装引导。                                                  |
| `/helpme`          | 完整命令速查。                                                                |

---

## 流程图

```text
┌────────────────────────────────────────────────────────┐
│  安装（每个项目一次）                                  │
│                                                        │
│  $ cd ~/Projects/my-app                                │
│  $ bash <(curl -sSL …/install.sh)                      │
│  → TUI 检查列表 → 空格/回车                            │
│                                                        │
│  结果：                                                │
│   ~/.claude/CLAUDE.md       ← 安全规则                 │
│   .claude/                  ← 命令、skill、agent       │
│   CLAUDE.md                 ← 匹配栈的模板             │
│   .claude/setup-guide.html  ← MCP API 设置指南         │
└────────────────────────────────────────────────────────┘
                       │
                       ▼
┌────────────────────────────────────────────────────────┐
│  日常开发                                              │
│                                                        │
│  $ claude                                              │
│  > /plan 添加身份验证                                   │
│  > /debug /api/users 报 500                             │
│  > /audit security                                      │
│  > /council 我的数据库迁移方案                          │
└────────────────────────────────────────────────────────┘
```

---

## 升级

```bash
cd ~/Projects/my-app
# 在 Claude Code 内：
> /update-toolkit   # toolkit 内容
> /update-deps      # 所有依赖（带复选框的 TUI）
```

`/update-deps` 展示完整 TUI 列表带 installed-vs-latest。你挑要升级的，其他保持不变。

---

## Claude Desktop

Desktop 用户通过 marketplace 安装：

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

会得到三个子插件：`tk-skills`（22 个 skill）、`tk-commands`（29 条命令）、`tk-framework-rules`（7 个 CLAUDE.md 片段）。详情：[docs/CLAUDE_DESKTOP.md](../CLAUDE_DESKTOP.md)。

---

## 故障排查

| 问题                                              | 解法                                                                                       |
|---------------------------------------------------|--------------------------------------------------------------------------------------------|
| 安装后 `cc-safety-net: command not found`          | `npm install -g cc-safety-net`，然后 `bash <(curl …/scripts/install-hooks.sh)`             |
| RTK 不重写命令                                    | `~/.claude/settings.json` 必须是**一个合并的** hook，不是两个分开的                          |
| Claude 看不见项目命令                             | 在 `.claude/` 所在的同一目录重启 `claude`                                                  |
| safety-net 拦截了你需要的命令                     | 在普通终端手动执行（或临时设置 `TK_NO_SAFETY=1`）                                           |
| 安装器卡在 TUI                                    | `Ctrl-C`，重启；macOS `bash` 3.2 上 ↑/↓ 可能需要 `--no-tui-fallback`                       |
| `setup-guide.html` 打不开                         | `open .claude/setup-guide.html`（macOS）/ `xdg-open`（Linux）；或用 `/setup-guide`。       |
