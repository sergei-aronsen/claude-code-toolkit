# Claude Code Toolkit

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-6.3.0-blue.svg)](../../CHANGELOG.md)

**[English](../../README.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **日本語** | **[Português](pt.md)** | **[한국어](ko.md)**

---

## これは何か

[**Superpowers**](https://github.com/obra/superpowers)（ブレインストーミング、サブエージェント、TDD、デバッグ）と [**Get Shit Done**](https://github.com/gsd-build/get-shit-done)（Spec → Plan → Execute）の上に乗る薄いオーバーレイで、これらのプラグインが個人の開発者向けに残すギャップを埋めます。

**対象：** [Claude Code](https://docs.anthropic.com/en/docs/claude-code) で本物のプロダクトを出荷する個人ファウンダーと一人エンジニアリングチーム。

**サポートするスタック：** Laravel · Rails · Next.js · Node.js · Python · Go。

## 埋めるギャップ

| ギャップ                              | toolkit が追加するもの                                                                                                                            |
|---------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| **マルチ AI プラン検証**              | `/council` —— あなたのプランを Gemini と ChatGPT に並列で送り、独立レビューを受ける。CLI（`gemini`、`codex`）または直接 API キーで動作。Persona オーバーレイ、ハッシュキャッシュ、コストゲート、ru ロケール。 |
| **フレームワーク文脈**                | 7 種類の `CLAUDE.md` テンプレート（base + 6 スタック）、`artisan` / `next.config` / `go.mod` / `pyproject.toml` / `package.json` で自動検出。     |
| **本番のセーフティネット**            | `cc-safety-net` が破壊的コマンド（`rm -rf /`、`git reset --hard` など）を PreToolUse でブロック —— 難読化されていても。インストーラに組み込み済み。 |
| **トークンコスト制御**                | RTK が冗長な開発コマンド出力（`git status`、テストランナー）を書き換え —— 60-90% のトークン削減。`cc-safety-net` と統合フック。                  |
| **コストルーティング**                | `better-model` が単純なタスクをより安いモデルに振り分け。自動インストールされ、インストールライフサイクルに統合される。                            |
| **シンボル対応のコード検索**          | [Serena](https://github.com/oraios/serena)（LSP、MIT、ローカル）+ ripgrep + claude-context（セマンティックベクトル）。デフォルトの Layer-3 スタック。 |
| **マルチ CLI ブリッジ**               | `CLAUDE.md` を `GEMINI.md`（Gemini CLI）と `AGENTS.md`（OpenAI Codex）に自動同期。インストールごとにドリフト検出。                                |
| **インテグレーションカタログ**        | TUI インストーラで 24 個の MCP サーバー + 8 個のコンパニオン CLI を 10 カテゴリ（Backend / Payments / Workspace / Project Management / …）から選択可能。行ごとに scope。 |
| **上限の可視化（Pro/Max）**           | Statusline がセッション/週次の使用量を表示 —— 壁にぶつかる前に分かる。                                                                            |
| **依存ダッシュボード（v6.2）**        | `/update-deps` —— 追跡中の依存（Layer 1/2/3）を installed-vs-latest と一緒にすべて並べる対話的 TUI。何を更新するかは自分で選ぶ。                  |
| **インストール後ガイド（v6.3）**      | ローカルの HTML ページ（`.claude/setup-guide.html`）を生成。MCP ごとの API キー手順とコンポーネント設定が並ぶ —— 実際にインストールしたものだけ。  |

中心的な価値はキュレーション。すべて TUI チェックボックスでオプトイン —— 強制は何もない。

## インストール

コマンド一つ。プロジェクトフォルダ内の**普通のターミナル**で実行（Claude Code の中ではダメ）：

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

インストーラは TUI チェックリスト（Toolkit、Security、RTK、Statusline、Council、Bridges、Integrations）を表示し、`superpowers` と `get-shit-done` が既に入っているかを検出します。入っている場合、それらのプラグインが既に提供しているファイルはスキップし、toolkit 固有の約 47 件の貢献だけを入れます。

Claude Desktop ユーザー —— marketplace 経由でインストール：

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

ステップバイステップの完全ガイド：[docs/howto/ja.md](../howto/ja.md)。

## インストール後

| コマンド           | 機能                                                                           |
|--------------------|--------------------------------------------------------------------------------|
| `/update-toolkit`  | toolkit の最新コンテンツを `.claude/` に取り込み、ローカル編集を保持。         |
| `/update-deps`     | 依存ダッシュボード（Layer 1/2/3 + MCP）を開き、更新対象を選ぶ。                |
| `/council`         | プランを Gemini + ChatGPT に送って独立レビュー。                               |
| `/learn`           | 現在の決定を scoped rule として保存し、今後のセッションで使う。                |
| `/audit`           | 7 種類のフレームワーク対応監査（security、performance 等）から一つを実行。     |
| `/debug`           | 4 フェーズの体系的デバッガ：root-cause → pattern → hypothesis → fix。          |
| `/setup-guide`     | インストール済み MCP/コンポーネント向けのローカル HTML 設定ガイドを再生成。    |

完全なコマンドリスト：[docs/features.md](../features.md)。

## アーキテクチャ

Toolkit v6.2 は **薄いオーバーレイ** で、三層に整理されています：

- **Layer 1** —— toolkit のコンテンツ（テンプレート、slash コマンド、コンポーネント、skill、エージェント）
- **Layer 2** —— 無料のベースプラグイン（Superpowers、Get Shit Done、ru-text）
- **Layer 3** —— オプションの外部ツール（cc-safety-net、RTK、Serena、claude-context、better-model）

完全な図：[docs/architecture.md](../architecture.md)。
個人ファウンダー / 非開発者向け：[docs/non-programmer-mode.md](../non-programmer-mode.md)。

## MCP サーバーカタログ

`--integrations` フラグ（または初回インストール後の `/integrations`）で、24 個のサーバーを 10 カテゴリ別に並べた TUI チェックリストが開きます。プロジェクトに必要なものだけを取ります。

| カテゴリ                | サーバー                                                                                |
|-------------------------|----------------------------------------------------------------------------------------|
| **docs-research**       | `context7` · `firecrawl` · `notebooklm`                                                |
| **backend**             | `aws-cloudwatch-logs` · `aws-cost-explorer` · `cloudflare` · `dbhub` · `supabase`      |
| **payments**            | `stripe`                                                                               |
| **email**               | `resend` · `mailgun`                                                                   |
| **workspace**           | `calendly` · `notion`                                                                  |
| **project-management**  | `jira` · `linear` · `youtrack`                                                         |
| **communication**       | `slack` · `telegram`                                                                   |
| **design**              | `figma`                                                                                |
| **dev-tools**           | `magic` · `openrouter` · `serena` · `claude-context` · `playwright`                    |
| **monitoring**          | `sentry` · `datadog` · `posthog`                                                       |

各サーバーは行ごとに scope を選んでインストールします（`[U]` user / `[P]` project / `[L]` local）。project スコープは資格情報を `<project>/.env`（mode 0600）に書き、自動で `.gitignore` する。`.mcp.json` には `${VAR}` の置換形式だけが入る。詳細：[docs/INTEGRATIONS.md](../INTEGRATIONS.md)。

## ライセンス

MIT —— [LICENSE](../../LICENSE) を参照。
