# Research & Design Decisions

## Summary
- **Feature**: `session-api-db-query`
- **Discovery Scope**: Extension
- **Key Findings**:
  - 既存の `copilot_sessions` は `summary_payload` と `detail_payload` を JSON object として保持し、`SessionRecordBuilder` が既存 presenter から response shape 互換の payload を生成している。
  - 現行の `SessionIndexQuery` / `SessionDetailQuery` は raw reader 経由で `NormalizedSession` を読み、controller が presenter で整形しているため、API 参照元切替では query/controller 境界の責務を明確に変える必要がある。
  - `updated_at_source` / `created_at_source` には個別 index が存在するが、表示日時は `updated_at_source` 優先、なければ `created_at_source` の派生値として扱うため、初期設計では schema 変更なしで `COALESCE` 条件を使い、性能問題が出た場合のみ派生列や複合 index を再検討する。

## Research Log

### 既存 session API の参照元と response 契約
- **Context**: `GET /api/sessions` と `GET /api/sessions/:id` を保存済み read model 参照へ切り替えるため、既存 HTTP 境界と presenter 境界を確認した。
- **Sources Consulted**: `backend/app/controllers/api/sessions_controller.rb`, `backend/lib/copilot_history/api/session_index_query.rb`, `backend/lib/copilot_history/api/session_detail_query.rb`, `backend/lib/copilot_history/api/presenters/session_index_presenter.rb`, `backend/lib/copilot_history/api/presenters/session_detail_presenter.rb`, `backend/spec/requests/api/sessions_spec.rb`
- **Findings**:
  - controller は query result の型を見て presenter に渡し、root failure と session not found を区別している。
  - 現行 query は `SessionCatalogReader` を呼ぶため、一覧・詳細のたびに raw files を読む。
  - request spec は top-level `data` / `meta`、detail の `data`、`session_not_found` error envelope、read-only route を互換性基準として固定している。
- **Implications**: DB query 化では raw reader failure は通常の API 参照では発生しない。query は保存済み payload を API-ready な hash として返し、controller は既存 error envelope を維持して render する。

### DB read model と保存 payload
- **Context**: 保存済み read model の列、payload 生成元、既存 validation を確認した。
- **Sources Consulted**: `backend/app/models/copilot_session.rb`, `backend/db/schema.rb`, `backend/db/migrate/20260430030000_create_copilot_sessions.rb`, `backend/lib/copilot_history/persistence/session_record_builder.rb`, `backend/spec/db/history_read_model_schema_spec.rb`, `backend/spec/db/history_read_model_persistence_spec.rb`
- **Findings**:
  - `CopilotSession` は `session_id` を unique key とし、`summary_payload` / `detail_payload` / `source_fingerprint` / `source_paths` を JSON object として検証する。
  - `summary_payload` は既存 `SessionIndexPresenter` の `data[0]`、`detail_payload` は既存 `SessionDetailPresenter` の `data` から生成される。
  - `created_at_source` と `updated_at_source` は nullable で、日付不明セッションを保存できる。
- **Implications**: API query は `summary_payload` と `detail_payload` を正規化済み contract として信頼する。保存 contract の変更はこの spec の境界外であり、変更時は API 互換性の再検証が必要になる。

### frontend 利用側との互換性
- **Context**: API response shape を保つ必要があるため、frontend の型と hooks を確認した。
- **Sources Consulted**: `frontend/src/features/sessions/api/sessionApi.ts`, `frontend/src/features/sessions/api/sessionApi.types.ts`, `frontend/src/features/sessions/hooks/useSessionIndex.ts`, `frontend/src/features/sessions/pages/SessionIndexPage.tsx`
- **Findings**:
  - frontend は `fetchSessionIndex()` を query param なしで呼び、`data.length === 0` を empty state として扱う。
  - `session_not_found` は 404 かつ code が一致する場合に `kind: "not_found"` として正規化される。
  - `fetchSessionDetailWithRaw()` は `include_raw=true` を付けるが、DB 保存済み detail payload は現時点で raw payload を含まない。
