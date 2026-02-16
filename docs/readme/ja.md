# Claude Toolkit

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

**27スラッシュコマンド** | **7監査** | **24以上のガイド** | [コマンド、テンプレート、監査、コンポーネントの完全なリスト](../features.md#slash-commands-27-total)をご覧ください。

---

## クイックスタート

### 1. セキュリティパック（グローバル、一度だけ）

多層防御のセキュリティ設定が含まれています。完全なガイドは[components/security-hardening.md](../../components/security-hardening.md)をご覧ください。

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh | bash
```

### 2. インストール（プロジェクトごと）

スクリプトは自動的にフレームワークを検出し、適切なテンプレートをコピーします。

プロジェクトフォルダのターミナルで実行してください：

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

**Claudeを再起動してください！** 今後のアップデートには `/update-toolkit` コマンドを使用して再インストールまたは更新を行ってください。

### 3. Rate Limit Statusline (Claude Max / Pro)

Claude Codeのステータスバーにセッション/週間の制限を表示します。詳細：[components/rate-limit-statusline.md](../../components/rate-limit-statusline.md)

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-statusline.sh | bash
```

### 4. Supreme Council（マルチAIレビュー、オプション）

Gemini + ChatGPTがコーディング前にプランをレビューします。詳細：[components/supreme-council.md](../../components/supreme-council.md)

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-council.sh | bash
```

---

## 主な機能

| 機能 | 説明 |
|------|------|
| **自己学習** | `/learn` で一度きりの解決策を保存。スキル蓄積で繰り返しパターンを自動的にキャプチャ |
| **自動起動フック** | フックがプロンプトをインターセプトし、コンテキスト（キーワード、意図、ファイルパス）をスコアリングして関連スキルを推奨 |
| **メモリ永続化** | MCPメモリを `.claude/memory/` にエクスポートし、gitにコミット。どのマシンでも利用可能 |
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
| `memory-bank` | セッション間のメモリ |
| `sequential-thinking` | ステップバイステップの問題解決 |
| `memory` | Knowledge Graph（関係グラフ） |

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add playwright -- npx @playwright/mcp@latest
claude mcp add memory-bank -- npx -y @allpepper/memory-bank-mcp@latest
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
claude mcp add memory -- npx -y @modelcontextprotocol/server-memory
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

## サポートされているフレームワーク

| フレームワーク | テンプレート | スキル | 自動検出 |
|----------------|--------------|--------|----------|
| Laravel | ✅ | ✅ | `artisan` ファイル |
| Ruby on Rails | ✅ | ✅ | `bin/rails` / `config/application.rb` |
| Next.js | ✅ | ✅ | `next.config.*` |
| Node.js | ✅ | ✅ | `package.json`（next.configなし） |
| Python | ✅ | ✅ | `pyproject.toml` / `requirements.txt` |
| Go | ✅ | ✅ | `go.mod` |
