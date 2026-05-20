# 調査・設計判断

## Summary
- **Feature**: `session-execution-directory-search`
- **Discovery Scope**: Extension
- **Key Findings**:
  - current 形式 reader は `workspace.yaml` から `cwd` / `git_root` / `repository` / `branch` を `NormalizedSession` に載せる契約を既に持つ。
  - `copilot_sessions` table と `SessionRecordBuilder` は `cwd` / `git_root` の scalar 保存口を持つため、新規 schema ではなく保存経路と同期後の再生成を検証する設計が適している。
  - 一覧 UI は `repository @ branch` を優先して 1 つの「作業コンテキスト」にまとめるため、`cwd` が存在しても実行ディレクトリを読めない場合がある。
  - 既存検索は `search_text` の literal substring match に限定され、`SessionSearchTextBuilder` は意図的に `cwd` を除外している。

## Research Log

### current 形式の実行ディレクトリ取得経路
- **Context**: 1.1, 1.3, 1.4 は current 形式セッションの実行ディレクトリを、推測なしで同期済み read model に保持することを求める。
- **Sources Consulted**:
  - `backend/lib/copilot_history/current_session_reader.rb`
  - `backend/lib/copilot_history/types/normalized_session.rb`
  - `backend/spec/lib/copilot_history/current_session_reader_spec.rb`
- **Findings**:
  - `CurrentSessionReader` は `workspace.yaml` を `Psych.safe_load` で読み、`cwd` / `git_root` を `NormalizedSession` へ渡している。
  - `NormalizedSession` は `cwd` / `git_root` を nullable `Pathname` として正規化し、入力がない場合は `nil` を保持する。
  - workspace parse failure / unreadable の場合、既存 spec は `cwd` を `nil` として扱う。これは推測値を作らない要件と整合する。
- **Implications**:
  - reader の責務は大きく変更しない。必要な実装は、保存・同期・request spec で current fixture の `cwd` が DB と API payload まで流れることを固定する。

### read model 保存契約
- **Context**: 実運用 DB で `cwd` / `git_root` が `null` になっているという課題があり、保存経路の設計境界を確認した。
- **Sources Consulted**:
  - `backend/db/schema.rb`
  - `backend/lib/copilot_history/persistence/session_record_builder.rb`
  - `backend/lib/copilot_history/sync/history_sync_service.rb`
  - `backend/spec/lib/copilot_history/persistence/session_record_builder_spec.rb`
- **Findings**:
  - `copilot_sessions.cwd` と `copilot_sessions.git_root` は既存 nullable text column である。
  - `SessionRecordBuilder` は `session.cwd` / `session.git_root` を scalar attributes と、`summary_payload.work_context` / `detail_payload.work_context` に含める既存構成を持つ。
  - `HistorySyncService` は source fingerprint と `search_text_version` によって skip / update を判断する。`cwd` 保存経路を修正した場合、既存 row の再同期で更新される条件を明確にする必要がある。
- **Implications**:
  - この spec は DB schema 追加を所有しない。`cwd` がある current session を明示同期したとき、scalar column と payload が同じ実値を持つことを保存契約として固定する。
  - 既存 row は raw files から明示同期で再生成される前提を維持する。raw files にない legacy session へ cwd を推測付与しない。

### 一覧表示の metadata 方針
- **Context**: 2.1, 2.2, 2.3, 2.4, 2.5 は一覧カードで cwd を読み、repository / branch があっても cwd が隠れないことを求める。
- **Sources Consulted**:
  - `frontend/src/features/sessions/presentation/formatters.ts`
  - `frontend/src/features/sessions/components/SessionSummaryCard.tsx`
  - `.kiro/specs/session-ui-noise-reduction/design.md`
- **Findings**:
  - 既存 helper は `repository + branch`、`repository`、`cwd`、`git_root` の順で 1 つの表示値を返す。
  - `session-ui-noise-reduction` は値がある metadata だけを表示し、不明 placeholder を出さない方針を定めている。
  - `SessionSummaryCard` の `dd` は `break-words` を持ち、長い値を折り返す既存パターンがある。
- **Implications**:
  - 一覧 summary surface では `cwd` を独立した metadata item として表示する。repository / branch は別 item に分けるか既存 work context item と併存させ、cwd を隠さない。
  - `cwd` がない session では item 自体を出さず、placeholder は作らない。

