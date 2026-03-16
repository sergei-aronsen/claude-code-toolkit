# Claude Code Toolkit

Claude Codeを使用したAI支援開発のための包括的な手順書です。

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](../../README.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **日本語** | **[Português](pt.md)** | **[한국어](ko.md)**

> まず[ステップバイステップのインストールガイド](../howto/ja.md)をお読みください。

---

## 対象者

[Claude Code](https://docs.anthropic.com/en/docs/claude-code)を使ってプロダクトを開発する**ソロ開発者**向けです。

対応スタック：**Laravel/PHP**、**Ruby on Rails**、**Next.js**、**Node.js**、**Python**、**Go**。

**7テンプレート** (basic、Laravel、Rails、Next.js、Node.js、Python、Go)

**29スラッシュコマンド** | **7監査** | **30ガイド** | [コマンド、テンプレート、監査、コンポーネントの完全なリスト](../features.md#slash-commands-29-total)をご覧ください。

---

## クイックスタート

### 1. グローバルセットアップ（一度だけ）

#### a) セキュリティパック

多層防御のセキュリティ設定。完全なガイドは[components/security-hardening.md](../../components/security-hardening.md)をご覧ください。

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)
```

#### b) RTK — トークンオプティマイザー（推奨）

[RTK](https://github.com/rtk-ai/rtk) は開発コマンド（`git status`、`cargo test` など）のトークン消費を60-90%削減します。

```bash
brew install rtk
rtk init -g
```

> **注意：** セキュリティパック（ステップ1a）はすでにsafety-netとRTKを順番に実行する統合フックを設定しています。
> 詳細は [components/security-hardening.md](../../components/security-hardening.md) をご覧ください。

#### c) Rate Limit Statusline（Claude Max / Pro、オプション）

ステータスバーにセッション/週間の制限を表示します。詳細：[components/rate-limit-statusline.md](../../components/rate-limit-statusline.md)

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-statusline.sh)
```

### 2. インストール（プロジェクトごと）

インストーラーは：

- **スタックの選択**を求めます（自動検出推奨）
- ツールキットをインストール（コマンド、エージェント、プロンプト、スキル）
- **Supreme Council** を設定（Gemini + ChatGPTマルチAIレビュー）
- APIキーの設定をガイド

プロジェクトフォルダのターミナルで実行してください：

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
```

**Claudeを再起動してください！** 今後のアップデートには `/update-toolkit` コマンドを使用してください。

---

## 主な機能

| 機能 | 説明 |
|------|------|
| **自己学習** | `/learn` で一度きりの解決策を保存。スキル蓄積で繰り返しパターンを自動的にキャプチャ |
| **自動起動フック** | フックがプロンプトをインターセプトし、コンテキスト（キーワード、意図、ファイルパス）をスコアリングして関連スキルを推奨 |
| **知識の永続化** | プロジェクトの事実を `.claude/rules/` に保存 — 毎セッション自動ロード、gitにコミット、どのマシンでも利用可能 |
| **体系的デバッグ** | `/debug` で4つのフェーズを強制：根本原因 → パターン → 仮説 → 修正。推測なし |
| **本番環境安全性** | `/deploy` でプレ/ポストチェック、`/fix-prod` でホットフィックス、インクリメンタルデプロイ |
| **Supreme Council** | `/council` でプランをGemini + ChatGPTに送信し、コーディング前に独立レビューを実施 |
| **構造化ワークフロー** | 3つの必須フェーズ：調査（読み取り専用） → 計画（スクラッチパッド） → 実行（確認後） |

詳細な説明と例は[こちら](../features.md)をご覧ください。

---

## MCPサーバー（推奨！）

| サーバー | 用途 |
|----------|------|
| `context7` | ライブラリドキュメント |
| `playwright` | ブラウザ自動化、UIテスト |
| `sequential-thinking` | ステップバイステップの問題解決 |

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add playwright -- npx @playwright/mcp@latest
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
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
    └── rules/                 # 自動読み込みプロジェクト情報
```

---

## サポートされているフレームワーク

| フレームワーク | テンプレート | スキル | 自動検出 |
|----------------|--------------|--------|----------|
| Laravel | ✅ | ✅ | `artisan` ファイル |
| Ruby on Rails | ✅ | ✅ | `bin/rails` / `config/application.rb` |
| Next.js | ✅ | ✅ | `next.config.*` |
| Node.js | ✅ | ✅ | `package.json`（next.configなし） |
| Python | ✅ | ✅ | `pyproject.toml` / `requirements.txt` |
| Go | ✅ | ✅ | `go.mod` |
