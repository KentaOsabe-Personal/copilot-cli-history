# Brief: history-db-read-model

## Problem

GitHub Copilot CLI のローカル会話履歴を参照する利用者は、将来的に日付フィルタや初期表示期間指定を高速かつ安定して使いたい。現在の画面表示 API は raw files reader を直接参照しているため、一覧条件を SQL query として処理できず、DB を前提にした read model が存在しない。

## Current State

`backend-history-reader` は current / legacy の raw files を正規化し、`backend-session-api` はその結果を read-only API として返している。MySQL は存在するが、Copilot セッションの表示用 payload、同期結果、source fingerprint を保持する schema / model はまだない。

## Desired Outcome

`copilot_sessions` に 1 session 1 row の read model を保存できる。`history_sync_runs` に同期実行結果を記録できる。`NormalizedSession` から既存 presenter payload に近い `summary_payload` / `detail_payload` と、source file の path / mtime / size に基づく `source_fingerprint` を作れる。

## Approach

Rails migration と ActiveRecord model を追加し、DB 上では履歴由来日時を `created_at_source` / `updated_at_source` として row timestamp から分離する。`CopilotHistory::Persistence` 名前空間に payload builder と fingerprint builder を置き、既存 reader / presenter の contract を再利用して DB 保存用 attributes を組み立てる。

## Scope

- **In**: `copilot_sessions` migration、`history_sync_runs` migration、`CopilotSession` model、`HistorySyncRun` model、model validation、date filter 用 index、`summary_payload` / `detail_payload` / `source_paths` / `source_fingerprint` の保存 contract、`NormalizedSession` から DB attributes を作る builder。
- **Out**: raw files の実読取を起動する同期 service、HTTP controller、既存 session API の DB query 化、frontend UI、削除同期、background job。

## Boundary Candidates

- DB schema / model と同期実行 orchestration を分ける。
- payload builder は existing presenter contract を利用し、controller や sync API の response mapping を持たない。
- fingerprint builder は source file metadata の比較材料だけを作り、skip / update 判断は sync service に委譲する。

## Out of Boundary

- `POST /api/history/sync` の route / controller。
- `GET /api/sessions` / `GET /api/sessions/:id` の参照元切替。
- frontend の同期ボタンや空状態表示。
- raw files が削除された session の DB 削除。

## Upstream / Downstream

- **Upstream**: `backend-history-reader` の `NormalizedSession`、既存 presenter、Rails / MySQL。
- **Downstream**: `history-sync-api` が upsert 先として利用する。`session-api-db-query` が DB query の source として利用する。

## Existing Spec Touchpoints

- **Extends**: なし。新しい永続化 boundary として扱う。
- **Adjacent**: `backend-history-reader` の正規化 contract、`backend-session-api` の response shape。既存 API spec は永続化を out of scope にしているため、ここでは API 切替を扱わない。

## Constraints

raw files は一次ソースであり、DB は再生成可能な read model とする。`created_at` / `updated_at` は Rails row timestamp として残し、履歴由来日時は source suffix の列で扱う。初期実装では `detail_payload` と `summary_payload` を JSON として保存し、contract 変更時は再同期で再生成できる前提にする。
