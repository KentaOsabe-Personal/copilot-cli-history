# Brief: session-date-filtering

## Problem
GitHub Copilot CLI のローカル会話履歴を読み返す利用者は、セッション一覧が広い期間を一括取得すると重くなり、目的の期間に絞って会話を探しづらい。さらに、長いセッション ID、本文、tool arguments、code block などが viewport 全体を押し広げると、一覧・詳細の読解性が落ちる。

## Current State
セッション一覧 API は DB read model 参照へ切り替わっており、backend 側には `from` / `to` / `limit` の query param と日付範囲絞り込みの受け口が存在する。frontend の `sessionApiClient.fetchSessionIndex()` と `useSessionIndex()` は query param を扱わず、一覧画面にも日付フィルタ UI がない。backend の未指定時既定期間と既存 spec は直近 30 日を前提にしている。

## Desired Outcome
利用者が一覧画面で開始日・終了日を指定し、対象期間のセッションだけを取得できる。条件なしの初期表示は直近 1 週間に絞られ、必要な場合はカレンダーから範囲を広げられる。長い文字列や code block はページ全体を横スクロールさせず、必要な横方向移動は該当ブロック内に閉じる。

## Approach
新規 spec 1 つで日付フィルタを主責務として扱い、関連する小規模な UI 安定化と backend 既定値変更も同じ閲覧体験改善に含める。frontend は `SessionIndexFilters` を API client と hook に通し、`SessionDateFilter` の適用操作で `GET /api/sessions?from=...&to=...` を発行する。backend は既存の日付 query param 契約を維持したまま、未指定時の既定期間だけを直近 7 日へ変更する。既存 spec 文書は承認時点の断面として残し、この spec が差分を所有する。

## Scope
- **In**: セッション一覧の日付フィルタ UI、`from` / `to` query param の frontend 連携、filter 条件ごとの一覧 snapshot 分離、`from > to` の frontend validation、filtered empty state、同期後 reload で現在条件を維持すること、一覧・詳細の横スクロール抑制、backend 未指定時既定期間の直近 7 日化、関連 tests / README の整合
- **Out**: 検索 UI、repo / branch / model filter、並び替え UI、pagination、`limit` UI、バックグラウンド同期、自動更新、削除同期、認証・認可、raw files を一次ソースから外すこと

## Boundary Candidates
- frontend API client / hook の `SessionIndexFilters` contract
- 一覧画面の filter form と empty / validation 表示
- backend `SessionListParams` の未指定時既定期間
- 長い文字列や `<pre>` の表示を viewport 内に閉じる layout rule

## Out of Boundary
- 日付以外の絞り込み条件
- 検索やソートの新規操作
- 履歴同期処理そのものの変更
- DB read model の保存 contract 変更
- 横スクロール対策を目的にした詳細画面全体の再設計

## Upstream / Downstream
- **Upstream**: `session-api-db-query` の `from` / `to` API 契約、`frontend-session-ui` の一覧・詳細画面、`frontend-history-sync-ui` の同期完了後 reload 導線
- **Downstream**: 将来の検索 UI、repo / branch / model filter、pagination、期間指定を含む履歴探索体験

## Existing Spec Touchpoints
- **Extends**: `session-api-db-query` が定義した日付 query param 契約を利用し、未指定時既定期間だけを直近 30 日から直近 7 日へ差し替える。この差分はこの spec が所有し、既存 spec 文書は承認時点の断面として原則更新しない。
- **Adjacent**: `frontend-session-ui` の一覧・詳細表示、`session-ui-noise-reduction` と `conversation-ui-readability` の読解性改善、`frontend-history-sync-ui` の同期後再取得

## Constraints
Markdown と spec 文書は日本語で書く。Docker Compose を開発環境の正本とし、frontend は React / TypeScript / Vite / Vitest / Tailwind CSS の既存構成に従う。backend は Rails API / RSpec の既存 query / params 構成に従う。日付入力は native `input type="date"` を基本にし、無効な範囲は API 呼び出し前に frontend で止める。
