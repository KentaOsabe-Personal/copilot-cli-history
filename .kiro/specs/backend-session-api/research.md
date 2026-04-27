# Research & Design Decisions

## Summary
- **Feature**: `backend-session-api`
- **Discovery Scope**: Extension
- **Key Findings**:
  - `CopilotHistory::SessionCatalogReader` は root 単位の fatal failure を `ReadResult::Failure`、session 局所の劣化を `ReadResult::Success` 内の `issues` へ分離済みであり、API でもこの境界を維持しないと空データと障害が混同される。
  - `NormalizedSession` は current / legacy を共通契約へ正規化済みだが、work context、`selected_model`、`message_snapshots` の有無は format ごとに異なるため、API は nullable field を含む単一 schema で欠落を明示する必要がある。
  - backend は API-only Rails で `/up` 以外の route を持たず、reader 実装は `backend/lib/` に集約されているため、HTTP 境界だけ `app/controllers` に置き、query / presenter は `lib/` へ閉じる構成が既存パターンと整合する。
  - HTTP error 契約は root failure code を upstream 所有のまま透過し、API 層は `session_not_found` だけを追加することで、reader taxonomy と controller 都合の混線を防げる。

## Research Log

### Reader 公開契約と劣化境界
- **Context**: API 側で root 障害、session 局所劣化、mixed current / legacy をどう写像するかを決める必要があった。
- **Sources Consulted**: `.kiro/specs/backend-session-api/requirements.md`, `.kiro/specs/backend-session-api/brief.md`, `.kiro/specs/backend-history-reader/design.md`, `backend/lib/copilot_history/session_catalog_reader.rb`, `backend/lib/copilot_history/types/read_result.rb`, `backend/lib/copilot_history/types/normalized_session.rb`, `backend/spec/lib/copilot_history/session_catalog_reader_spec.rb`
- **Findings**:
  - reader は fatal root 障害を `ReadResult::Failure` で返し、current / legacy 混在の一覧は `ReadResult::Success` で返す。
  - file unreadable、parse failure、partial mapping、unknown event は `NormalizedSession#issues` に保持され、sibling session の読取を止めない。
  - detail API は reader の success envelope から目的 session を抽出するだけでよく、session 未検出だけを API 固有の not found として追加すればよい。
- **Implications**:
  - 一覧 API は root failure を 200 空配列へ変換してはならない。
  - 詳細 API では `session_not_found` を root failure と別 code / status で表現する。
  - API の劣化表現は reader issue を捨てず、session 単位と event 単位へ機械判別可能に写像する。

### Rails API の拡張ポイント
- **Context**: 新しい feature をどこへ配置すれば既存 backend 構造と衝突せず、後続 spec でも再利用しやすいかを判断したかった。
- **Sources Consulted**: `.kiro/steering/tech.md`, `.kiro/steering/structure.md`, `backend/config/routes.rb`, `backend/app/controllers/application_controller.rb`, `backend/config/application.rb`, `backend/spec/requests/health_spec.rb`, `backend/spec/rails_helper.rb`
- **Findings**:
  - backend は `config.api_only = true` で動作し、現状 route は `/up` のみである。
  - `backend/lib/` は `config.autoload_lib` により autoload 対象であり、feature logic を `lib/` 下に追加しやすい。
  - request spec は `host! "localhost"` と明示的な endpoint 呼び出しを使う最小構成で、support helper も `rails_helper` から自動読込される。
- **Implications**:
  - controller は `app/controllers/api/` に置き、feature の query / presenter / value object は `backend/lib/copilot_history/api/` に寄せる。
  - API 契約検証は request spec、mapping と not-found 分岐は lib spec で分担する。

