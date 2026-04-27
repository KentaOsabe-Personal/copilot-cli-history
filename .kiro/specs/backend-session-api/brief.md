# Brief: backend-session-api

## Problem
GitHub Copilot CLI のローカル会話履歴を参照したい開発者は、backend で正規化済みの履歴オブジェクトを読めても、それを一覧表示や詳細タイムライン表示に使える HTTP API がまだありません。  
そのため frontend は履歴 reader を直接利用できず、セッション一覧・詳細表示のための安定した取得境界とエラー契約が不足しています。

## Current State
既存の `backend-history-reader` spec は、`COPILOT_HOME` / `~/.copilot` 配下の新旧履歴形式を読み取り、共通オブジェクトへ正規化する責務までを定義しています。  
一方で、セッション一覧 API、セッション詳細タイムライン API、API レスポンス形式、HTTP エラーへの写像、MVP で扱う検索・フィルタ境界は未定義です。

## Desired Outcome
backend が read-only の HTTP API として、セッション一覧とセッション詳細タイムラインを安定して返せるようになる。  
また、履歴未存在、権限不足、壊れた JSONL、部分的に正規化できないイベントなどを、frontend や将来の利用側が識別しやすい形で返せるようにする。

## Approach
Phase4 は **Query/Presenter 分離型** で進める。  
controller は HTTP 入出力と status code だけを担当し、アプリ層の query が `backend-history-reader` を呼び、presenter/serializer が一覧・詳細用のレスポンス形へ変換する。これにより、Phase4 の責務を read-only API に保ちながら、将来の検索・永続化追加にも伸ばしやすくする。

## Scope
- **In**: セッション一覧 API、セッション詳細タイムライン API、reader の結果を API レスポンスへ写像する query/presenter 層、MVP 向けエラーハンドリング方針の定義
- **Out**: repo / branch / date / model の検索・フィルタ API、永続化スキーマ、増分同期や監視、frontend 実装、認証・認可

## Boundary Candidates
- セッション一覧取得を担う query とレスポンス整形
- セッション詳細タイムライン取得を担う query とレスポンス整形
- 履歴 reader の失敗結果を HTTP エラーへ写像する API 境界

## Out of Boundary
- `workspace.yaml` / `events.jsonl` / legacy JSON のパースや正規化責務
- MySQL を使った検索最適化や再取り込み設計
- UI 向けの画面状態管理や表示ロジック
- 履歴の自動更新監視や watch ベースの同期

## Upstream / Downstream
- **Upstream**: `backend-history-reader` が返す共通オブジェクトと失敗結果、Rails API 実行環境、ローカルの Copilot CLI 履歴ファイル
- **Downstream**: frontend のセッション一覧画面、会話タイムライン画面、将来の検索・フィルタ spec、将来の永続化 spec

## Existing Spec Touchpoints
- **Extends**: なし
- **Adjacent**: `backend-history-reader` spec。reader の責務は再利用し、API 層で再実装しない

## Constraints
- Rails API mode と既存の RSpec request spec 構成に沿うこと
- raw files を正本とし、API 層は reader の結果をそのまま活かすこと
- MVP では一覧 API と詳細 API に集中し、検索・フィルタは後続 spec に分離すること
- エラーは silent fallback にせず、利用側が識別可能な形で返すこと
