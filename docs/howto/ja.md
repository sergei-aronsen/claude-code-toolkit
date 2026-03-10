# Claude Code Toolkit 入門ガイド

> 完全な初心者向けガイド: ゼロから Claude Code を使った生産的な開発まで

**[English](en.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **日本語** | **[Português](pt.md)** | **[한국어](ko.md)**

---

## 前提条件

以下がインストールされていることを確認してください:

- **Node.js** (確認: `node --version`)
- **Claude Code** (確認: `claude --version`)

Claude Code がまだインストールされていない場合:

```bash
npm install -g @anthropic-ai/claude-code
```

---

## セットアップの2つのレベル

| レベル | 内容 | タイミング |
|--------|------|------------|
| **グローバル** | セキュリティルール + hooks + プラグイン | マシンごとに1回 |
| **プロジェクトごと** | コマンド、スキル、テンプレート | プロジェクトごとに1回 |

---

## ステップ 1: グローバルセットアップ (マシンごとに1回)

セキュリティルール、統合フック（safety-net + RTK サポート）、Anthropic 公式プラグインをインストールします。**1回**だけ実行すれば、**すべての**プロジェクトで機能します。

通常のターミナル (Claude Code ではなく) を開いてください:

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh | bash
```

**実行される内容:**

- `~/.claude/CLAUDE.md` が作成されます -- グローバルセキュリティルールです。Claude Code は**すべてのプロジェクトで起動するたびに**このファイルを読み込みます。「SQLインジェクションを行わない、eval()を使わない、危険な操作の前に確認を取る」といった指示です
- `cc-safety-net` がインストールされます -- 破壊的なコマンド (`rm -rf /`、`git push --force` など) をブロックします
- 統合フックが設定されます (safety-net + RTK 順次実行、並列の競合なし)
- Anthropic 公式プラグインが有効化されます (code-review、commit-commands、security-guidance、frontend-design)

**正常に動作しているか確認:**

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/verify-install.sh | bash
```

以上です。グローバル部分は完了しました。**この作業を繰り返す必要はありません**。

---

## ステップ 2: プロジェクトを作成する

例えば、Laravel プロジェクトの場合:

```bash
cd ~/Projects
composer create-project laravel/laravel my-app
cd my-app
git init
```

Next.js の場合:

```bash
cd ~/Projects
npx create-next-app@latest my-app
cd my-app
```

既にプロジェクトがある場合は、そのフォルダに移動するだけです:

```bash
cd ~/Projects/my-app
```

---

## ステップ 3: プロジェクトに Toolkit をインストールする

**プロジェクトフォルダ内**で以下を実行します:

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

スクリプトがフレームワーク (Laravel、Next.js、Python、Go など) を**自動検出**し、以下を作成します:

```text
my-app/
└── .claude/
    ├── CLAUDE.md              ← Claude への指示 (プロジェクト用)
    ├── settings.json          ← 設定、フック
    ├── commands/              ← 24個のスラッシュコマンド
    │   ├── debug.md           ← /debug — 体系的なデバッグ
    │   ├── plan.md            ← /plan — コーディング前の計画
    │   ├── verify.md          ← /verify — コミット前のチェック
    │   ├── audit.md           ← /audit — セキュリティ/パフォーマンス監査
    │   ├── test.md            ← /test — テストの作成
    │   └── ...                ← その他約19個のコマンド
    ├── prompts/               ← 監査テンプレート
    ├── agents/                ← サブエージェント (code-reviewer, test-writer)
    ├── skills/                ← フレームワークの専門知識
    ├── cheatsheets/           ← チートシート (9言語)
    ├── memory/                ← セッション間のメモリ
    └── scratchpad/            ← 作業メモ
```

**フレームワークを明示的に指定する場合:**

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh | bash -s -- laravel
```

---

## ステップ 4: プロジェクト用に CLAUDE.md を設定する

これが最も重要なファイルです。エディタで `.claude/CLAUDE.md` を開き、内容を記入してください:

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

Claude はこのプロジェクトで**起動するたびにこのファイルを読み込みます**。詳しく記入すればするほど、Claude はより賢く動作します。

---

## ステップ 5: .claude を Git にコミットする

```bash
git add .claude/
git commit -m "feat: add Claude Code toolkit configuration"
```

これで設定がリポジトリに保存されました。別のマシンでプロジェクトをクローンしても、Toolkit が既に含まれています。

---

## ステップ 6: Claude Code を起動して作業する

```bash
claude
```

Claude Code が起動し、自動的に以下を読み込みます:

1. **グローバル** `~/.claude/CLAUDE.md` (セキュリティルール -- ステップ 1 より)
2. **プロジェクト** `.claude/CLAUDE.md` (あなたの指示 -- ステップ 4 より)
3. `.claude/commands/` のすべてのコマンド

これで作業を始められます:

```text
> Create a REST API for product management: CRUD, pagination, search
```

---

## Claude Code 内で使える便利なコマンド

| コマンド | 機能 |
|----------|------|
| `/plan` | まず考え、それからコーディング (調査 → 計画 → 実行) |
| `/debug problem` | 4つのフェーズによる体系的なデバッグ |
| `/audit security` | セキュリティ監査 |
| `/audit` | コードレビュー |
| `/verify` | コミット前チェック (build + lint + tests) |
| `/test` | テストの作成 |
| `/learn` | 問題の解決策を将来の参照用に保存 |
| `/helpme` | 全コマンドのチートシート |

---

## 全体像 -- 完全なパス

```text
┌─────────────────────────────────────────────────────┐
│  ONCE PER MACHINE (Step 1)                          │
│                                                     │
│  Terminal:                                          │
│  $ curl ... setup-security.sh | bash                │
│                                                     │
│  Result:                                            │
│  ~/.claude/CLAUDE.md      ← security rules          │
│  ~/.claude/settings.json  ← 統合フック + プラグイン   │
│  ~/.claude/hooks/pre-bash.sh ← safety-net + RTK     │
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

## Toolkit のアップデート

新しいコマンドやテンプレートがリリースされた場合:

```bash
cd ~/Projects/my-app
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/update-claude.sh | bash
```

または Claude Code 内で:

```text
> /install
```

---

## トラブルシューティング

| 問題 | 解決策 |
|------|--------|
| `cc-safety-net: command not found` | `npm install -g cc-safety-net` を実行してください |
| Claude が Toolkit を検出しない | プロジェクトルートに `.claude/CLAUDE.md` が存在するか確認してください |
| コマンドが利用できない | `init-claude.sh` を再実行するか、`.claude/commands/` フォルダを確認してください |
| safety-net が正当なコマンドをブロックする | Claude Code の外の通常のターミナルでコマンドを手動実行してください |
| RTK がコマンドを書き換えない | settings.json に単一の統合フックがあることを確認してください。個別のフックではなく統合フックを使用してください |
