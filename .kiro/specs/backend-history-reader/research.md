# Research & Design Decisions

## Summary
- **Feature**: `backend-history-reader`
- **Discovery Scope**: Extension / Light discovery
- **Key Findings**:
  - 既存 backend は Rails API の最小雛形で、`config.autoload_lib` により `backend/lib/` を新しい責務境界として使える。
  - Copilot CLI 履歴の一次ソースは `COPILOT_HOME` または `~/.copilot` 配下の raw files であり、現行 `session-state` と旧形式 `history-session-state` が並存し得る。
  - 公開境界は `ReadResult::Success/Failure` の union に固定し、legacy `chatMessages` は `message_snapshots` として保持しつつ、file-level unreadable は recoverable issue として分離する必要がある。

## Research Log

### 既存 backend の拡張ポイント
- **Context**: Phase3 の reader 基盤をどこに配置すべきかを決める必要があった。
- **Sources Consulted**: `README.md`, `backend/config/application.rb`, `backend/config/routes.rb`, `backend/spec/rails_helper.rb`
- **Findings**:
  - backend は Rails API の最小雛形で、現状は `/up` 以外のドメイン責務を持たない。
  - `config.autoload_lib(ignore: %w[assets tasks])` が有効であり、`backend/lib/` 配下へ reader 群を置いても追加設定なしで autoload できる。
  - RSpec は request spec しか存在せず、新規 reader は `spec/lib/` と fixture ベースで検証するのが自然である。
- **Implications**: この spec は controller や ActiveRecord を増やさず、`backend/lib/copilot_history/` に閉じた filesystem reader と value object 群として設計する。

### Copilot 履歴ソースと実行環境前提
- **Context**: 要件 1 系・3 系・5 系を満たす責務境界を確定する必要があった。
- **Sources Consulted**: `.kiro/specs/backend-history-reader/requirements.md`, `.kiro/specs/backend-history-reader/brief.md`, `copilot-cli-session-history-research.md`, GitHub Docs `cli-config-dir-reference`, `chronicle`
- **Findings**:
  - 履歴ルートは `COPILOT_HOME` を優先し、未設定時は `~/.copilot` を既定値として扱う。
  - 読取対象は `session-state/<session-id>/workspace.yaml`、`session-state/<session-id>/events.jsonl`、`history-session-state/*.json` で十分に要件を満たせる。
  - Docker 実行でも mount されたローカル履歴ディレクトリを通常の filesystem と同様に読めればよく、HTTP API や CLI 自動操作は不要である。
- **Implications**: root 解決・source 列挙・format reader を分離し、allowed dependency をローカル filesystem と標準 parser に限定する。

### 形式互換と失敗の扱い
- **Context**: 要件 2.3, 2.4, 3.3, 4.1, 4.2 を同時に満たす失敗モデルが必要だった。
- **Sources Consulted**: `.kiro/specs/backend-history-reader/requirements.md`, `.kiro/specs/backend-history-reader/brief.md`, `copilot-cli-session-history-research.md`, GitHub copilot-cli changelog
- **Findings**:
  - `workspace.yaml` は安全に読み取る必要があり、`Psych.safe_load` 前提の boundary が妥当である。
  - `events.jsonl` は行順自体が意味を持つため、reader は line index を維持したまま parse し、壊れた行があっても sibling session を巻き込まず issue として保持すべきである。
  - 旧形式 JSON は `sessionId`, `startTime`, `chatMessages`, `timeline`, `selectedModel` を中心に共通オブジェクトへ写像できるが、timeline の詳細型は将来変動し得る。
- **Implications**: root 全体の失敗は `ReadFailure`、session 局所の失敗は `ReadIssue` として分離し、未知イベントは `NormalizedEvent` に raw payload を必須保持させる。

### 設計レビューで露出した契約ギャップの補正
- **Context**: `/kiro-validate-design backend-history-reader` で、公開契約の揺れ、legacy `chatMessages` の扱い、file-level permission error の境界が主要論点として指摘された。
- **Sources Consulted**: `.kiro/specs/backend-history-reader/design.md`, `.kiro/specs/backend-history-reader/requirements.md`, design review feedback
- **Findings**:
  - 公開境界では `ReadResult::Success/Failure` のみを分岐点とし、`ReadFailure` は `Failure` の payload として扱う方が責務が明確になる。
  - `EventNormalizer` の戻り値は tuple ではなく `NormalizationResult(event:, issues:)` のような固定 shape にした方が task 化しやすい。
  - legacy `chatMessages` は `timeline` と順序整合を持たないため、canonical `events` に混ぜず `message_snapshots` として補助保持するのが最小で安全である。
  - root 解決後の artifact unreadable は root failure ではなく session-level `ReadIssue` に留める方が 5.2 の切り分けに適合する。
- **Implications**: design では `ReadFailure`, `NormalizationResult`, `MessageSnapshot` を明示し、`root_*` と `current.*` / `legacy.*` / `event.*` の code 境界を固定する。

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Reader adapter pipeline | root 解決、source 列挙、current/legacy reader、event normalizer、公開 facade を層分離する | 責務境界が明確、raw source 中心、API/DB 非依存、RSpec で個別検証しやすい | value object と result contract を先に定義する必要がある | **採用** |
| Controller first parsing | request 層から直接 filesystem を読んで parse する | 初期ファイル数を減らせる | API 形状と reader 境界が混ざり、Phase4 を先食いする | Out of boundary に抵触 |
| Immediate ActiveRecord import | 読取と同時に DB schema へ落とし込む | 後続検索へ直結しやすい | Phase6 の永続化設計へ強く依存し、raw source の責務が曖昧になる | この spec の境界を超える |