### 正規化済み型と API 契約差分
- **Context**: current / legacy 共通契約を API へどう露出するか、また detail timeline で何を保持するかを詰める必要があった。
- **Sources Consulted**: `backend/lib/copilot_history/types/normalized_event.rb`, `backend/lib/copilot_history/types/read_issue.rb`, `backend/lib/copilot_history/types/read_failure.rb`, `backend/lib/copilot_history/current_session_reader.rb`, `backend/lib/copilot_history/legacy_session_reader.rb`, `backend/lib/copilot_history/event_normalizer.rb`
- **Findings**:
  - `NormalizedEvent` は `sequence`, `kind`, `raw_type`, `occurred_at`, `role`, `content`, `raw_payload` を持ち、UI は message / partial / unknown を区別できる。
  - `ReadIssue` は `sequence` を optional に持つため、event 由来 issue は event sequence へ紐づけられる。
  - legacy だけが `selected_model` と `message_snapshots` を持ち、current だけが `cwd`, `git_root`, `repository`, `branch`, `updated_at` を持ちやすい。
- **Implications**:
  - API session schema は field を固定しつつ、未取得項目を `null` または空配列で返す。
  - detail timeline は `raw_payload` を保持し、未知 shape や部分正規化を frontend が診断可能にする。
  - issue payload は共通 shape とし、`scope` と `event_sequence` で session / event 位置を表現する。

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Controller 直列変換 | controller が reader を直接呼び、JSON をその場で組み立てる | 実装ファイル数が少ない | HTTP 分岐、not found、共通 error 契約、list/detail 差分が controller に集中し肥大化する | 却下 |
| Query / Presenter 分離 | query が reader 呼び出しと抽出、presenter が JSON 契約化、controller は status と render のみ担当する | brief の方針に一致し、reader 再利用と後続 spec への拡張性が高い | query / presenter の境界設計が必要 | **採用** |
| 永続化先行 | DB や index に一度取り込み、API は DB を参照する | 将来の検索・フィルタへ伸ばしやすい | 今回の boundary を超え、raw files 正本原則にも反する | MVP 範囲外として却下 |

## Design Decisions

### Decision: 既存 reader の上に query / presenter を載せる
- **Context**: API は read-only かつ `backend-history-reader` を再実装せずに使う必要がある。
- **Alternatives Considered**:
  1. controller で reader 結果を直接 render する
  2. query / presenter を分離して API 専用契約へ写像する
- **Selected Approach**: `CopilotHistory::Api::SessionIndexQuery` / `SessionDetailQuery` が `SessionCatalogReader` を呼び、`SessionIndexPresenter` / `SessionDetailPresenter` / `ErrorPresenter` が HTTP payload を生成する。
- **Rationale**: brief の boundary 候補と一致し、reader 側の domain 契約と HTTP 契約を切り離せる。generalization として list / detail の双方で共通 issue/error presenter を再利用できる。
- **Trade-offs**: file 数は増えるが、controller に branching と payload 組み立てを混在させずに済む。
- **Follow-up**: 実装では controller が reader 型に直接依存しすぎないかを request spec と lib spec の両方で確認する。

### Decision: 詳細 API の not found は query 固有 union で返す
- **Context**: reader には「root failure」と「success with sessions」はあるが、「指定 session が存在しない」は存在しない。
- **Alternatives Considered**:
  1. controller が success sessions を直接検索して 404 を生成する
  2. detail query が `Found` / `NotFound` union を返し、controller は HTTP 変換だけを行う
- **Selected Approach**: `CopilotHistory::Api::Types::SessionLookupResult` に `Found` と `NotFound` を定義し、root failure は既存 `ReadResult::Failure` をそのまま返す。
- **Rationale**: build vs adopt の観点で既存 `ReadResult::Failure` は再利用しつつ、API 固有の not found だけを最小追加できる。
- **Trade-offs**: detail query の戻り値 union は 3 系統になる。
- **Follow-up**: design.md で controller の分岐を明示し、task 化時に曖昧さを残さない。

