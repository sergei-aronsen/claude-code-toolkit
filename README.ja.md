# Claude Guides

Claude Codeを使用したAI支援開発のための包括的な手順書です。

[![Quality Check](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](README.md)** | **[Русский](README.ru.md)** | **[Español](README.es.md)** | **[Deutsch](README.de.md)** | **[Français](README.fr.md)** | **[中文](README.zh.md)** | **日本語** | **[Português](README.pt.md)** | **[한국어](README.ko.md)**

> **Claude Code は初めてですか？** まず[ステップバイステップのインストールガイド](howto/ja.md)をお読みください。

---

## 対象者

[Claude Code](https://docs.anthropic.com/en/docs/claude-code)を使って**AIと共にプロダクトを開発するソロ開発者**向けです。

対応スタック：**Laravel/PHP**、**Next.js**、**Node.js**、**Python**、**Go**、**Ruby on Rails**。

チームがなければ、コードレビューも、アーキテクチャについて相談できる人も、セキュリティをチェックしてくれる人もいません。このリポジトリはこれらのギャップを埋めます：

| 問題 | 解決策 |
|------|--------|
| Claudeが毎回ルールを忘れる | `CLAUDE.md` — セッション開始時に読み込む指示書 |
| 誰にも聞けない | `/debug` — 推測ではなく体系的なデバッグ |
| コードレビューがない | `/audit code` — チェックリストに基づいてClaudeがレビュー |
| セキュリティレビューがない | `/audit security` — SQLインジェクション、XSS、CSRF、認証 |
| デプロイ前のチェックを忘れる | `/verify` — ビルド、型、lint、テストを一括実行 |

**内容:** 24コマンド、7種類の監査、23以上のガイド、主要スタック対応テンプレート。

---

## クイックスタート

### 初回インストール

Claude Codeに伝えてください：

```text
Download instructions from https://github.com/digitalplanetno/claude-code-toolkit
```

またはターミナルで実行：

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

スクリプトは自動的にフレームワーク（Laravel、Next.js）を検出し、適切なテンプレートをコピーします。

### インストール後

再インストールまたはアップデートには `/install` コマンドを使用：

```text
/install          # フレームワークを自動検出
/install laravel  # Laravelを強制
/install nextjs   # Next.jsを強制
/install nodejs   # Node.jsを強制
/install python   # Pythonを強制
/install go       # Goを強制
/install rails    # Ruby on Railsを強制
```

またはターミナルで：

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/update-claude.sh | bash
```

---

## 主な機能

### 1. 自己学習システム

Claudeはあなたの修正から学び、プロジェクトの知識を蓄積します。

**2つのメカニズム：**

| メカニズム | 機能 | 使用タイミング |
|------------|------|----------------|
| `/learn` | **一度きりの**問題解決を保存 | 非自明な問題を解決した、回避策を見つけた |
| **スキル蓄積** | **繰り返される**パターンを蓄積 | Claudeが2回以上修正されたことに気付いた |

**違い：**

```text
/learn  → "問題Xをどう解決したか"    （一度きりの修正）
skill   → "Yは常にこうする"          （プロジェクトのパターン）
```

**/learnの例：**

```text
> /learn

セッションを分析中...
発見: Prisma Serverless接続修正

問題: Vercel Edge Functionsでの接続タイムアウト
解決策: DATABASE_URLに?connection_limit=1を追加

.claude/learned/prisma-serverless.mdに保存しますか？ → yes
```

**スキル蓄積の例：**

```text
ユーザー: ユーザー用のエンドポイントを作成して
Claude: [エンドポイントを作成]
ユーザー: いや、バリデーションにはZodを、エラーにはAppErrorを使う

Claude: パターンを検出: エンドポイントではZod + AppErrorを使用
        'backend-endpoints'としてスキルを保存しますか？
        トリガー: endpoint, api, route

ユーザー: yes

[次回からClaudeは最初からZod + AppErrorを使用]
```

### 2. 自動起動フック

**問題：** 10個のスキルがあるのに、使うのを忘れる。

**解決策：** フックがプロンプトをClaudeに送信する**前に**インターセプトし、スキルのロードを推奨。

```text
ユーザープロンプト → フックが分析 → スコアリング → 推奨
```

**スコアリングシステム：**

| トリガー | ポイント | 例 |
|----------|----------|-----|
| keyword | +2 | プロンプトに"endpoint"が含まれる |
| intentPattern | +4 | "create.*endpoint" |
| pathPattern | +5 | ファイル `src/api/*` が開いている |

**例：**

```text
プロンプト: "登録用のPOSTエンドポイントを作成"
ファイル: src/api/auth.controller.ts

スキル推奨:
[高] backend-dev (スコア: 13)
[高] security-review (スコア: 12)

Skillツールを使用してガイドラインをロードしてください。
```

### 3. メモリの永続化

**問題：** MCPメモリはローカルに保存される。別のコンピューターに移動すると、メモリが失われる。

**解決策：** `.claude/memory/` にエクスポート → gitにコミット → どこでも利用可能。

```text
.claude/memory/
├── knowledge-graph.json   # コンポーネントの関係
├── project-context.md     # プロジェクトコンテキスト
└── decisions-log.md       # なぜ決定Xを下したか
```

**ワークフロー：**

```text
セッション開始時:    同期を確認 → MCPからメモリをロード
変更後:             エクスポート → .claude/memory/をコミット
新しいコンピューター: プル → MCPにインポート
```

### 4. 体系的なデバッグ (/debug)

**鉄則：**

```text
根本原因の調査なしに修正を行わない
```

**4つのフェーズ：**

| フェーズ | 何をするか | 終了条件 |
|----------|------------|----------|
| **1. 根本原因** | エラーを読み、再現し、データフローを追跡 | 何が、なぜを理解 |
| **2. パターン** | 動作する例を見つけ、比較 | 違いを発見 |
| **3. 仮説** | 理論を立て、1つの変更をテスト | 確認済み |
| **4. 修正** | テストを書き、修正し、検証 | テストがグリーン |

**3回の修正ルール：**

```text
3回以上の修正がうまくいかなかったら — 止まれ！
これはバグではない。アーキテクチャの問題だ。
```

### 5. 構造化されたワークフロー

**問題：** Claudeはタスクを理解する代わりに「すぐにコーディング」することが多い。

**解決策：** 明示的な制限を持つ3つのフェーズ：

| フェーズ | アクセス | 許可される操作 |
|----------|----------|----------------|
| **調査** | 読み取り専用 | Glob、Grep、Read — コンテキストを理解 |
| **計画** | スクラッチパッドのみ | `.claude/scratchpad/` に計画を作成 |
| **実行** | フル | 計画の確認後のみ |

```text
ユーザー: メールバリデーションを追加

Claude: フェーズ1: 調査
        [ファイルを読み、パターンを検索]
        発見: RegisterForm.tsxにフォーム、Zodでバリデーション

        フェーズ2: 計画
        [.claude/scratchpad/current-task.mdに計画を作成]
        計画完了。続行を確認してください。

ユーザー: ok

Claude: フェーズ3: 実行
        ステップ1: スキーマを追加中...
        ステップ2: フォームに統合中...
        ステップ3: テスト...
```

---

## インストール後の構造

```text
your-project/
└── .claude/
    ├── CLAUDE.md              # メイン指示書（プロジェクトに合わせて適応）
    ├── settings.json          # フック、権限
    ├── commands/              # スラッシュコマンド
    │   ├── verify.md
    │   ├── debug.md
    │   └── ...
    ├── prompts/               # 監査
    │   ├── SECURITY_AUDIT.md
    │   ├── PERFORMANCE_AUDIT.md
    │   ├── CODE_REVIEW.md
    │   ├── DESIGN_REVIEW.md
    │   ├── MYSQL_PERFORMANCE_AUDIT.md
    │   └── POSTGRES_PERFORMANCE_AUDIT.md
    ├── agents/                # サブエージェント
    │   ├── code-reviewer.md
    │   ├── test-writer.md
    │   └── planner.md
    ├── skills/                # フレームワーク専門知識
    │   └── [framework]/SKILL.md
    ├── scratchpad/            # 作業メモ
    └── memory/                # MCPメモリエクスポート
```

---

## 内容

### テンプレート（7種類）

| テンプレート | 用途 | 特徴 |
|--------------|------|------|
| `base/` | あらゆるプロジェクト | 汎用ルール |
| `laravel/` | Laravel + Vue/Inertia | Eloquent、マイグレーション、Blade、Pint |
| `nextjs/` | Next.js + TypeScript | App Router、RSC、Tailwind |
| `nodejs/` | Node.js + TypeScript | Express、Fastify、NestJS |
| `python/` | Python | Django、FastAPI、Flask |
| `go/` | Go | 標準ライブラリ、Gin、Echo |
| `rails/` | Ruby on Rails + Hotwire | ActiveRecord、Turbo、Stimulus、RSpec |

### スラッシュコマンド（全24個）

| コマンド | 説明 |
|----------|------|
| `/verify` | コミット前チェック：ビルド、型、lint、テスト |
| `/debug [problem]` | 4フェーズデバッグ：根本原因 → 仮説 → 修正 → 検証 |
| `/learn` | 問題の解決策を `.claude/learned/` に保存 |
| `/plan` | 実装前にスクラッチパッドに計画を作成 |
| `/audit [type]` | 監査を実行（security、performance、code、design、database） |
| `/test` | モジュールのテストを作成 |
| `/refactor` | 動作を保持しながらリファクタリング |
| `/fix [issue]` | 特定の問題を修正 |
| `/explain` | コードの動作を説明 |
| `/doc` | ドキュメントを生成 |
| `/context-prime` | セッション開始時にプロジェクトコンテキストをロード |
| `/checkpoint` | 進捗をスクラッチパッドに保存 |
| `/handoff` | タスクの引き継ぎを準備（サマリー + 次のステップ） |
| `/worktree` | Git worktrees管理 |
| `/install` | claude-guidesをプロジェクトにインストール |
| `/migrate` | データベースマイグレーション支援 |
| `/find-function` | 名前/説明で関数を検索 |
| `/find-script` | package.json/composer.jsonでスクリプトを検索 |
| `/tdd` | テスト駆動開発ワークフロー |
| `/docker` | Dockerコンテナとcompose管理 |
| `/api` | APIエンドポイントの作成と管理 |
| `/e2e` | E2Eテストの作成と実行 |
| `/perf` | パフォーマンス分析と最適化 |
| `/deps` | 依存関係の管理とアップデート |

### 監査（7種類）

| 監査 | ファイル | チェック内容 |
|------|----------|--------------|
| **セキュリティ** | `SECURITY_AUDIT.md` | SQLインジェクション、XSS、CSRF、認証、シークレット |
| **パフォーマンス** | `PERFORMANCE_AUDIT.md` | N+1、バンドルサイズ、キャッシング、遅延読み込み |
| **コードレビュー** | `CODE_REVIEW.md` | パターン、可読性、SOLID、DRY |
| **デザインレビュー** | `DESIGN_REVIEW.md` | UI/UX、アクセシビリティ、レスポンシブ（Playwright MCP） |
| **MySQL** | `MYSQL_PERFORMANCE_AUDIT.md` | performance_schema、インデックス、スロークエリ |
| **PostgreSQL** | `POSTGRES_PERFORMANCE_AUDIT.md` | pg_stat_statements、bloat、接続 |
| **デプロイ** | `DEPLOY_CHECKLIST.md` | デプロイ前チェックリスト |

### コンポーネント（23以上のガイド）

| コンポーネント | 説明 |
|----------------|------|
| `structured-workflow.md` | 3フェーズアプローチ：調査 → 計画 → 実行 |
| `smoke-tests-guide.md` | 最小限のAPIテスト（Laravel/Next.js/Node.js） |
| `hooks-auto-activation.md` | プロンプトコンテキストによるスキルの自動起動 |
| `skill-accumulation.md` | 自己学習：Claudeがプロジェクト知識を蓄積 |
| `modular-skills.md` | 大きなガイドライン向けの段階的開示 |
| `spec-driven-development.md` | コードの前に仕様 |
| `mcp-servers-guide.md` | 推奨MCPサーバー |
| `memory-persistence.md` | MCPメモリとGitの同期 |
| `plan-mode-instructions.md` | 思考レベル：think → think hard → ultrathink |
| `git-worktrees-guide.md` | ブランチでの並行作業 |
| `devops-highload-checklist.md` | 高負荷プロジェクトのチェックリスト |
| `api-health-monitoring.md` | APIエンドポイントの監視 |
| `bootstrap-workflow.md` | 新規プロジェクトのワークフロー |
| `github-actions-guide.md` | GitHub ActionsでのCI/CD設定 |
| `pre-commit-hooks.md` | コミット前の自動チェック設定 |
| `deployment-strategies.md` | デプロイ戦略とベストプラクティス |

---

## MCPサーバー（推奨！）

| サーバー | 用途 |
|----------|------|
| `context7` | ライブラリドキュメント |
| `playwright` | ブラウザ自動化、UIテスト |
| `memory-bank` | セッション間のメモリ |
| `sequential-thinking` | ステップバイステップの問題解決 |
| `memory` | Knowledge Graph（関係グラフ） |

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add playwright -- npx @playwright/mcp@latest
```

---

## Rate Limit Statusline (Claude Max / Pro)

Claude Code のステータスバーで API 使用制限を直接監視できます。

```text
25% | 5h:23% (2h57m) | 7d:80% (1d18h)
 │      │      │          │       │
 │      │      │          │       └─ 週間リセットまでの時間
 │      │      │          └─ 週間使用量（7日間ウィンドウ）
 │      │      └─ セッションリセットまでの時間
 │      └─ セッション使用量（5時間ウィンドウ）
 └─ コンテキストウィンドウ使用量
```

**色分け：** 色なし（<60%）、黄色（60-79%）、赤（80-89%）、明るい赤（90-100%）

**要件：** macOS、`jq`、OAuth 認証済みの Claude Code（Max または Pro サブスクリプション）

### インストール

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/install-statusline.sh | bash
```

インストーラーは前提条件を確認し、スクリプトを `~/.claude/` にダウンロードし、`settings.json` を設定して初期テストを実行します。

詳細とカスタマイズ：[components/rate-limit-statusline.md](components/rate-limit-statusline.md)。

---

## 使用例

### /verify — コミット前チェック

```text
> /verify

チェックを実行中...
ビルド: 合格
TypeScript: エラーなし
ESLint: 2件の警告（未使用のインポート）
テスト: 23件合格

推奨: コミット前にlint警告を修正してください。
```

### /debug — 体系的なデバッグ

```text
> /debug APIが/api/usersで500を返す

フェーズ1: 根本原因分析
├── app/api/users/route.tsを読み込み中
├── ログを確認中
└── 発見: prisma.user.findMany()にtry/catchがない

フェーズ2: 仮説
└── コールドスタート時のデータベース接続タイムアウト

フェーズ3: 修正
└── エラーハンドリング + リトライロジックを追加

フェーズ4: 検証
└── エンドポイントをテスト — 動作確認
```

### /audit security — セキュリティ監査

```text
> /audit security

セキュリティ監査レポート
=======================

[致命的] (1)
├── UserController:45でSQLインジェクション
└── 推奨: プリペアドステートメントを使用

[中] (2)
├── /api/loginにレート制限がない
└── CORSがAccess-Control-Allow-Origin: *で設定

[低] (1)
└── .env.exampleでデバッグモード
```

---

## サポートされているフレームワーク

| フレームワーク | テンプレート | スキル | 自動検出 |
|----------------|--------------|--------|----------|
| Laravel | ✅ 専用 | ✅ | `artisan`ファイル |
| Next.js | ✅ 専用 | ✅ | `next.config.*` |
| Node.js | ✅ 専用 | ✅ | `package.json`（next.configなし） |
| Python | ✅ 専用 | ✅ | `pyproject.toml` / `requirements.txt` |
| Go | ✅ 専用 | ✅ | `go.mod` |
| Ruby on Rails | ✅ 専用 | ✅ | `bin/rails` / `config/application.rb` |
