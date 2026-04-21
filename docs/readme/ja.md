# Claude Code Toolkit

Claude Code を使用した AI 支援開発のための包括的な手順書です。

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](../../README.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **日本語** | **[Português](pt.md)** | **[한국어](ko.md)**

> 最初に完全な[ステップバイステップのインストールガイド](../howto/ja.md)をお読みください。

---

## 対象者

[Claude Code](https://docs.anthropic.com/en/docs/claude-code) を使ってプロダクトを開発する**ソロ開発者**向けです。

対応スタック：**Laravel/PHP**、**Ruby on Rails**、**Next.js**、**Node.js**、**Python**、**Go**。

**30 スラッシュコマンド** | **7 監査** | **29 ガイド** | [コマンド、テンプレート、監査、コンポーネントの完全なリスト](../features.md#slash-commands-30-total)をご覧ください。

---

## クイックスタート

### 1. グローバルセットアップ（一度だけ）

#### a) セキュリティパック

多層防御のセキュリティ設定です。完全なガイドは [components/security-hardening.md](../../components/security-hardening.md) をご覧ください。

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)
```

#### b) RTK — トークンオプティマイザー（推奨）

[RTK](https://github.com/rtk-ai/rtk) は開発コマンド（`git status`、`cargo test` など）のトークン消費を 60-90% 削減します。

```bash
brew install rtk
rtk init -g
```

> **注意：** RTK と cc-safety-net が別々のフックになっている場合、結果が競合します。
> Security Pack（ステップ 1a）はすでに両方を順番に実行する統合フックを設定しています。
> 詳細は [components/security-hardening.md](../../components/security-hardening.md) をご覧ください。

#### c) Rate Limit Statusline（Claude Max / Pro、オプション）

Claude Code のステータスバーにセッション/週間の制限を表示します。詳細：[components/rate-limit-statusline.md](../../components/rate-limit-statusline.md)

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-statusline.sh)
```

## インストールモード

TK は `superpowers`（obra）と `get-shit-done`（gsd-build）がインストールされているかを自動検出し、
`standalone`、`complement-sp`、`complement-gsd`、`complement-full` の 4 つのモードから 1 つを選択します。
各フレームワークテンプレートは `## Required Base Plugins` で必要なベースプラグインを記載しています —
例：[templates/base/CLAUDE.md](../../templates/base/CLAUDE.md)。12 マスのインストールマトリックスと
ステップバイステップガイドは [docs/INSTALL.md](../INSTALL.md) をご覧ください。

### スタンドアロンインストール

`superpowers` または `get-shit-done` がインストールされていない（または明示的に不使用を選択した）場合です。
TK は全 54 ファイルをインストールします — フルセットのデフォルト構成です。通常のターミナル（Claude Code
内ではなく！）でプロジェクトフォルダから実行してください：

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
```

そのプロジェクトディレクトリで Claude Code を起動してください。今後のアップデートは `/update-toolkit` を使用してください。

### 補完インストール

`superpowers`（obra）と `get-shit-done`（gsd-build）の一方または両方がインストールされている場合です。TK は
自動検出し、SP の機能と重複する 7 ファイルをスキップして、約 47 の TK 独自コントリビューション（Council、
フレームワーク CLAUDE.md テンプレート、コンポーネントライブラリ、cheatsheets、フレームワーク専用スキル）
を保持します。同じインストールコマンドを使用してください — TK が自動的に `complement-*` モードを選択します。
上書きするには `--mode standalone`（または他のモード名）を渡してください：

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh) --mode complement-full
```

### v3.xからのアップグレード

TK のインストール後に SP または GSD をインストールした v3.x ユーザーは、`scripts/migrate-to-complement.sh` を
実行してファイルごとの確認と完全な移行前バックアップで重複ファイルを削除してください。12 マスのマトリックスと
ステップバイステップガイドは [docs/INSTALL.md](../INSTALL.md) をご覧ください。

> **重要：** プロジェクトテンプレートは `project/.claude/CLAUDE.md` 専用です。`~/.claude/CLAUDE.md` に
> コピーしないでください — そのファイルにはグローバルなセキュリティルールと個人設定のみを記載してください
> （50 行以内）。詳細は [components/claude-md-guide.md](../../components/claude-md-guide.md) をご覧ください。

---

## 主な機能

| 機能 | 説明 |
|------|------|
| **自己学習** | `/learn` が `globs:` 付きのルールファイルとして解決策を保存 — 関連ファイルにのみ自動読み込み |
| **自動起動フック** | フックがプロンプトをインターセプトし、コンテキスト（キーワード、意図、ファイルパス）をスコアリングして関連スキルを推奨 |
| **知識の永続化** | プロジェクトの事実を `.claude/rules/` に保存 — 毎セッション自動ロード、git にコミット、どのマシンでも利用可能 |
| **体系的デバッグ** | `/debug` で 4 つのフェーズを強制：根本原因 → パターン → 仮説 → 修正。推測なし |
| **本番環境安全性** | `/deploy` でプレ/ポストチェック、`/fix-prod` でホットフィックス、インクリメンタルデプロイ、worker 安全性 |
| **Supreme Council** | `/council` でプランを Gemini + ChatGPT に送信し、コーディング前に独立レビューを実施 |
| **構造化ワークフロー** | 3 つの必須フェーズ：調査（読み取り専用） → 計画（スクラッチパッド） → 実行（確認後） |

詳細な説明と例は[こちら](../features.md)をご覧ください。

---

## MCPサーバー（推奨！）

### グローバル（全プロジェクト）

| サーバー | 用途 |
|----------|------|
| `context7` | ライブラリドキュメント |
| `playwright` | ブラウザ自動化、UI テスト |
| `sequential-thinking` | ステップバイステップの問題解決 |
| `sentry` | エラーモニタリングと問題調査 |

```bash
claude mcp add -s user context7 -- npx -y @upstash/context7-mcp
claude mcp add -s user playwright -- npx @playwright/mcp@latest --browser chromium
claude mcp add -s user sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp
```

### プロジェクトごと（認証情報）

| サーバー | 用途 |
|----------|------|
| `dbhub` | 汎用データベースアクセス（PostgreSQL、MySQL、MariaDB、SQL Server、SQLite） |

```bash
claude mcp add dbhub -- npx -y @bytebase/dbhub --dsn "postgresql://user:pass@localhost:5432/dbname"
```

> **セキュリティ：** 常に**読み取り専用のデータベースユーザー**を使用してください — DBHub のアプリレベルの `--readonly` フラグのみに頼らないでください（[既知のバイパス](https://github.com/bytebase/dbhub/issues/271)）。プロジェクトごとのサーバーは `.claude/settings.local.json`（.gitignore 済み、認証情報に安全）に保存されます。詳細は [mcp-servers-guide.md](../../components/mcp-servers-guide.md) をご覧ください。

---

## インストール後の構造

† でマークされたファイルは `superpowers` と競合します — `complement-sp` および `complement-full` モードでは除外されます。

```text
your-project/
└── .claude/
    ├── CLAUDE.md              # 主な指示（プロジェクトに合わせて調整）
    ├── settings.json          # フック、権限
    ├── commands/              # スラッシュコマンド
    │   ├── verify.md          # † complement-sp/full では除外
    │   ├── debug.md           # † complement-sp/full では除外
    │   └── ...
    ├── prompts/               # 監査
    │   ├── SECURITY_AUDIT.md
    │   ├── PERFORMANCE_AUDIT.md
    │   ├── CODE_REVIEW.md
    │   ├── DESIGN_REVIEW.md
    │   ├── MYSQL_PERFORMANCE_AUDIT.md
    │   └── POSTGRES_PERFORMANCE_AUDIT.md
    ├── agents/                # サブエージェント
    │   ├── code-reviewer.md   # † complement-sp/full では除外
    │   ├── test-writer.md
    │   └── planner.md
    ├── skills/                # フレームワーク専門知識
    │   └── [framework]/SKILL.md
    ├── rules/                 # 自動読み込みされるプロジェクト情報
    └── scratchpad/            # 作業メモ
```

---

## サポートされているフレームワーク

| フレームワーク | テンプレート | スキル | 自動検出 |
|----------------|--------------|--------|----------|
| Laravel | ✅ | ✅ | `artisan` ファイル |
| Ruby on Rails | ✅ | ✅ | `bin/rails` / `config/application.rb` |
| Next.js | ✅ | ✅ | `next.config.*` |
| Node.js | ✅ | ✅ | `package.json`（next.config なし） |
| Python | ✅ | ✅ | `pyproject.toml` / `requirements.txt` |
| Go | ✅ | ✅ | `go.mod` |

---

## コンポーネント

カスタム `CLAUDE.md` ファイルを構成するための再利用可能な Markdown セクションです。コンポーネントはリポジトリルートの
アセットです — `.claude/` にはインストールされません。絶対 GitHub URL で参照してください。

**オーケストレーションパターン** — Council と GSD ワークフローが共に使用する、精瘦なオーケストレーター +
リッチなサブエージェント設計については [components/orchestration-pattern.md](../../components/orchestration-pattern.md)
をご覧ください。カスタムスラッシュコマンドを単一のコンテキストウィンドウを超えてスケールさせるのに役立ちます。
