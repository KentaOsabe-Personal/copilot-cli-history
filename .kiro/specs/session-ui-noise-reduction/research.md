# 調査・設計判断ログ

## Summary
- **Feature**: `session-ui-noise-reduction`
- **Discovery Scope**: Extension
- **Key Findings**:
  - 既存 API は `selected_model`、`work_context`、`conversation_summary`、`issues`、`activity` をすでに返しており、表示ノイズ削減のために新しい response field は不要である。
  - current 形式では `CurrentSessionReader` が `selected_model: nil` を固定しているため、既存 `selected_model` contract を再利用して event 内の model 情報だけを昇格するのが最小変更である。
  - 詳細画面は `SessionDetailHeader` → session issue → `ConversationTranscript` → `ActivityTimeline` の順で描画しており、conversation-first のためには session issue と activity を明示操作に移す必要がある。

## Research Log

### 既存 UI の表示ノイズ境界
- **Context**: 一覧と詳細で常設ラベル、`不明` プレースホルダー、session issue、activity が会話本文より目立つという要件を確認した。
- **Sources Consulted**: `frontend/src/features/sessions/components/SessionSummaryCard.tsx`, `SessionDetailHeader.tsx`, `SessionDetailPage.tsx`, `ActivityTimeline.tsx`, `TimelineContent.tsx`, `formatters.ts`, 関連 component tests
- **Findings**:
  - 一覧 card は `会話あり`、`正常`、`complete`、内部 activity 数を常時表示している。
  - `formatWorkContext` と `formatModel` は欠損時に `作業コンテキスト不明`、`モデル不明` を返し、一覧と詳細でそのまま表示される。
  - `SessionDetailPage` は session-level issue を会話より前に常時表示し、`ActivityTimeline` も見出しと raw action を初期表示する。
  - `TimelineContent` は `skill-context`、複数行、truncated arguments の折りたたみ policy を既に持つが、短い単一行 tool arguments は初期展開される。
- **Implications**:
  - 一覧・詳細の metadata 表示可否は formatter の戻り値ではなく、表示可能値を判定する helper と component 側の conditional rendering に寄せる。
  - session issue と activity は既存 `IssueList` / `ActivityTimeline` を再利用し、初期状態だけを disclosure 化する。
  - tool call は `conversationContent` の collapse policy を「全 tool arguments 既定折りたたみ」に拡張し、存在と issue は見える状態を残す。

### backend contract と current model 抽出
- **Context**: current 形式でも model 名を一覧・詳細で読めるようにする要件を確認した。
- **Sources Consulted**: `backend/lib/copilot_history/current_session_reader.rb`, `legacy_session_reader.rb`, `types/normalized_session.rb`, `api/presenters/session_index_presenter.rb`, `api/presenters/session_detail_presenter.rb`, `backend/spec` fixtures, GitHub Docs の Copilot SDK streaming events と Copilot CLI programmatic reference
- **Findings**:
  - `NormalizedSession` は `selected_model` を持ち、index/detail presenter はその値をそのまま API response に出している。
  - legacy reader は `selectedModel` から `selected_model` を設定している一方、current reader は常に `nil` を設定している。
  - GitHub Docs の streaming events では `assistant.usage` が `model` を含むが ephemeral event とされるため、保存済み `events.jsonl` の主要抽出元としては弱い。`session.shutdown.data.currentModel` と `tool.execution_complete.data.model` は保存 event 候補として優先して扱う。
  - `system.message` の documented `metadata` は model field ではないため、実データ fixture で確認できるまで抽出候補から外す。CLI reference では model は `--model`、`COPILOT_MODEL`、settings の `model` などから決まるが、この spec では raw event 以外から推測しない。
  - この repository の current fixtures には model を含む event がないため、実装時に model 付き current fixture を追加する必要がある。
- **Implications**:
  - `CurrentSessionReader` に event payload から model を抽出する private helper を追加し、`session.shutdown.data.currentModel`、`tool.execution_complete.data.model`、保存済み event に実在する後方互換候補の順に確認する。確認できる値がない場合は `nil` のままにする。
  - model 推測、CLI settings の直接読取、環境変数の読取はこの spec の境界外とする。
  - API field 追加は不要で、frontend は legacy と同じ `selected_model` 表示方針を使う。