### 一覧検索の拡張点
- **Context**: 3.1, 3.2, 3.3, 3.4, 3.5, 4.1, 4.5 は保存済み read model を使い、既存検索を維持しつつ実行ディレクトリだけを検索対象へ加えることを求める。
- **Sources Consulted**:
  - `backend/lib/copilot_history/api/session_index_query.rb`
  - `backend/lib/copilot_history/api/session_list_params.rb`
  - `backend/lib/copilot_history/persistence/session_search_text_builder.rb`
  - `backend/spec/lib/copilot_history/api/session_index_query_spec.rb`
  - `.kiro/specs/session-full-text-search/design.md`
- **Findings**:
  - `SessionListParams` は `search` を trim / whitespace collapse / 200 文字上限 / 制御文字拒否で正規化する。
  - `SessionIndexQuery` は `search_text LIKE ? ESCAPE '!'` を date candidate scope に合成し、payload は保存済み `summary_payload` を返す。
  - `SessionSearchTextBuilder` は `metadata` 引数を受け取るが、現在は `cwd` / repository / branch / model を意図的に除外している。
- **Implications**:
  - 実行ディレクトリ検索は `search_text` へ cwd を混ぜるのではなく、`SessionIndexQuery` が `search_text OR cwd` の read model query として扱う。
  - 検索対象拡張は `cwd` のみに限定し、`git_root` / repository / branch / selected model は一般検索対象へ追加しない。
  - `search_text_version` を cwd 検索のためだけに上げる必要はない。既存本文検索 projection の意味を変えないためである。

### frontend 検索 UI と条件維持
- **Context**: 5.1, 5.2, 5.3, 5.4, 5.5 は検索対象の説明、日付範囲維持、条件表示、検索条件エラーの区別を求める。
- **Sources Consulted**:
  - `frontend/src/features/sessions/components/SessionSearchForm.tsx`
  - `frontend/src/features/sessions/hooks/useSessionIndex.ts`
  - `frontend/src/features/sessions/presentation/sessionIndexCriteria.ts`
  - `frontend/tests/features/sessions/components/SessionSearchForm.test.tsx`
- **Findings**:
  - `useSessionIndex` は date range と search term を `SessionIndexCriteria` として保持し、検索適用・解除時に現在の日付範囲を維持する。
  - `SessionSearchForm` は現在の条件 label、frontend validation、backend search condition error を表示できる。
  - 説明文は「会話本文、会話 preview、issue の内容」に限定されており、cwd が検索対象に増えたことを示していない。
- **Implications**:
  - UI state 構造は維持し、説明文と tests を更新する。
  - backend `details.field == "search"` の error を検索条件エラーとして扱う既存分類を継続する。

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| `search_text` へ `cwd` を追加 | 同期時の検索 projection に cwd を追記し、既存 `search_text LIKE` のまま検索する | query 変更が小さい | 表示と検索の根拠が分かれ、実行ディレクトリを検索用 text に閉じ込める。既存 `search_text` の本文検索 projection 意味も変わる | 不採用 |
| `search_text OR cwd` query | 既存本文検索 projection と scalar `cwd` column の両方を read model 上で検索する | `cwd` が表示・検索の共通根拠になる。新規 schema と外部依存なし | `%term%` は index を効かせにくい。scope 条件の OR を慎重に構築する必要がある | 採用 |
| 専用 project filter | `cwd` 専用 param や repository filter を追加する | 後続の project grouping に発展しやすい | 今回の一般検索拡張範囲を超え、UI/API contract が増える | 不採用 |
| raw files 直接検索 | search request 時に `workspace.yaml` を読む | DB 未同期 session も拾える可能性がある | read-only API の read model 方針に反し、重い読取と破損処理が検索 request へ戻る | 不採用 |

## Design Decisions

### Decision: 実行ディレクトリ検索は `copilot_sessions.cwd` を直接参照する
- **Context**: 実行ディレクトリを検索用 text だけに閉じ込めず、一覧表示と検索が同じ read model metadata を参照する必要がある。
- **Alternatives Considered**:
  1. `SessionSearchTextBuilder` に cwd を追加する。
  2. `SessionIndexQuery` で `search_text` と `cwd` の OR 条件を構築する。
- **Selected Approach**: 既存本文検索は `search_text` に残し、実行ディレクトリ検索は `cwd` column の literal substring match として追加する。
- **Rationale**: `cwd` は scalar metadata として既に存在し、表示根拠にもなる。`search_text` の責務を本文・preview・issue に保つことで、検索対象の境界が読みやすい。
- **Trade-offs**: query の OR 条件が増える。大量データで性能が問題化した場合は別 spec で index / FULLTEXT / structured filter を検討する。
- **Follow-up**: 実装時は `%` / `_` を literal として扱う既存 escape 処理を `cwd` 条件にも適用する。