- **Implications**: DB 空一覧は 200 empty response にする必要がある。`include_raw=true` は互換性のため受け付けるが、raw files を再読取せず保存済み `detail_payload` の内容を返す。

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| DB payload passthrough | `CopilotSession` から保存済み summary/detail payload を取得し、API envelope を組み立てる | raw reader 非依存、既存 payload contract を最大限再利用、変更範囲が小さい | 保存 payload contract に強く依存する | 採用 |
| DB row rehydration | JSON payload や列から `NormalizedSession` を復元し、既存 presenter を再利用する | presenter 経由の一貫性が高い | 復元 layer が複雑で raw 由来 detail の欠落を再解釈しやすい | 不採用 |
| raw fallback 併用 | DB にない場合は raw reader を読む | 空 DB でも既存閲覧を保てる | 要件の raw fallback 境界に反する | 不採用 |

## Design Decisions

### Decision: 保存済み payload を API の read model contract として返す
- **Context**: 一覧・詳細 API は raw files を毎回読まず、既存 response shape と互換性を保つ必要がある。
- **Alternatives Considered**:
  1. 保存済み payload を直接返す
  2. 保存済み列から `NormalizedSession` を復元して presenter を再実行する
- **Selected Approach**: `SessionIndexQuery` は `summary_payload` の配列と `meta` を返し、`SessionDetailQuery` は `detail_payload` を返す。既存 presenter は同期時の payload 生成責務として残す。
- **Rationale**: `SessionRecordBuilder` が既存 presenter から payload を作っているため、API query 側で再整形しない方が response shape の二重定義を避けられる。
- **Trade-offs**: payload 保存 contract の品質に依存する。保存 contract が変わる場合は sync/build 側と API 側の再検証が必要になる。
- **Follow-up**: request spec で persisted payload の passthrough と shape 互換を固定する。

### Decision: 表示日時は `updated_at_source` 優先の派生値として query 内で扱う
- **Context**: 日付範囲、並び順、日付不明セッション除外を同じ規則で扱う必要がある。
- **Alternatives Considered**:
  1. SQL の `COALESCE(updated_at_source, created_at_source)` を使う
  2. 新しい `displayed_at_source` 列を追加する
  3. Ruby 側で全件読み込み後に filter/sort する
- **Selected Approach**: 初期実装は schema 変更なしで query object が `COALESCE` 相当の表示日時を使う。
- **Rationale**: 既存 schema に必要な timestamp があり、この spec は保存 contract 変更を境界外にしている。
- **Trade-offs**: 大量データで `COALESCE` が index を十分使えない可能性がある。初期のローカル履歴用途では許容し、性能問題が実測された場合に派生列または index を検討する。
- **Follow-up**: request/query spec で更新日時優先、作成日時 fallback、両方 nil 除外を確認する。

### Decision: 一覧条件 validation は controller 境界で 400 error envelope に正規化する
- **Context**: `from` / `to` / `limit` の不正値は成功応答と区別できる client error にする必要がある。
- **Alternatives Considered**:
  1. controller が param parser を呼び、query は正規化済み条件だけを受け取る
  2. query が raw `params` を受け取って validation する
- **Selected Approach**: `SessionListParams` 相当の小さな parser を API 名前空間に置き、controller は parser result に応じて query または error presenter を呼ぶ。
- **Rationale**: HTTP param validation と DB query 条件を分離でき、query object の入力 contract が明確になる。
- **Trade-offs**: 小さな追加 component が増えるが、invalid range と invalid limit のテストが局所化される。
- **Follow-up**: error code と details を request spec で固定する。

## Risks & Mitigations
- 保存済み payload と frontend 型が drift する — `SessionRecordBuilder` が既存 presenter を使う前提を維持し、request spec で persisted payload 経由の shape を検証する。
- `include_raw=true` 利用者が raw payload を期待する — DB query 化後は保存済み detail payload の範囲だけを返し、raw files 再読取をしないことを設計と spec に明記する。
- `COALESCE` query の性能が履歴量増加で悪化する — 初期実装は既存 index を活用し、性能問題が確認された場合に `displayed_at_source` 派生列の追加を再検討する。

## References
- `.kiro/steering/product.md` — raw files を一次ソース、DB を再生成可能な補助層とするプロダクト原則。
- `.kiro/steering/tech.md` — Rails API / MySQL / RSpec と Docker Compose 開発標準。
- `.kiro/steering/structure.md` — `CopilotHistory::Api` query/presenter と controller 境界の配置方針。
- `.kiro/steering/roadmap.md` — session API DB query 化の依存順と raw fallback 境界。