## Design Decisions

### Decision: Reader adapter pipeline を公開 service で束ねる
- **Context**: 新旧 2 形式を同じ backend で扱いつつ、Phase4 の API と独立した読取基盤を成立させる必要がある。
- **Alternatives Considered**:
  1. Controller や request object から直接 parse する
  2. ActiveRecord import を reader の公開境界にする
- **Selected Approach**: `SessionCatalogReader` を唯一の公開 service とし、その下に `HistoryRootResolver`、`SessionSourceCatalog`、`CurrentSessionReader`、`LegacySessionReader`、`EventNormalizer` を置く。
- **Rationale**: root 解決・列挙・format 変換・共通正規化を別責務に分けることで、要件変更時の revalidation 範囲が明確になる。
- **Trade-offs**: 初期の file 数は増えるが、実装タスクの並列性と review しやすさが上がる。
- **Follow-up**: 実装時に `backend/lib/` 配下の Zeitwerk 命名規約を崩さないことを確認する。

### Decision: root failure と session issue を分離した result envelope を採用する
- **Context**: root 不達と一部 session の parse failure を同一レベルの失敗として扱うと、要件 2 系・3 系の「正常データと区別できる結果」が曖昧になる。
- **Alternatives Considered**:
  1. 例外だけで表現する
  2. 壊れた session を黙ってスキップする
- **Selected Approach**: 公開戻り値は `Types::ReadResult::Success/Failure` の union とし、root 全体の読取不能は `ReadFailure` を `Failure` payload として返し、event 単位の変換は `NormalizationResult` を介して session へ集約する。
- **Rationale**: 呼び出し元は `ReadResult` だけを見ればよく、internal value object の責務と公開 envelope の責務が分離される。
- **Trade-offs**: result 型は増えるが、戻り値 shape は安定する。
- **Follow-up**: 実装時は issue code を固定し、controller 層が勝手に string 比較を増やさないようにする。

### Decision: legacy `chatMessages` は `message_snapshots` として補助保持する
- **Context**: 要件 3.2 は `chatMessages` と `timeline` の両方を共通 object へ変換することを求めるが、両者は同じ順序責務を持たない。
- **Alternatives Considered**:
  1. `chatMessages` を `events` へ混ぜて再順序付けする
  2. `chatMessages` を破棄して `timeline` だけ採用する
- **Selected Approach**: `timeline` を canonical `events` とし、`chatMessages` は `message_snapshots` として別 field に保持する。
- **Rationale**: lossless 性を維持しつつ、順序責務と transcript 補助情報の責務を分離できる。
- **Trade-offs**: caller は `events` と `message_snapshots` の役割差を理解する必要がある。
- **Follow-up**: 実装時は current format では `message_snapshots` を空配列で返し、legacy 専用分岐を最小化する。

### Decision: 共通 event は raw payload を必須保持する
- **Context**: Copilot CLI の内部 event schema は安定公開契約ではなく、未知 event を無視すると将来の情報欠落を招く。
- **Alternatives Considered**:
  1. 既知型だけ正規化して未知型は破棄する
  2. 正規化を諦めて raw JSON だけ返す
- **Selected Approach**: `NormalizedEvent` に共通項目と `raw_payload` を両方持たせ、未知 event は `kind: :unknown` として返す。
- **Rationale**: 後続 API / persistence 層は最低限の共通項目を利用しつつ、未対応 schema も raw payload から再解釈できる。
- **Trade-offs**: payload 保持によりメモリ量は増えるが、Phase3 の安全性を優先する。
- **Follow-up**: 実装時は raw payload を deep copy せず immutable value object 化の方針を検討する。

### Decision: 新規依存 gem を追加しない
- **Context**: この spec は reader 基盤の責務に限定され、format parse は標準機能で十分に満たせる。
- **Alternatives Considered**:
  1. YAML/JSON parser や result monad 系 gem を追加する
  2. Ruby 標準ライブラリだけで構成する
- **Selected Approach**: `Psych.safe_load`, `JSON.parse`, `Pathname`, `Dir`, `File`, `Time` を中心に設計する。
- **Rationale**: dependency surface を広げず、Docker / Rails API 既存構成との整合を保てる。
- **Trade-offs**: result 型や value object は自前定義が必要になる。
- **Follow-up**: 実装時に parser option を固定し、unsafe class load を許可しない。

## Risks & Mitigations
- Copilot CLI 内部 schema の変化で既知 mapping が崩れる — `source_format`, `raw_payload`, `issue_code` を残して再解釈余地を維持する。
- `events.jsonl` の壊れた行や書込途中の行で session 全体が読めなくなる — line 単位 issue を返し、順序付きの読取済み event は保持する。
- root 解決後の artifact unreadable を fatal 扱いして partial success を潰す — `root_*` と session/file-level issue code を分離し、戻り値契約で昇格条件を固定する。
- この spec が API や DB 設計を抱え込む — file structure plan と boundary section を `backend/lib/` 内の reader 契約に限定する。

## References
- `README.md` — backend/runtime の基礎構成
- `backend/config/application.rb` — `lib/` autoload の根拠
- `.kiro/specs/backend-history-reader/brief.md` — spec boundary と制約
- `.kiro/specs/backend-history-reader/requirements.md` — 要件 ID と acceptance criteria
- `copilot-cli-session-history-research.md` — 既存調査メモと公式リンク集
- GitHub Docs, “GitHub Copilot CLI configuration directory” — `COPILOT_HOME`, `session-state`, `session-store.db`
- GitHub Docs, “About GitHub Copilot CLI session data” — raw files が complete record であること
- `github/copilot-cli` changelog — `history-session-state` から `session-state` への形式移行
