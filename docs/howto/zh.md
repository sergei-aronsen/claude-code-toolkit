# Claude Code Toolkit 入门指南

> 完整的新手教程：从零开始使用 Claude Code 进行高效开发

**[English](en.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **中文** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

---

## 前置条件

请确保已安装以下工具：

- **Node.js**（检查方法：`node --version`）
- **Claude Code**（检查方法：`claude --version`）

如果尚未安装 Claude Code：

```bash
npm install -g @anthropic-ai/claude-code
```

---

## 两个层级的配置

| 层级 | 内容 | 时机 |
|------|------|------|
| **全局** | 安全规则 + safety-net | 每台机器配置一次 |
| **项目级** | 命令、技能、模板 | 每个项目配置一次 |

---

## 第一步：全局配置（每台机器一次）

此步骤安装安全规则和 safety-net 插件。只需执行**一次**，即可在**所有**项目中生效。

打开常规终端（不是 Claude Code）：

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh | bash
```

**执行结果：**

- 创建 `~/.claude/CLAUDE.md` — 全局安全规则。Claude Code **在任何项目中每次启动时**都会读取此文件。它相当于一条指令，告诉 Claude "不要进行 SQL 注入、不要使用 eval()、执行危险操作前先确认"
- 安装 `cc-safety-net` — 一个拦截所有 bash 命令并阻止破坏性操作的插件（如 `rm -rf /`、`git push --force` 等）
- 在 `~/.claude/settings.json` 中配置 hook — 连接 Claude Code 和 safety-net

**验证是否正常工作：**

```bash
cc-safety-net doctor
```

完成。全局部分已配置好，**无需再次执行此步骤**。

---

## 第二步：创建你的项目

例如，一个 Laravel 项目：

```bash
cd ~/Projects
composer create-project laravel/laravel my-app
cd my-app
git init
```

或 Next.js 项目：

```bash
cd ~/Projects
npx create-next-app@latest my-app
cd my-app
```

如果你已有项目 — 直接进入项目文件夹即可：

```bash
cd ~/Projects/my-app
```

---

## 第三步：将 Toolkit 安装到项目中

在**项目文件夹内**运行：

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

脚本会**自动检测**你的框架（Laravel、Next.js、Python、Go 等）并创建：

```text
my-app/
└── .claude/
    ├── CLAUDE.md              ← Claude 的指令（针对你的项目）
    ├── settings.json          ← 设置、hooks
    ├── commands/              ← 24 个斜杠命令
    │   ├── debug.md           ← /debug — 系统化调试
    │   ├── plan.md            ← /plan — 编码前规划
    │   ├── verify.md          ← /verify — 提交前检查
    │   ├── audit.md           ← /audit — 安全/性能审计
    │   ├── test.md            ← /test — 编写测试
    │   └── ...                ← 约 19 个其他命令
    ├── prompts/               ← 审计模板
    ├── agents/                ← 子代理（code-reviewer、test-writer）
    ├── skills/                ← 框架专业知识
    ├── cheatsheets/           ← 速查表（9 种语言）
    ├── memory/                ← 会话间记忆
    └── scratchpad/            ← 工作笔记
```

**手动指定框架：**

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh | bash -s -- laravel
```

---

## 第四步：为你的项目配置 CLAUDE.md

这是最重要的文件。用编辑器打开 `.claude/CLAUDE.md` 并填写：

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

Claude **在此项目中每次启动时都会读取该文件**。填写得越详细 — Claude 就越智能。

---

## 第五步：将 .claude 提交到 Git

```bash
git add .claude/
git commit -m "feat: add Claude Code toolkit configuration"
```

现在配置已保存在代码仓库中。如果你在另一台机器上克隆项目 — toolkit 已经包含在内。

---

## 第六步：启动 Claude Code 开始工作

```bash
claude
```

Claude Code 启动并自动加载：

1. **全局** `~/.claude/CLAUDE.md`（安全规则 — 来自第一步）
2. **项目级** `.claude/CLAUDE.md`（你的指令 — 来自第四步）
3. `.claude/commands/` 中的所有命令

现在你可以开始工作了：

```text
> Create a REST API for product management: CRUD, pagination, search
```

---

## Claude Code 中的常用命令

| 命令 | 功能说明 |
|------|----------|
| `/plan` | 先思考，后编码（调研 - 规划 - 执行） |
| `/debug problem` | 4 阶段系统化调试 |
| `/audit security` | 安全审计 |
| `/audit` | 代码审查 |
| `/verify` | 提交前检查（构建 + lint + 测试） |
| `/test` | 编写测试 |
| `/learn` | 保存问题解决方案以供将来参考 |
| `/helpme` | 所有命令的速查表 |

---

## 全局概览 — 完整流程

```text
┌─────────────────────────────────────────────────────┐
│  ONCE PER MACHINE (Step 1)                          │
│                                                     │
│  Terminal:                                          │
│  $ curl ... setup-security.sh | bash                │
│                                                     │
│  Result:                                            │
│  ~/.claude/CLAUDE.md      ← security rules          │
│  ~/.claude/settings.json  ← safety-net hook         │
│  cc-safety-net            ← npm package             │
└─────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  FOR EACH PROJECT (Steps 2-5)                       │
│                                                     │
│  Terminal:                                          │
│  $ cd ~/Projects/my-app                             │
│  $ curl ... init-claude.sh | bash                   │
│  $ # edit .claude/CLAUDE.md                         │
│  $ git add .claude/ && git commit                   │
│                                                     │
│  Result:                                            │
│  .claude/                 ← commands, skills,       │
│                              prompts, agents        │
└─────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  WORK (Step 6)                                      │
│                                                     │
│  $ claude                                           │
│  > /plan add authentication                         │
│  > /debug why 500 on /api/users                     │
│  > /verify                                          │
│  > /audit security                                  │
└─────────────────────────────────────────────────────┘
```

---

## 更新 Toolkit

当有新的命令或模板发布时：

```bash
cd ~/Projects/my-app
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/update-claude.sh | bash
```

或在 Claude Code 内部执行：

```text
> /install
```

---

## 故障排查

| 问题 | 解决方案 |
|------|----------|
| `cc-safety-net: command not found` | 运行 `npm install -g cc-safety-net` |
| Claude 未检测到 Toolkit | 检查项目根目录中是否存在 `.claude/CLAUDE.md` |
| 命令不可用 | 重新运行 `init-claude.sh` 或检查 `.claude/commands/` 文件夹 |
| safety-net 阻止了合法命令 | 在 Claude Code 外部的终端中手动运行该命令 |
