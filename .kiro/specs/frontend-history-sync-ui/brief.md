# Brief: frontend-history-sync-ui

## Problem

DB が空の初期状態では、利用者が画面から履歴を取り込む導線がないと、DB query 化後の一覧が空のままに見える。既存 `frontend-session-ui` は read-only 閲覧に集中しており、再読み込み操作や同期操作は out of scope である。

## Current State

frontend は session list/detail API を使って一覧と詳細を表示する想定である。同期 API と DB read model はまだ UI から呼ばれておらず、DB が空のときに「履歴を取り込む」状態を案内する設計もない。

## Desired Outcome

一覧画面に「履歴を最新化」ボタンを追加し、押下時に `POST /api/history/sync` を呼ぶ。同期中はボタンを disabled にし、成功後は一覧を再取得する。DB が空の場合は「履歴を取り込む」状態を表示し、同期失敗時は成功表示と誤認しない error state を表示する。

## Approach

sessions feature slice の既存 API / hook / page 構成に沿って、sync API client と同期状態管理を追加する。既存の一覧・詳細表示を壊さず、まずは raw reader 経由の一覧が残っている段階でも同期ボタンを動かせるようにし、session API DB query 化後は DB 空状態の primary action として機能させる。

## Scope

- **In**: sync API client、一覧画面の履歴最新化ボタン、同期中 disabled / loading、同期成功後の一覧再取得、同期失敗 error state、DB 空状態の取り込み導線、frontend tests、必要に応じた README の初回同期説明。
- **Out**: 日付フィルタ UI、検索 UI、自動更新、background sync の進捗 polling、認証・認可、詳細画面の再設計。

## Boundary Candidates

- sync 操作は sessions feature の API / hook に閉じる。
- list page は既存 session list rendering を維持し、同期状態と empty state の表示だけを追加する。
- sync result の詳細表示は最小限にし、最終同期日時 API は必要になった場合の後続候補にする。

## Out of Boundary

- backend sync service / controller。
- session API の DB query 化。
- 日付範囲 UI やデフォルト期間の選択 UI。
- raw files の削除や DB の手動編集。

## Upstream / Downstream

- **Upstream**: `history-sync-api`、既存 session list API、将来の `session-api-db-query`。
- **Downstream**: 利用者の初回取り込み体験、将来の日付フィルタ UI。

## Existing Spec Touchpoints

- **Extends**: `frontend-session-ui` の一覧画面に、read-only 閲覧を補助する明示同期操作を追加する。
- **Adjacent**: `session-ui-noise-reduction` と `conversation-ui-readability` の表示改善方針を壊さず、操作追加は一覧画面の主要導線に限定する。

## Constraints

同期操作は backend の `POST /api/history/sync` を唯一の raw files 読取入口として扱う。同期成功後は `GET /api/sessions` を再取得する。同期中の二重押下を防ぐ。DB query 化前後の移行期間でも既存閲覧体験を壊さない。