### Decision: root failure code は upstream 所有のまま透過し、API は `session_not_found` だけを追加する
- **Context**: review で、HTTP error code の所有者が reader か API か曖昧だと実装時に taxonomy が崩れる懸念が見つかった。
- **Alternatives Considered**:
  1. `session_not_found` を `CopilotHistory::Errors::ReadErrorCode` へ追加する
  2. root failure code は upstream のまま保持し、API 固有 code は HTTP 契約の境界で閉じる
- **Selected Approach**: root failure は `ReadFailure.code` をそのまま `503` へ写像し、`session_not_found` だけを detail query / error presenter が API 契約として返す。
- **Rationale**: upstream reader は filesystem / parse failure の canonical owner であり、HTTP 都合の 404 を混ぜると境界が曖昧になる。API 側は最小限の code 追加に留めることで責務を保てる。
- **Trade-offs**: error code の生成箇所が reader と API の 2 箇所に分かれる。
- **Follow-up**: design.md と presenter spec で code ownership と status mapping を固定する。

### Decision: issue 契約は単一 shape で session / event を区別する
- **Context**: requirement 3 は session 単位と event 単位の劣化を機械判別可能にすることを求める。
- **Alternatives Considered**:
  1. list 用 / detail 用で別 issue schema を作る
  2. 単一 issue schema に `scope` と `event_sequence` を持たせる
- **Selected Approach**: `IssuePresenter` が `ReadIssue` を `{ code, severity, message, source_path, scope, event_sequence }` へ写像し、detail endpoint では event 配列側へ再配置する。canonical field は削除せず、JSON 互換な型へだけ正規化する。
- **Rationale**: generalization と simplification を両立でき、list と detail で同一の issue field を再利用できる。
- **Trade-offs**: detail presenter では issue の再グルーピング処理が必要になる。
- **Follow-up**: event issue の sequence と timeline sequence が一致することを presenter spec で固定する。

### Decision: MVP では毎回 reader を再実行し、永続化や cache を導入しない
- **Context**: list / detail のみがスコープであり、検索・監視・永続化は明示的に out of scope である。
- **Alternatives Considered**:
  1. API request ごとに `SessionCatalogReader` を呼ぶ
  2. cache や DB に正規化済み session を保持する
- **Selected Approach**: query は毎回 `SessionCatalogReader` を呼び、in-memory で sort / lookup する。
- **Rationale**: simplification により MVP の責務を最小に保ち、raw files 正本原則を崩さない。
- **Trade-offs**: 履歴件数が大きくなると list / detail の応答時間は reader 実行時間に比例する。
- **Follow-up**: 将来の検索 / 永続化 spec では revalidation trigger として API 契約互換性を確認する。

## Risks & Mitigations
- 履歴件数増加で request ごとの full scan が重くなる — MVP では query を reader 1 回呼び出しに限定し、遅延が顕在化した時点で別 spec に切り出す
- local path や `raw_payload` を返す設計は外部公開に向かない — この spec はローカル利用前提とし、認証や外部 exposure を追加する場合は再設計する
- reader 側の type / code が変わると API 契約が drift する — presenter spec と request spec で API 契約を固定し、reader 変更時の差分を早期検知する

## References
- `.kiro/specs/backend-session-api/requirements.md` — 要件 ID と acceptance criteria
- `.kiro/specs/backend-session-api/brief.md` — feature boundary と採用方針
- `.kiro/specs/backend-history-reader/design.md` — upstream reader の公開契約
- `backend/lib/copilot_history/session_catalog_reader.rb` — reader facade と root failure 取扱い
- `backend/lib/copilot_history/types/normalized_session.rb` — current / legacy 共通 session 契約
- `backend/lib/copilot_history/types/normalized_event.rb` — timeline event 契約
- `backend/lib/copilot_history/types/read_issue.rb` — 劣化情報の canonical shape
- `backend/config/application.rb` — `backend/lib/` autoload 前提
