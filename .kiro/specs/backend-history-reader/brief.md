# Brief: backend-history-reader

## Problem
GitHub Copilot CLI のローカル会話履歴を参照するアプリを実装したいが、現状の backend には履歴ファイルを読む基盤が存在しない。  
新形式 `session-state` と旧形式 `history-session-state` の両方に対応しつつ、後続の API 実装や永続化設計に依存しない読取基盤が必要である。

## Current State
リポジトリには Rails API / RSpec の基盤はあるが、`COPILOT_HOME` 解決、`workspace.yaml` 読取、`events.jsonl` の逐次パース、旧形式 JSON 読取、正規化モデルは未実装である。  
また `.kiro/specs/` に既存 spec はなく、Phase3 の責務を独立した spec として新規に定義する必要がある。

## Desired Outcome
`COPILOT_HOME` 優先・未設定時 `~/.copilot` で履歴ルートを解決できる。  
新形式・旧形式の履歴ファイルを個別 reader で読み取り、共通の正規化オブジェクトへ変換できる。  
未知のイベント型や完全に解釈できないイベントでも raw JSON を保持でき、Phase4 以降の API/ドメイン層がこの読取基盤を利用できる状態にする。

## Approach
Reader Adapter 分離型を採用する。  
`COPILOT_HOME` 解決、現行形式 reader、旧形式 reader、正規化処理を責務ごとに分け、形式差分は reader 側に閉じ込める。これにより Phase3 を「読取基盤」に限定し、Phase4 の入口設計や Phase6 の永続化設計を先食いしない。

## Scope
- **In**:
  - `COPILOT_HOME` / `~/.copilot` の設定解決層
  - `workspace.yaml` の安全な読取
  - `events.jsonl` の逐次パース
  - `history-session-state/*.json` の読取
  - 共通の正規化オブジェクト設計
  - 未知イベントの raw JSON 保持方針
  - reader / normalizer の RSpec による検証
- **Out**:
  - セッション一覧 API / 詳細 API
  - Rails アプリケーションからの公開入口設計
  - MySQL 永続化スキーマ
  - 増分同期や監視
  - UI 実装

## Boundary Candidates
- 履歴ルート解決 (`COPILOT_HOME` と既定パス)
- 現行形式 reader (`workspace.yaml`, `events.jsonl`)
- 旧形式 reader (`history-session-state/*.json`)
- 正規化モデル / raw event 保持

## Out of Boundary
- API のレスポンス形状やエラーレスポンス設計
- 永続化先テーブルや再取り込み戦略
- フロントエンド向け表示整形
- ファイル監視や自動更新

## Upstream / Downstream
- **Upstream**: ローカルの Copilot CLI 履歴ファイル、Docker Compose の実行環境設定
- **Downstream**: Phase4 のバックエンド API / ドメイン整備、Phase6 の永続化・検索・更新監視

## Existing Spec Touchpoints
- **Extends**: なし
- **Adjacent**: `copilot-cli-session-history-plan.md` の Phase4 / Phase6 と責務境界を共有する

## Constraints
- Docker から履歴を読む場合は `COPILOT_HOME` または `~/.copilot` を read-only bind mount する前提とする
- `workspace.yaml` は `Psych.safe_load` を前提に扱う
- raw files を source of truth とし、reader は永続化方式に依存しない
- 不明イベント型でも raw JSON を失わない