### 既存 spec との整合
- **Context**: 隣接 spec の責務を越えず、今回の表示改善だけに閉じる必要がある。
- **Sources Consulted**: `.kiro/specs/current-copilot-cli-schema-compatibility/design.md`, `.kiro/specs/conversation-ui-readability/design.md`, `.kiro/specs/frontend-session-ui/design.md`
- **Findings**:
  - `current-copilot-cli-schema-compatibility` は current event の conversation/activity 分離、raw 明示要求、`source_state` を既に定義している。
  - `conversation-ui-readability` は role styling、発話 visibility、tool arguments の一部折りたたみ、JST 表示を既に定義している。
  - `frontend-session-ui` は list/detail の read-only UI と nullable metadata の placeholder 表示を初期実装として扱っている。
- **Implications**:
  - 今回は API shape や conversation/activity projector を再設計せず、表示 policy と current model 抽出だけを変更する。
  - 詳細画面の全体レイアウト刷新ではなく、既存コンポーネントの disclosure 境界を狭く追加する。

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| UI-only 表示調整 | backend を変えずに既存 DTO の表示だけを整理する | 一覧・詳細のノイズ削減は最小変更で実現できる | current model 表示の要件を満たせない | 不採用。Requirement 3 に backend 抽出が必要 |
| API field 追加 | `display_metadata` や disclosure state を backend から返す | UI 判断を backend に集約できる | 既存 contract が肥大化し、brief の「field 追加なし」に反する | 不採用 |
| 既存 contract 再利用 + UI policy helper | `selected_model` は既存 field を使い、UI は値あり項目だけを表示する | scope が小さく current/legacy 共通表示を維持できる | UI helper と component tests の更新が必要 | 採用 |

## Design Decisions

### Decision: metadata は値がある場合だけ表示する
- **Context**: 一覧と詳細で `作業コンテキスト不明`、`モデル不明` が常に判断材料のように見える。
- **Alternatives Considered**:
  1. formatter の placeholder を維持して label 文言だけ弱める。
  2. 表示可能値を判定し、該当項目ごと非表示にする。
- **Selected Approach**: `getDisplayableWorkContext` と `getDisplayableModel` 相当の helper を presentation 層に置き、component は `null` の項目を描画しない。
- **Rationale**: 欠損値を UI 上の metadata として扱わず、既存 DTO の `null` は維持できる。
- **Trade-offs**: 欠損理由の説明は metadata 領域には出ない。破損や制約は issue / source_state に残す。
- **Follow-up**: 表示可能項目が更新日時だけ、または何もない場合に空の `dl` が残らないことを component test で確認する。

### Decision: current model は確認できる event 値だけを `selected_model` に昇格する
- **Context**: current reader は `selected_model` を常に `nil` にしている。
- **Alternatives Considered**:
  1. CLI settings や環境変数から model を推測する。
  2. event payload に存在する model 値だけを抽出する。
  3. 新しい API field で current 専用 model metadata を返す。
- **Selected Approach**: `CurrentSessionReader` が `events.jsonl` の保存済み raw event から `session.shutdown.data.currentModel` を最優先し、次に `tool.execution_complete.data.model` を読む。`assistant.usage.data.model` と root `model` は保存済み event に実在する場合だけ後方互換候補として扱う。空文字や欠損は `nil` とする。
- **Rationale**: raw files を正本にする原則と、推測値を生成しない要件に合う。既存 `selected_model` contract だけで UI 表示できる。
- **Trade-offs**: model を含まない current session では表示されない。ephemeral な `assistant.usage` が保存されない環境でも、保存済み shutdown/tool event に model がなければ推測しない。
- **Follow-up**: current fixture に `session.shutdown` と `tool.execution_complete` の model 付き event を追加し、reader / request / UI tests で legacy と同じ表示方針を確認する。

