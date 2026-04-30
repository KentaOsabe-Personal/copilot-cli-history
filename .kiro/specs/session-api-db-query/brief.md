# Brief: session-api-db-query

## Problem

日付範囲指定や初期表示のデフォルト期間を実装するには、session list/detail API が raw files を毎回読むのではなく、DB read model を query する必要がある。現在の `backend-session-api` は永続化と date / repo / branch / model filter を out of scope としており、DB query layer がない。

## Current State

`GET /api/sessions` と `GET /api/sessions/:id` は既存 reader / presenter を通じて raw files 由来の response を返す。`history-sync-api` が完成するまではこの状態を維持し、DB が未投入でも従来どおり履歴を参照できるようにする必要がある。

## Desired Outcome

同期 API と frontend 同期導線が動作した後、`GET /api/sessions` と `GET /api/sessions/:id` は DB のみを参照する。一覧は `from` / `to` / `limit` を受け、`COALESCE(updated_at_source, created_at_source)` を基準に日付範囲と並び順を処理する。詳細は `detail_payload` を返し、DB に無い session は `session_not_found` を返す。

## Approach

`CopilotHistory::Api::DbSessionIndexQuery` と `DbSessionDetailQuery` を追加し、ActiveRecord query と payload 取り出しを controller から分離する。response shape は既存 `SessionIndexPresenter` / detail presenter の payload に極力合わせ、controller 切替時の frontend 影響を抑える。

## Scope

- **In**: DB query layer、`GET /api/sessions?from=...&to=...&limit=...`、デフォルト期間の backend 適用、`GET /api/sessions/:id` の DB detail payload 返却、DB 空一覧の 200 + empty data、DB 未登録 detail の 404、request specs、既存 API contract との互換確認。
- **Out**: sync service、frontend 同期ボタン、検索 UI、repo / branch / model filter UI、raw files への fallback、削除同期。

## Boundary Candidates

- DB query class は ActiveRecord 条件と payload 取得に集中する。
- controller は既存 API route / status contract を保ちつつ query class を呼ぶ。
- 日付範囲指定は SQL 条件として扱い、frontend presentation には持ち込まない。

## Out of Boundary

- DB read model の schema / builder。
- `POST /api/history/sync` の実装。
- frontend empty state の文言や同期操作。
- 検索や高度な絞り込み。

## Upstream / Downstream

- **Upstream**: `history-db-read-model`、`history-sync-api`、既存 `backend-session-api` の response contract。
- **Downstream**: frontend の一覧・詳細表示、将来の日付フィルタ UI、検索 UI。

## Existing Spec Touchpoints

- **Extends**: `backend-session-api` の session list/detail 契約を参照元だけ DB に切り替える。
- **Adjacent**: `frontend-session-ui` は一覧・詳細の表示契約に依存する。response shape の不要な変更を避ける。

## Constraints

この切替は同期 API と frontend 同期導線が完成してから実施する。DB query 化後は raw files への fallback をしない。`from` / `to` 未指定時の初期案は直近 30 日とするが、仕様化時に確定する。並び順は `COALESCE(updated_at_source, created_at_source) DESC, session_id ASC` を基準にする。
