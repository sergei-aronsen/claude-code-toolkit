# Claude Code Toolkit のインストールと使い方

> ゼロから Claude Code での生産的な開発までの完全な経路を、一箇所にまとめた。

**[English](en.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **日本語** | **[Português](pt.md)** | **[한국어](ko.md)**

---

## 前提条件

以下が入っていることを確認：

- **Node.js** —— `node --version`（20.x 以降推奨）
- **Claude Code** —— `claude --version`
- **git** —— `.claude/` をリポジトリにコミットするため
- **jq** —— インストーラが `settings.json` をマージするのに必要（`brew install jq` / `apt install jq`）

Claude Code がまだ入っていなければ：

```bash
npm install -g @anthropic-ai/claude-code
```

---

## インストール

プロジェクトフォルダに `cd` し、**普通のターミナル**で（Claude Code の中ではダメ）実行：

```bash
cd ~/Projects/my-app
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

インストーラは全コンポーネント入りの TUI チェックリストを開きます：

```text
[x] toolkit              ← toolkit のコンテンツ（プロジェクトの .claude/）
[x] security             ← グローバルな security pack + cc-safety-net
[ ] rtk                  ← 冗長な開発コマンド出力を書き換え（-60-90% トークン）
[ ] statusline           ← ステータスバーにセッション/週次の使用量
[ ] council              ← /council = Gemini + ChatGPT のプラン検証
[ ] gemini-bridge        ← CLAUDE.md → GEMINI.md 自動同期
[ ] codex-bridge         ← CLAUDE.md → AGENTS.md 自動同期
[ ] mcp-servers (24)     ← インテグレーション TUI チェックリスト（Stripe, Sentry, dbhub, …）
[ ] skills (22)          ← marketplace skill（i18n, shadcn, stripe, …）
```

`スペース` で切替、`↑/↓` で移動、`Enter` でチェック済みをインストール。

インストーラは特徴ファイルからフレームワーク（Laravel, Next.js, Python, Go, …）を検出し、対応する `CLAUDE.md` テンプレートを配置します。`superpowers` と `get-shit-done` が既に入っていれば、それらのプラグインが既に提供するファイルはスキップし、toolkit 固有の約 47 件の貢献だけを入れます。

完了後、ローカルの HTML ページが `.claude/setup-guide.html` で開き、インストール済み MCP ごとの手順（API key の取り方、設定すべき env 変数、テスト方法）が並びます。

---

## コミットして使い始める

```bash
git add .claude/ CLAUDE.md
git commit -m "chore: add Claude Code toolkit configuration"
claude
```

Claude Code が起動し、自動的に読み込みます：

1. グローバルな `~/.claude/CLAUDE.md`（セキュリティルール —— スクリプトが配置）
2. プロジェクトの `CLAUDE.md`（スタックに合わせた内容 —— プロジェクト固有の詳細を追記可）
3. `.claude/commands/` の全コマンドと marketplace の skill

---

## 便利なコマンド

| コマンド           | 機能                                                                           |
|--------------------|--------------------------------------------------------------------------------|
| `/update-toolkit`  | toolkit の最新コンテンツを取り込み、`CLAUDE.md` のローカル編集を保持。         |
| `/update-deps`     | 依存ダッシュボード（Layer 1/2/3 + MCP）を開き、更新対象を選ぶ。                |
| `/council プラン`  | プランを Gemini + ChatGPT に送り独立レビュー。                                 |
| `/learn`           | 現在の決定を scoped rule として保存し、今後のセッションで使う。                |
| `/audit security`  | 7 種類のフレームワーク対応監査の一つを実行。                                  |
| `/debug 問題`      | 4 フェーズの体系的デバッガ。                                                  |
| `/setup-guide`     | ローカル HTML 設定ガイドを再生成。                                             |
| `/helpme`          | 全コマンドのチートシート。                                                    |

---

## 全体フロー

```text
┌────────────────────────────────────────────────────────┐
│  インストール（プロジェクトごとに 1 回）                │
│                                                        │
│  $ cd ~/Projects/my-app                                │
│  $ bash <(curl -sSL …/install.sh)                      │
│  → TUI チェックリスト → スペース/Enter                  │
│                                                        │
│  結果：                                                │
│   ~/.claude/CLAUDE.md       ← セキュリティルール       │
│   .claude/                  ← コマンド・skill・agent   │
│   CLAUDE.md                 ← スタック対応テンプレート │
│   .claude/setup-guide.html  ← MCP の API 設定ガイド    │
└────────────────────────────────────────────────────────┘
                       │
                       ▼
┌────────────────────────────────────────────────────────┐
│  日常の作業                                            │
│                                                        │
│  $ claude                                              │
│  > /plan 認証を追加する                                │
│  > /debug /api/users で 500                            │
│  > /audit security                                     │
│  > /council DB 移行プラン                              │
└────────────────────────────────────────────────────────┘
```

---

## アップデート

```bash
cd ~/Projects/my-app
# Claude Code 内で：
> /update-toolkit   # toolkit のコンテンツ
> /update-deps      # 全依存（チェックボックス付き TUI）
```

`/update-deps` は installed-vs-latest つきの完全な TUI リストを表示します。更新するものを選び、それ以外はそのまま。

---

## Claude Desktop

Desktop ユーザーは marketplace 経由でインストール：

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

3 つのサブプラグインを取得します：`tk-skills`（22 skill）、`tk-commands`（29 コマンド）、`tk-framework-rules`（7 つの CLAUDE.md フラグメント）。詳細：[docs/CLAUDE_DESKTOP.md](../CLAUDE_DESKTOP.md)。

---

## トラブルシューティング

| 問題                                                | 対処                                                                                       |
|-----------------------------------------------------|--------------------------------------------------------------------------------------------|
| インストール後 `cc-safety-net: command not found`   | `npm install -g cc-safety-net`、その後 `bash <(curl …/scripts/install-hooks.sh)`           |
| RTK がコマンドを書き換えない                        | `~/.claude/settings.json` には**統合された 1 つの**フックが必要（2 つに分けない）           |
| Claude がプロジェクトのコマンドを見つけない         | `.claude/` がある同じフォルダで `claude` を再起動                                          |
| safety-net が必要なコマンドをブロックする           | 普通のターミナルで手動実行（または一時的に `TK_NO_SAFETY=1`）                              |
| インストーラが TUI で固まる                         | `Ctrl-C` で再起動；macOS `bash` 3.2 では ↑/↓ に `--no-tui-fallback` が必要なことあり        |
| `setup-guide.html` が開かない                       | `open .claude/setup-guide.html`（macOS）/ `xdg-open`（Linux）。または `/setup-guide` を実行。 |
