# Research & Design Decisions

## Summary
- **Feature**: `history-sync-api`
- **Discovery Scope**: Extension
- **Key Findings**:
  - 既存の `backend-history-reader` は root failure を `ReadResult::Failure`、session 単位の劣化を `ReadResult::Success` 内の `ReadIssue` として分離しているため、同期 API はこの境界をそのまま HTTP 結果と実行履歴へ写像できる。
  - `history-db-read-model` は `CopilotSession`、`HistorySyncRun`、`SessionRecordBuilder`、`SourceFingerprintBuilder` を提供済みだが、二重実行を DB レベルで防ぐ lock key と insert/update count の永続化は未定義である。
  - skip 判定は `source_fingerprint` の一致だけで決め、skip 時は `summary_payload` / `detail_payload` を再保存しない設計にすることで、raw files 正本と read model の再生成可能性を維持できる。

## Research Log

### 既存 reader の成功と失敗境界
- **Context**: root failure と degraded session を同期 API で別扱いにする要件がある。
- **Sources Consulted**: `backend/lib/copilot_history/session_catalog_reader.rb`, `backend/lib/copilot_history/types/read_result.rb`, `backend/lib/copilot_history/types/read_failure.rb`, `backend/lib/copilot_history/types/read_issue.rb`, `.kiro/specs/backend-history-reader/design.md`
- **Findings**:
  - `SessionCatalogReader#call` は root 解決または source catalog access の致命失敗だけを `ReadResult::Failure` として返す。
  - session file の parse/access issue は `NormalizedSession#issues` に残り、同じ `ReadResult::Success` 内で他 session とともに返る。
  - `ReadFailure#code` は root failure code に限定され、`ReadIssue#code` は root failure code を拒否する。
- **Implications**:
  - root failure は同期実行を `failed` にし、HTTP でも成功応答を返さない。
  - degraded session は保存を継続し、同期実行を `completed_with_issues` として完了できる。

### read model と fingerprint の保存境界
- **Context**: insert / update / skip 判定と read model 更新範囲を確定する必要がある。
- **Sources Consulted**: `backend/app/models/copilot_session.rb`, `backend/lib/copilot_history/persistence/session_record_builder.rb`, `backend/lib/copilot_history/persistence/source_fingerprint_builder.rb`, `backend/db/schema.rb`, `.kiro/specs/history-db-read-model/design.md`
- **Findings**:
  - `CopilotSession` は `session_id` unique の 1 session 1 row read model で、`source_fingerprint` と表示 payload を JSON object として保存する。
  - `SourceFingerprintBuilder` は source artifact の path / mtime / size / status を安定順で返し、`complete` flag を持つ。
  - `SessionRecordBuilder` は既存 presenter を再利用して `summary_payload` / `detail_payload` を生成するが、現在は同期判定を持たない。
- **Implications**:
  - 同期 service が `source_fingerprint` を先に生成して既存 row と比較し、保存が必要な場合だけ `SessionRecordBuilder` を使う。
  - `SessionRecordBuilder` は任意の precomputed fingerprint を受け取れるよう拡張し、比較時と保存時で fingerprint がずれないようにする。

### 同期実行履歴と二重実行
- **Context**: 未完了同期中の再実行を conflict として拒否し、実行履歴を上書きしない要件がある。
- **Sources Consulted**: `backend/app/models/history_sync_run.rb`, `backend/db/migrate/20260430030100_create_history_sync_runs.rb`, `backend/spec/models/history_sync_run_spec.rb`
- **Findings**:
  - `HistorySyncRun` は `running`, `succeeded`, `failed`, `completed_with_issues` を持つが、DB レベルで running を 1 件に制限する仕組みはない。
  - MySQL unique index は `NULL` を複数許容するため、running 中だけ固定値を入れる nullable lock key で単一 running を表現できる。
  - 現行 count fields は `processed_count`, `saved_count`, `skipped_count`, `failed_count`, `degraded_count` で、insert/update split はない。
- **Implications**:
  - `history_sync_runs.running_lock_key` を追加し、running 行だけ `"history_sync"` を入れる unique index で二重実行を防ぐ。
  - terminal status へ更新するときは `running_lock_key` を `nil` に戻し、次回同期を許可する。
  - `inserted_count` と `updated_count` を追加し、API response と実行履歴の双方で insert/update/skip を識別できるようにする。

### HTTP API integration
- **Context**: 既存 Rails API の route/controller/presenter パターンに合わせる必要がある。
- **Sources Consulted**: `backend/config/routes.rb`, `backend/app/controllers/api/sessions_controller.rb`, `backend/lib/copilot_history/api/presenters/error_presenter.rb`, `.kiro/specs/backend-session-api/design.md`
- **Findings**:
  - 既存 API は controller が query/service result を見て HTTP status と presenter を選び、JSON 整形は presenter に寄せている。
  - error envelope は `{ error: { code, message, details } }` の形で統一されている。
  - API 層は filesystem を直接触らず、domain service を介する構成が既存設計と一致する。
- **Implications**:
  - `POST /api/history/sync` を同期 command endpoint とし、controller は `HistorySyncService` と `HistorySyncPresenter` のみを使う。
  - 成功と degraded completion は 200、running conflict は 409、root failure は 503、予期しない永続化失敗は 500 とする。

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Controller direct implementation | controller が reader、DB、presenter を直接呼ぶ | ファイル数は少ない | HTTP 境界に同期判定と transaction が混ざり、request spec 以外で検証しにくい | 不採用 |
| Service orchestration | controller は service result を render し、同期処理は service が所有する | 既存 query / presenter 分離に近く、同期判定を単体テストしやすい | service が大きくなりすぎないよう result type を分ける必要がある | 採用 |
| Background job | POST は job enqueue だけを行い、後続 polling で結果を見る | 長時間処理に強い | 要件 1.2 と 6.3 が request 内完了、初期 background job なしを要求している | 不採用 |
| DB nullable unique lock | running 中だけ固定 lock key を入れ、terminal で nil に戻す | MySQL で単一 running を DB レベルに保証できる | crash 後の running 行は手動復旧が必要 | 採用 |

