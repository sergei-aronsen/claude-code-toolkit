# Claude Guides — クイックリファレンス

## コマンド

| コマンド | 機能 |
|---------|------|
| `/plan` | コーディング前に実装計画を作成 |
| `/debug` | 体系的デバッグ（4フェーズ） |
| `/verify` | コミット前チェック：ビルド、型、lint、テスト |
| `/audit` | 監査：セキュリティ、パフォーマンス、コード、デザイン、DB |
| `/test` | モジュールのテストを作成 |
| `/tdd` | テスト駆動開発：テストを先に、コードを後に |
| `/fix` | 特定の問題を修正 |
| `/refactor` | 動作を変えずに構造を改善 |
| `/explain` | コードやアーキテクチャの仕組みを説明 |
| `/doc` | ドキュメントを生成 |
| `/learn` | 解決策を `.claude/learned/` に保存（将来のセッション用） |
| `/context-prime` | セッション開始時にプロジェクトコンテキストを読み込み |
| `/checkpoint` | 進捗をスクラッチパッドに保存 |
| `/handoff` | タスクの引き継ぎ（要約と次のステップ付き） |
| `/install` | claude-guides をプロジェクトにインストール |
| `/worktree` | 並行ブランチ用の git worktrees を管理 |
| `/migrate` | データベースマイグレーションの作成・デバッグ |
| `/find-function` | 関数やクラスの定義を検索 |
| `/find-script` | package.json、Makefile 等のスクリプトを検索 |
| `/docker` | Dockerfile と docker-compose を生成 |
| `/api` | REST API を設計、OpenAPI スペックを生成 |
| `/e2e` | Playwright で E2E テストを生成 |
| `/perf` | パフォーマンス分析：N+1、バンドル、メモリ |
| `/deps` | 依存関係監査：セキュリティ、ライセンス、古いバージョン |

---

## エージェント

深い分析のためのエージェント：

| エージェント | 呼び出し方 | 目的 |
|------------|-----------|------|
| Code Reviewer | `/agent:code-reviewer` | チェックリストに基づくコードレビュー |
| Test Writer | `/agent:test-writer` | TDD アプローチでテスト生成 |
| Planner | `/agent:planner` | タスクをフェーズ付き計画に分解 |
| Security Auditor | `/agent:security-auditor` | 深いセキュリティ分析 |

---

## 監査

`/audit {タイプ}` で実行：

| タイプ | チェック内容 |
|--------|------------|
| `security` | SQLインジェクション、XSS、CSRF、認証、シークレット |
| `performance` | N+1クエリ、キャッシュ、遅延読み込み、バンドルサイズ |
| `code` | パターン、可読性、SOLID、DRY |
| `design` | UI/UX、アクセシビリティ、レスポンシブ |
| `mysql` | インデックス、遅いクエリ、performance_schema |
| `postgres` | pg_stat_statements、ブロート、接続 |
| `deploy` | デプロイ前チェックリスト |

---

## スキル

スキルはコンテキストに基づいて自動的にアクティブ化：

| スキル | アクティブ化タイミング |
|--------|---------------------|
| Database | マイグレーション、インデックス、クエリ |
| API Design | REST エンドポイント、OpenAPI、ステータスコード |
| Docker | コンテナ、Dockerfile、Compose |
| Testing | テスト、モック、カバレッジ |
| Tailwind | CSSスタイリング、レスポンシブデザイン |
| Observability | ロギング、メトリクス、トレーシング |
| LLM Patterns | RAG、エンベディング、ストリーミング |
| AI Models | モデル選択、料金、コンテキストウィンドウ |

---

## ワークフロー

### 3つのフェーズ（必須）

```text
RESEARCH（読み取り専用）--> PLAN（スクラッチパッドのみ）--> EXECUTE（フルアクセス）
```

### 思考レベル

| レベル | 使用場面 |
|--------|---------|
| `think` | シンプルなタスク、クイックフィックス |
| `think hard` | 複数ステップの機能、リファクタリング |
| `ultrathink` | アーキテクチャ決定、複雑なデバッグ |

---

## シナリオ — いつ何を使うか

### バグを見つけた

```text
/debug バグの説明
```

Claude は修正前に根本原因を調査。修正後：`/verify`

### コードレビューが必要

```text
/audit code
```

完全なレビュー：`/audit security`、次に `/audit performance`

### 新機能を追加したい

```text
/plan 機能の説明
```

Claude がスクラッチパッドに計画を作成。承認後に実行。その後：`/verify`

### テストを書く必要がある

```text
/tdd モジュール名
```

まず失敗するテストを書き、次にそれを通す最小限のコードを書く。

### デプロイ前

```text
/verify
/audit security
/audit deploy
```

3つすべて実行して、本番前に問題をキャッチ。

### 新しいセッションを開始

```text
/context-prime
```

プロジェクトコンテキストを読み込み、Claude が最初からコードベースを理解。

### タスクを他の開発者に引き継ぐ

```text
/handoff
```

要約を作成：完了した作業、現在の状態、次のステップ。

### 安全にリファクタリング

```text
/refactor 対象コード
```

Claude は動作を保持しながらリファクタリング。常にテストを実行。

### 知らないコードを理解したい

```text
/explain path/to/file.ts
/explain 認証フロー
```

### データベース作業

```text
/migrate users テーブルを作成
/audit mysql
/audit postgres
```

### パフォーマンス問題

```text
/perf
/audit performance
```

### 依存関係チェック

```text
/deps
```

### REST API が必要

```text
/api users のエンドポイントを設計
```

### Docker 設定

```text
/docker
```

### E2E テスト

```text
/e2e ユーザー登録とログイン
```

---

## MCP サーバー

| サーバー | 目的 |
|---------|------|
| context7 | 最新のライブラリドキュメント |
| playwright | ブラウザ自動化、UIテスト、スクリーンショット |
| sequential-thinking | ステップバイステップの問題解決 |

---

## クイックヒント

- 大きな機能の前には常に `/plan` を使用 — 無駄な作業を防止
- 各コミット前に `/verify` を実行 — 問題を早期に発見
- 難しい問題を解決した後は `/learn` を使用 — 将来のセッションのために知識を保存
- セッションは `/context-prime` で開始 — コンテキストがあると Claude はより良く動作
- 長いタスクでは `/checkpoint` を使用 — セッションが切断されても進捗を保存
- `/debug` は「とりあえず直してみる」より良い — 体系的アプローチの方が速い
