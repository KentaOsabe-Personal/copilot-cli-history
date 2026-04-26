# GitHub Copilot CLI 会話履歴参照アプリ 実装プラン

## 問題

事前調査をもとに、GitHub Copilot CLI のローカル会話履歴を参照できるアプリを新規構築する。  
対象リポジトリの現状は調査メモのみで、アプリ実装・環境構築・開発規約は未着手である。

## 前提と提案方針

- モノレポ構成は `frontend/` と `backend/` を基本とする。
- 初手は Docker Compose による開発環境構築を行う。
- フロントエンドは React + TypeScript + Vite + pnpm + Vitest を採用する。
- バックエンドは Rails を API モードで構築し、RSpec を採用する。
- 会話履歴の一次ソースは `COPILOT_HOME` または `~/.copilot` 配下の raw files とする。
- MySQL は MVP から採用し、正規化済みセッションデータの保存先として使う。
- 読み取り対象は `session-state/<session-id>/workspace.yaml`、`session-state/<session-id>/events.jsonl`、`history-session-state/*.json` とする。
- GitHub Copilot CLI の対話操作や非公開 API には依存せず、ファイル読取ベースで実装する。
- 仕様駆動開発は、環境構築完了後に要件ごとに「仕様定義 -> 失敗テスト -> 実装 -> 検証」の cc-sdd サイクルで進める。
- CSS フレームワークは、画面試作と一覧 UI の実装速度を優先して Tailwind CSS を第一候補とする。

## 想定アーキテクチャ

1. `backend` がローカルの Copilot CLI セッションファイルを走査・正規化する。
2. `backend` は raw files を正規化して MySQL に保存し、セッション一覧、詳細タイムライン、検索・フィルタ用 API を提供する。
3. `frontend` がセッション一覧、会話詳細、検索 UI を提供する。
4. MySQL は検索・フィルタ・将来の増分同期の基盤として扱う。

## 実装フェーズ

### Phase 0. 要件整理

- MVP の範囲を確定する。
- MySQL を初期フェーズから使う前提で、MVP 対象機能を確定する。
- 初期対象機能を次の候補から切り分ける。
  - セッション一覧
  - 会話タイムライン表示
  - 全文検索
  - リポジトリ / ブランチ / 日付 / モデルのフィルタ
  - 自動更新監視

### Phase 1. 開発環境構築

- ルートに Docker Compose、共通 README、開発手順を整備する。
- `frontend/` に React/Vite/TypeScript/pnpm/Vitest の基盤を作る。
- `backend/` に Rails API / RSpec の基盤を作る。
- ポートを以下で固定する。
  - frontend: `51730`
  - backend: `30000`
  - mysql: `33006`（採用時のみ）
- ホットリロード、テスト実行、コンテナ間接続を確認できる状態にする。

### Phase 2. cc-sdd 開発フロー定義

- 要件ごとに仕様ファイル、受け入れ観点、テスト配置ルールを定義する。
- frontend/backend それぞれのテスト戦略を決める。
  - frontend: Vitest
  - backend: RSpec
- 仕様駆動開発の 1 サイクルをリポジトリ内で再現できるテンプレートを用意する。

### Phase 3. バックエンドの履歴読取基盤

- `COPILOT_HOME` 優先、未設定時 `~/.copilot` を使う設定解決層を作る。
- 現行形式 reader を実装する。
  - `workspace.yaml` の読取
  - `events.jsonl` のストリーム/逐次パース
- 旧形式 reader を実装する。
  - `history-session-state/*.json` の読取
- 不明イベント型でも raw JSON を保持できる正規化モデルを設計する。

### Phase 4. バックエンド API とドメイン整備

- セッション一覧 API を定義する。
- セッション詳細タイムライン API を定義する。
- 検索・フィルタ API の要否を MVP に合わせて定義する。
- エラーハンドリング方針を定義する。
  - Copilot 履歴が存在しない
  - 壊れた JSONL 行がある
  - 権限不足
  - 形式差分で一部イベントが正規化できない

### Phase 5. フロントエンド UI 実装

- レイアウトとナビゲーションを定義する。
- セッション一覧画面を実装する。
- 会話タイムライン画面を実装する。
- 必要なら検索バー、フィルタ、再読み込み UI を実装する。
- 長文・ツール呼び出し・コードブロックの表示ルールを固める。

### Phase 6. 検索・永続化・更新監視

- MySQL の正規化済みテーブルを設計する。
  - `sessions`
  - `events`
  - `messages`
  - `tool_calls`
- 初回取り込みと再取り込みの戦略を定義する。
- `events.jsonl` の追記監視による増分取り込みの要否を決める。

### Phase 7. 品質・運用整備

- Docker 上で frontend/backend テストを回せるようにする。
- 設定方法、`COPILOT_HOME` の扱い、機密情報への注意点を文書化する。
- ローカル専用閲覧アプリを基本とし、外部送信は扱わない前提を明文化する。

## 初期 Todo

1. MVP 範囲と MySQL 前提の永続化方針を確定する。
2. モノレポ + Docker Compose の開発基盤を作る。
3. frontend の React/Vite/TypeScript/Tailwind/Vitest 基盤を作る。
4. backend の Rails API/RSpec 基盤を作る。
5. cc-sdd 用の仕様テンプレートと開発フローを定義する。
6. Copilot 履歴 reader と正規化モデルを実装する。
7. セッション一覧/詳細 API を実装する。
8. セッション一覧/詳細 UI を実装する。
9. 検索・フィルタ・更新監視の要件を満たす実装を追加する。
10. 運用ドキュメントと開発手順を整える。

## 主要な判断ポイント

- **DB 方針**: MySQL を MVP から採用し、検索・フィルタ・将来の高速化を見据えた正規化ストアを先に用意する。
- **Rails 構成**: frontend 分離のため API モードを前提にする。
- **データ互換**: 新形式 `session-state` と旧形式 `history-session-state` の両対応を初期から前提にする。
- **機密性**: ローカル閲覧を前提とし、会話履歴の外部送信機能は初期スコープに含めない。

## リスクと注意点

- Copilot CLI の内部保存形式は将来変更され得るため、reader は adapter 分離を前提にする。
- `events.jsonl` は追記途中の不完全行を含み得るため、増分読取時は再試行前提にする。
- MySQL を使っても raw files が source of truth である点は維持し、再取り込み可能な設計にする。
- 指定バージョンの Docker image / runtime availability は環境構築フェーズで実確認が必要。