## Design Decisions

### Decision: 同期処理は request 内 service として実行する
- **Context**: 要件は同期要求を受け付けた request 内で完了状態を返すことを求め、background job と polling を初期範囲から除外している。
- **Alternatives Considered**:
  1. Controller direct implementation — 実装は速いが責務が混ざる。
  2. Background job — 将来拡張性はあるが今回の実行境界に反する。
  3. Service orchestration — HTTP と同期処理を分けつつ request 内で完了できる。
- **Selected Approach**: `CopilotHistory::Sync::HistorySyncService` が reader、fingerprint 比較、read model 保存、sync run 更新を統括する。
- **Rationale**: 既存 Rails API の controller/query/presenter 分離に合い、同期判定を request spec と service spec の両方で確認できる。
- **Trade-offs**: request が同期完了まで待つため、非常に大きな履歴では latency が増える。初期要件では許容し、background 化は revalidation trigger とする。
- **Follow-up**: 実装時に service の transaction 範囲と failure update を request spec で固定する。

### Decision: skip 判定は source fingerprint の完全一致で行う
- **Context**: raw files を正本にしつつ、保存済み payload の不要な再保存を避ける必要がある。
- **Alternatives Considered**:
  1. 常に upsert — 単純だが skip 要件に反する。
  2. updated_at_source 比較 — 日時欠落 session や metadata 変更を取りこぼす。
  3. source fingerprint 比較 — 既存 read model contract を使える。
- **Selected Approach**: session の `source_paths` から precomputed fingerprint を作り、既存 `CopilotSession#source_fingerprint` と一致すれば skip とする。
- **Rationale**: path / mtime / size / status の比較は既存 persistence spec の設計意図と一致する。
- **Trade-offs**: ファイル内容が変わって mtime/size が同一の場合は検知できない。初期設計では既存 fingerprint contract を尊重し、hash 内容拡張は別 revalidation とする。
- **Follow-up**: `SessionRecordBuilder` に precomputed fingerprint を渡せるようにし、比較結果と保存値を一致させる。

### Decision: running lock は `history_sync_runs` の nullable unique key で表現する
- **Context**: アプリ内の `exists?` check だけでは並行 request の競合を完全には防げない。
- **Alternatives Considered**:
  1. `HistorySyncRun.where(status: "running").exists?` のみ — race condition が残る。
  2. MySQL advisory lock — DB 固有関数に依存し、テストしにくい。
  3. nullable unique lock column — Rails model と migration で表現できる。
- **Selected Approach**: running 行だけ `running_lock_key = "history_sync"` を持ち、unique index で 1 件に制限する。terminal update 時に `nil` へ戻す。
- **Rationale**: 既存 MySQL/ActiveRecord の範囲で二重実行を DB レベルに固定できる。
- **Trade-offs**: process crash で running 行が残ると以後 conflict になる。初期仕様では自動 stale recovery は扱わない。
- **Follow-up**: 実装時に conflict response が既存 running 行を上書きしないことを request spec で確認する。

### Decision: insert/update count は実行履歴にも保存する
- **Context**: 要件 2.5 は insert、update、skip の件数を同期結果として識別できることを求めている。
- **Alternatives Considered**:
  1. API response だけで insert/update を返す — 後続処理が run record から参照できない。
  2. `saved_count` だけを保存する — insert/update の区別が失われる。
  3. `inserted_count` / `updated_count` を追加する — schema 変更が必要だが情報が残る。
- **Selected Approach**: `history_sync_runs` に `inserted_count` と `updated_count` を追加し、`saved_count = inserted_count + updated_count` を不変条件にする。
- **Rationale**: 同期結果と実行履歴の count contract を一致させ、運用者が空 DB、全 skip、更新ありを切り分けられる。
- **Trade-offs**: prior read model spec の `HistorySyncRun` schema を拡張するため、関連 spec の revalidation 対象になる。
- **Follow-up**: model validation で非負整数と saved count 整合性を確認する。

## Risks & Mitigations
- 同期中に永続化例外が発生すると部分更新が残るリスク — session writes と terminal success update を transaction に入れ、例外時は rollback 後に run を `failed` へ更新する。
- running 行が crash 後に残るリスク — 初期実装では conflict として扱い、手動復旧を前提にする。stale recovery は別 spec の revalidation trigger とする。
- fingerprint 比較と保存 payload 生成の間に raw file が変わるリスク — precomputed fingerprint を builder に渡し、少なくとも判定値と保存値を一致させる。厳密な filesystem snapshot は初期範囲外とする。
- API response が既存 session API error envelope と drift するリスク — sync presenter は既存 `{ error: { code, message, details } }` 形を維持する。

## References
- `.kiro/steering/product.md` — raw files 正本、degraded data の扱い。
- `.kiro/steering/tech.md` — Rails API / MySQL / RSpec / Docker Compose 前提。
- `.kiro/steering/structure.md` — backend controller と `backend/lib/copilot_history` の責務分離。
- `.kiro/specs/backend-history-reader/design.md` — root failure と session issue の upstream 境界。
- `.kiro/specs/history-db-read-model/design.md` — read model、sync run、fingerprint contract。
- `.kiro/specs/backend-session-api/design.md` — API controller / presenter / error envelope pattern。
