# Research & Design Decisions

## Summary
- **Feature**: `history-db-read-model`
- **Discovery Scope**: Extension
- **Key Findings**:
  - 既存の `SessionIndexPresenter` と `SessionDetailPresenter` は `NormalizedSession` から一覧・詳細 payload を生成済みであり、read model builder はこの contract を再利用できる。
  - `NormalizedSession` は履歴由来日時、source format/state、work context、model、issues、source paths を保持しており、DB record timestamp と履歴由来日時を分離する設計に適合する。
  - 現在の backend には migration / schema が未導入であるため、この spec は `copilot_sessions` と `history_sync_runs` の物理 schema、ActiveRecord model、DB attributes builder を新規境界として定義する。

## Research Log

### 既存 reader / presenter contract の確認
- **Context**: 保存済み read model が既存表示 payload を raw files 再読取なしで返せるかを確認した。
- **Sources Consulted**:
  - `backend/lib/copilot_history/types/normalized_session.rb`
  - `backend/lib/copilot_history/types/session_source.rb`
  - `backend/lib/copilot_history/api/presenters/session_index_presenter.rb`
  - `backend/lib/copilot_history/api/presenters/session_detail_presenter.rb`
  - `backend/lib/copilot_history/api/presenters/issue_presenter.rb`
- **Findings**:
  - `NormalizedSession` は `created_at` / `updated_at` を `Time` または `nil` として保持し、欠落を補完しない。
  - `source_format` は `current` / `legacy`、`source_state` は `complete` / `workspace_only` / `degraded` に正規化されている。
  - 一覧 presenter は `conversation_summary`、`degraded`、`issues`、work context、件数を返す。
  - 詳細 presenter は header、message snapshots、conversation、activity、timeline、issues を返し、`include_raw: false` を既定にできる。
- **Implications**:
  - read model は presenter 出力を `summary_payload` / `detail_payload` として保存することで、既存 API shape に近い payload を再利用できる。
  - payload builder は controller や downstream DB query に依存せず、`NormalizedSession` と presenter にだけ依存する。

### ActiveRecord / MySQL 配置の確認
- **Context**: schema と model の置き場所、Rails 設定、利用可能な DB 機能を確認した。
- **Sources Consulted**:
  - `backend/Gemfile`
  - `backend/Gemfile.lock`
  - `backend/config/application.rb`
  - `backend/config/database.yml`
  - `backend/app/models/application_record.rb`
  - `docker-compose.yml`
- **Findings**:
  - Rails は 8.1.3、ActiveRecord は 8.1.3、MySQL adapter は `mysql2` 0.5.7。
  - backend は API mode だが ActiveRecord railtie は有効で、`ApplicationRecord` が存在する。
  - `backend/db/migrate` と `backend/db/schema.rb` はまだ存在せず、DB schema はこの feature が最初に追加する領域になる。
  - MySQL は `utf8mb4` で、Docker Compose 上の MySQL 9.7 を開発環境の正本として扱う。
- **Implications**:
  - model は `backend/app/models`、DB 変換 logic は `backend/lib/copilot_history/persistence` に分離する。
  - JSON payload は MySQL JSON column に保存し、日付範囲 query 用の scalar column と payload を併存させる。
  - migration 実行後は `backend/db/schema.rb` が生成・更新される前提で task を設計する。

### source metadata / fingerprint 境界の確認
- **Context**: 後続同期が保存省略や再生成を判断できる材料を、この feature がどこまで所有するかを確認した。
- **Sources Consulted**:
  - `backend/lib/copilot_history/types/session_source.rb`
  - `backend/lib/copilot_history/session_source_catalog.rb`
  - `.kiro/specs/history-db-read-model/requirements.md`
  - `.kiro/steering/product.md`
  - `.kiro/steering/roadmap.md`
- **Findings**:
  - source artifact は current では `workspace.yaml` と `events.jsonl`、legacy では単一 JSON source として列挙される。
  - `NormalizedSession#source_paths` は role keyed hash として保存対象 path を保持できる。
  - requirements は fingerprint の比較材料提供を要求するが、保存省略 / 再生成判断は明示的に out of scope としている。
- **Implications**:
  - `SourceFingerprintBuilder` は path、mtime、size、missing/error 状態、完全性 flag を含む deterministic な Hash を返す。
  - sync service はこの fingerprint を比較に使えるが、skip/update 判断は `history-sync-api` 側の責務にする。

### 同期実行結果の保存境界
- **Context**: session row が存在しない状態と同期実行失敗を切り分けるための記録単位を確認した。
- **Sources Consulted**:
  - `.kiro/specs/history-db-read-model/requirements.md`
  - `.kiro/steering/roadmap.md`
  - `history-db-sync-implementation-plan.md`
- **Findings**:
  - `history_sync_runs` は read model row とは独立し、started/finished、status、処理件数、保存件数、失敗・劣化概要を保持する必要がある。
  - raw files 読取開始、明示同期 API、非同期 job はこの spec の境界外である。