### Decision: 一覧カードでは cwd を独立 metadata として表示する
- **Context**: repository / branch 情報がある場合でも、実行ディレクトリ表示を隠してはならない。
- **Alternatives Considered**:
  1. 既存「作業コンテキスト」表示の優先順位だけを `cwd` 最優先に変える。
  2. `cwd` と repository / branch を別 item として表示する。
- **Selected Approach**: summary surface では `cwd` を「実行ディレクトリ」として独立表示し、repository / branch は隣接 metadata として併存させる。
- **Rationale**: `cwd` と repository / branch は別の識別軸であり、片方が存在してももう片方を隠すべきではない。
- **Trade-offs**: 一覧カードの metadata item 数が増える。値がある item だけを表示し、wrap-safe class を維持して密度を抑える。
- **Follow-up**: 詳細 header の metadata 表示を同時に変えるかは実装時に既存 helper の共有範囲で判断するが、今回の受け入れ基準は一覧カードを必須範囲とする。

### Decision: schema 追加ではなく保存経路の契約を固定する
- **Context**: `cwd` / `git_root` column は既に存在するが、実運用 DB で null が観測されている。
- **Alternatives Considered**:
  1. 新しい execution directory column を追加する。
  2. 既存 `cwd` / `git_root` column と payload contract を使い、保存経路と再同期を test で固定する。
- **Selected Approach**: 既存 `cwd` を実行ディレクトリ metadata の正規保存先とし、current fixture から sync / record builder / API response までの regression test を追加する。
- **Rationale**: 既存 schema と reader contract が目的に合っており、重複 column はデータ所有境界を曖昧にする。
- **Trade-offs**: 過去に同期済みの row は明示同期で再生成されるまで null のまま残り得る。raw files を一次ソースとする steering に従い、同期で回復させる。
- **Follow-up**: 実装時に保存経路の不具合が見つかった場合は `HistorySyncService` の skip 判定を見直し、source fingerprint が同じでも cwd 欠落 row を更新対象にする。

## Synthesis Outcomes

### Generalization
- 日付範囲と検索語は既に `SessionIndexCriteria` として統合されている。今回の `cwd` 検索は新しい UI state ではなく、同じ `search` term が複数 read model fields に当たる backend query 拡張として扱う。
- 表示 metadata は「値がある item のリスト」という既存一般化に乗せる。cwd 専用カード UI を作らず、metadata item builder の summary 表示契約を拡張する。

### Build vs. Adopt
- 新規検索ライブラリ、MySQL FULLTEXT、外部検索サービスは採用しない。既存 ActiveRecord + MySQL literal substring match で十分に要件を満たす。
- 新しい frontend state library は採用しない。既存 React hook と presentation helper で条件維持を実現する。

### Simplification
- `cwd` 専用 query param は追加しない。既存 `search` param の対象範囲を「本文・preview・issue・実行ディレクトリ」に広げる。
- `git_root` / repository / branch / selected model は検索対象に追加しない。後続の project filter や repository filter は別 spec とする。
- DB migration は基本不要とし、実装中に現行 schema との差分が見つかった場合のみ tasks 側で扱う。

## Risks & Mitigations
- `cwd` 欠落 row が source fingerprint 不変で skip され続ける — sync spec で cwd 欠落 current row の再生成条件を確認し、必要なら skip 判定へ metadata 欠落検出を追加する。
- `search_text OR cwd` が既存本文検索の結果を変えすぎる — request / query spec で本文一致、cwd 一致、日付併用、no match empty success を分けて固定する。
- repository / branch も検索できると誤解される — UI 説明文と design boundary で追加対象を実行ディレクトリに限定する。
- 長い path が一覧カードを横に広げる — 既存 `break-words` / responsive grid を維持し、長い cwd 専用 test を追加する。
- legacy session に推測 cwd が混ざる — reader / builder は `nil` を保持し、UI は item を表示しない test を追加する。

## References
- `.kiro/steering/product.md` — raw files を一次ソース、DB read model を再生成可能な補助層として扱う原則。
- `.kiro/steering/tech.md` — Rails API / React / MySQL、session search は read model projection で扱う判断。
- `.kiro/steering/structure.md` — backend `lib/copilot_history` と frontend sessions feature slice の配置方針。
- `.kiro/specs/session-full-text-search/design.md` — 既存 `search_text` projection と `search` param の境界。
- `.kiro/specs/session-ui-noise-reduction/design.md` — metadata は値がある項目だけを表示し、placeholder を避ける方針。