### Decision: tool issue は発話近傍 IssueList を正式な表示経路にする
- **Context**: tool arguments を既定で折りたたむと、tool call に紐づく issue の存在まで見えなくなるリスクがある。
- **Alternatives Considered**:
  1. `TimelineContent` に issue summary props を追加し、tool block 内にも issue indicator を表示する。
  2. 既存の `ConversationTranscript` が発話 entry 内で `IssueList` を表示する経路を正式な要件充足手段にする。
- **Selected Approach**: `TimelineContent` は tool 名、partial/truncated、arguments toggle に責務を限定し、event-level issue は `ConversationTranscript` の同一発話 entry 内 `IssueList` が表示する。activity 側の issue は `ActivityTimeline` の近傍 `IssueList` が担当する。
- **Rationale**: API shape と props を増やさず、既存 component の責務に沿って issue visibility を保てる。tool arguments disclosure state と issue visibility を分離できる。
- **Trade-offs**: issue indicator は tool block 内ではなく発話内の隣接 section に出る。tool 単位の issue 紐付けが必要になった場合は別 spec で DTO 変更を検討する。
- **Follow-up**: `ConversationTranscript.test.tsx` で tool arguments が collapsed のままでも同じ発話 entry 内の issue list が表示されることを確認する。

### Decision: 詳細の secondary 情報は disclosure に移す
- **Context**: session issue と activity が会話本文より前後で常時展開され、会話を読み始める妨げになっている。
- **Alternatives Considered**:
  1. section の順序だけを変える。
  2. session issue と activity を初期折りたたみにし、件数や degraded signal は残す。
- **Selected Approach**: `SessionDetailPage` は `ConversationTranscript` を先に描画し、session issue と activity は `DisclosureSection` 相当の component-local state で初期折りたたみにする。
- **Rationale**: issue の存在を隠さず、初期表示は conversation-first にできる。
- **Trade-offs**: 追加の click が必要になるが、read-only 境界と既存データは維持される。
- **Follow-up**: event-level issue は発話や activity entry 近傍の表示を維持し、session issue の折りたたみで完全に消えないことを確認する。

### Decision: tool arguments はすべて初期折りたたみにする
- **Context**: tool call 補助情報は会話の流れを遮りやすく、`skill-context` は特に長くなりやすい。
- **Alternatives Considered**:
  1. 既存どおり短い単一行 arguments は初期展開する。
  2. 全 tool arguments を初期折りたたみにし、tool 名と状態だけを常時表示する。
- **Selected Approach**: `conversationContent` の `argumentsDefaultCollapsed` を arguments preview がある tool call では原則 true にする。`skill-context` は collapse reason と label で長文候補として扱う。
- **Rationale**: Requirement 5 の「初期表示で補助情報を展開しない」を一貫して満たす。
- **Trade-offs**: 短い tool arguments も click なしでは見えない。
- **Follow-up**: tool 名、partial/truncated badge、event-level issue indicator が collapsed 時も見えることをテストする。

## Risks & Mitigations
- current event の model field が今後変わる — 抽出 helper を小さく閉じ、保存済み event fixture で確認した候補だけを読む。model が見つからない場合は `nil` として推測しない。
- 折りたたみで issue の存在まで見えなくなる — session/activity disclosure header に件数 / warning 表示を残し、tool arguments の issue は `ConversationTranscript` の発話近傍 `IssueList` に残す。
- metadata を消しすぎて比較材料が不足する — 実値のある `updated_at`、`selected_model`、work context、degraded / workspace-only だけを表示する。
- 既存 tests が placeholder 前提で落ちる — page/component tests を要件ベースに更新し、placeholder 非表示を明示する。

## References
- [GitHub Docs: Streaming events in the Copilot SDK](https://docs.github.com/en/copilot/how-tos/copilot-sdk/use-copilot-sdk/streaming-events) — current event taxonomy、`system.message` metadata、`assistant.usage` model の確認に使用。
- [GitHub Docs: Copilot CLI programmatic reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-programmatic-reference) — CLI model 指定と設定 precedence の確認に使用。
- `.kiro/specs/current-copilot-cli-schema-compatibility/design.md` — current schema、conversation/activity 分離、raw 明示要求の既存設計。
- `.kiro/specs/conversation-ui-readability/design.md` — 発話 visibility、tool disclosure、JST 表示の既存設計。