- **Implications**:
  - この spec は `HistorySyncRun` の schema / validation / status contract を定義し、実行 orchestration は下流 spec に委譲する。
  - status は `running` / `succeeded` / `failed` / `completed_with_issues` を固定し、完全成功と部分劣化を分ける。

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| ActiveRecord read model + builder | `NormalizedSession` から DB attributes を作り、1 session 1 row で保存する | Rails 標準に沿い、downstream query が扱いやすい | payload contract 変更時は再同期が必要 | 採用 |
| raw normalized object を丸ごと JSON 保存 | `NormalizedSession` 相当を単一 JSON として保存する | schema が少ない | 日付範囲 query、index、payload互換確認が弱い | 不採用 |
| API response 時に毎回 presenter 再実行 | DB には normalized fields だけ保存し、query 時に payload を再構成する | payload重複が少ない | raw event / snapshots の完全な再構成が必要になり、初期実装が重い | 不採用 |
| sync service まで同一 spec に含める | raw reader 実行、fingerprint比較、upsertまで実装する | end-to-end で動かしやすい | roadmap の境界を超え、API/UI切替と混在しやすい | `history-sync-api` へ委譲 |

## Design Decisions

### Decision: presenter payload を read model に保存する
- **Context**: 後続 query が raw files を再読取せずに一覧 / 詳細 payload を返す必要がある。
- **Alternatives Considered**:
  1. `summary_payload` / `detail_payload` を保存する。
  2. normalized events を保存し、query 時に presenter を再実行する。
  3. summary だけ保存し、detail は raw files に fallback する。
- **Selected Approach**: 既存 presenter contract を使い、`summary_payload` と `detail_payload` を JSON column として保存する。
- **Rationale**: 既存表示契約との drift を抑え、DB query 化時に raw files 依存を外せる。
- **Trade-offs**: payload shape 変更時は再同期が必要だが、raw files 正本の原則により再生成可能である。
- **Follow-up**: builder spec で既存 presenter 出力との一致を確認する。

### Decision: 履歴由来日時と row timestamp を分離する
- **Context**: Rails の `created_at` / `updated_at` は保存レコード日時であり、履歴由来日時とは意味が異なる。
- **Alternatives Considered**:
  1. `created_at_source` / `updated_at_source` を使う。
  2. Rails timestamps を履歴由来日時として上書きする。
  3. payload 内の日時だけを query 時に読む。
- **Selected Approach**: 履歴由来日時は `created_at_source` / `updated_at_source`、DB record timestamp は Rails 標準 `created_at` / `updated_at` に分ける。
- **Rationale**: 欠落を暗黙補完せず、日付不明と保存日時を明確に区別できる。
- **Trade-offs**: column 数は増えるが、query と監査の意味が明確になる。
- **Follow-up**: 両方欠落時の `history_date` 相当は `nil` とし、保存日時に fallback しない spec を追加する。

### Decision: source fingerprint は比較材料だけを提供する
- **Context**: requirements は fingerprint の安定性と不完全状態の識別を要求するが、同期時の skip/update 判断は境界外としている。
- **Alternatives Considered**:
  1. builder が fingerprint Hash と completeness を返す。
  2. builder が DB の既存値と比較して skip/update を決める。
  3. fingerprint を checksum 文字列だけにする。
- **Selected Approach**: `SourceFingerprintBuilder` は artifact role ごとの path、mtime、size、status と top-level `complete` を返す。
- **Rationale**: 比較可能性と診断可能性を両立し、sync orchestration への責務流出を避ける。
- **Trade-offs**: JSON 比較の詳細は downstream に残るが、この spec は再利用可能な材料を固定できる。
- **Follow-up**: path / mtime / size 不変時に同じ Hash、いずれか変更時に異なる Hash になる unit spec を追加する。

### Decision: 同期実行結果は session read model と別 table にする
- **Context**: セッション未保存と同期失敗を切り分ける必要がある。
- **Alternatives Considered**:
  1. `history_sync_runs` table を持つ。
  2. `copilot_sessions` に最後の同期状態を混ぜる。
  3. log 出力のみで保持する。
- **Selected Approach**: `HistorySyncRun` model と `history_sync_runs` table を追加する。
- **Rationale**: session row が 0 件でも同期実行の成否を記録でき、運用・UI・APIが同じ source を参照できる。
- **Trade-offs**: cleanup policy は別途必要になり得るが、初期 scope では永続履歴として保持する。
- **Follow-up**: downstream sync API は実行開始前失敗、部分劣化、完全成功を status と counts で表現する。

## Risks & Mitigations
- JSON payload が既存 presenter contract と drift する — builder が既存 presenter を直接使い、spec で payload key を固定する。
- 日付不明 session が保存日時で範囲 query に混入する — `history_date_source` は生成列ではなく query contract として `updated_at_source || created_at_source` を使い、両方欠落時は `nil` を維持する。
- fingerprint metadata の取得失敗で同期判断が誤る — artifact ごとに `status` と top-level `complete: false` を保存する。
- sync orchestration がこの feature に混入する — file structure と component boundary で controller、route、reader起動、skip/update判断を out of boundary に固定する。

## References
- `.kiro/steering/product.md` — raw files を正本、DB を再生成可能な補助層とする原則。
- `.kiro/steering/tech.md` — Rails API 8.1、Ruby 4、MySQL 9.7、Docker Compose 正本の技術前提。
- `.kiro/steering/structure.md` — backend model / lib / spec の配置方針。
- `.kiro/steering/roadmap.md` — DB read model、sync API、session API DB query、frontend sync UI の依存順。
- `.kiro/specs/backend-history-reader/design.md` — `NormalizedSession` と raw files reader 境界。
- `.kiro/specs/backend-session-api/design.md` — 既存 list/detail presenter payload contract。
