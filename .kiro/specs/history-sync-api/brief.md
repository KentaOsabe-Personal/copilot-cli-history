# Brief: history-sync-api

## Problem

画面表示を最終的に DB のみに寄せるには、利用者が明示的に raw files を読み取り、DB read model を更新できる操作が必要である。現在は raw files reader が session API から直接呼ばれており、DB 登録の実行履歴、差分判定、失敗記録が存在しない。

## Current State

既存 reader は root failure と session 単位の degraded を識別できる。`history-db-read-model` により DB 保存先と payload builder が用意される想定だが、reader を呼び出して upsert する同期 service と HTTP API はまだない。

## Desired Outcome

`POST /api/history/sync` により backend が `COPILOT_HOME` 配下を読み取り、`copilot_sessions` に insert / update / skip できる。同期開始・終了・成功・失敗・件数を `history_sync_runs` に記録し、root failure は failed run と error response として返せる。

## Approach

`CopilotHistory::Persistence::HistorySyncService` を追加し、`SessionCatalogReader`、record builder、fingerprint 比較、DB 保存、sync run 更新を集約する。`Api::HistorySyncController` は service result を JSON に写像する薄い入口にし、初期実装では同期処理を request 内で完結させる。

## Scope

- **In**: sync service、fingerprint による session 単位の skip / update / insert 判定、root failure の failed run 記録、degraded session の保存継続、sync result JSON、`POST /api/history/sync` route / controller、二重実行時の初期方針、backend request / service tests。
- **Out**: background job、自動 file watch、削除同期、frontend のボタン実装、既存 session API の DB query 化、日付フィルタ UI。

## Boundary Candidates

- sync service は raw reader 実行と DB upsert の orchestration を持つ。
- controller は service result の HTTP status / JSON mapping だけを持つ。
- fingerprint の生成は `history-db-read-model` 側、fingerprint の比較判断は sync service 側に置く。

## Out of Boundary

- DB schema / model の詳細設計。
- session list/detail API の参照元切替。
- frontend 空状態や最終同期日時の表示。
- `GET /api/history/sync_runs/latest` は必要になった場合の隣接候補に留める。

## Upstream / Downstream

- **Upstream**: `history-db-read-model`、`backend-history-reader`、既存 presenter contract。
- **Downstream**: `frontend-history-sync-ui` が同期操作として呼び出す。`session-api-db-query` は同期済みデータを前提に DB 参照へ切り替える。

## Existing Spec Touchpoints

- **Extends**: なし。新しい同期 boundary として扱う。
- **Adjacent**: `backend-session-api` は raw reader 経由の read-only API を提供済みだが、この spec は raw files 読取を同期 API に閉じ込める新しい入口を扱う。

## Constraints

初期実装では同期処理を同期的に実行する。raw files が消えた session は DB から削除しない。`running` の sync run がある場合は 409 を返す案を初期方針とする。DB query 化が完了するまでは既存閲覧 API を raw reader のまま維持する。
