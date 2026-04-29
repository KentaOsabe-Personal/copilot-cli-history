# Research & Design Decisions

## Summary
- **Feature**: `current-copilot-cli-schema-compatibility`
- **Discovery Scope**: Extension
- **Key Findings**:
  - 公式 docs は `~/.copilot/session-state/{session-id}/events.jsonl` を session history の event log として説明しているが、保存 file の field-level schema を安定 public contract として固定していない。
  - Copilot SDK の event reference は `assistant.message` の `content` と `toolRequests`、`assistant.turn_*`、`tool.execution_*` を別 event として説明しており、実セッション観測とも整合する。
  - 既存実装は current dotted event の正規化を始めているが、要件 1〜8 を満たすには conversation transcript、activity、raw detail、index summary、更新時刻補正を API contract として明示する必要がある。

## Research Log

### 既存 reader / API / UI の責務境界
- **Context**: 現行 schema 互換を既存の reader / API / UI 境界を壊さず追加できるか確認した。
- **Sources Consulted**:
  - `backend/lib/copilot_history/session_source_catalog.rb`
  - `backend/lib/copilot_history/current_session_reader.rb`
  - `backend/lib/copilot_history/legacy_session_reader.rb`
  - `backend/lib/copilot_history/event_normalizer.rb`
  - `backend/lib/copilot_history/api/presenters/session_index_presenter.rb`
  - `backend/lib/copilot_history/api/presenters/session_detail_presenter.rb`
  - `frontend/src/features/sessions/api/sessionApi.types.ts`
  - `frontend/src/features/sessions/pages/SessionDetailPage.tsx`
- **Findings**:
  - source catalog は current directory と legacy JSON を分け、reader に format 差分を委譲している。
  - current reader は `workspace.yaml` と `events.jsonl` を line 単位で読み、JSONL の parse failure を issue として継続できる。
  - event normalizer は current `user.message` / `assistant.message` / `system.message` と detail event の基本分類を持つ。
  - detail presenter は full timeline を返すが、主会話 transcript と activity は API 上で分離されていない。
  - index presenter は会話有無、会話数、preview、workspace-only 状態を返していない。
- **Implications**:
  - 変更の中心は normalizer の classifier 強化、projection 層の追加、presenter DTO の拡張に置く。
  - frontend は raw payload や source format を直接見ず、`conversation` と `activity` の typed contract を描画する。

### requirements.md 更新内容の確認
- **Context**: 既存 `design.md` は古い要件 ID に基づいており、現行 `requirements.md` は 1.1〜8.5 の会話 first 要件へ更新されている。
- **Sources Consulted**:
  - `.kiro/specs/current-copilot-cli-schema-compatibility/requirements.md`
  - `.kiro/specs/current-copilot-cli-schema-compatibility/design.md`
- **Findings**:
  - 現行要件は主会話 transcript 抽出、詳細画面の conversation first、内部 activity 分離、tool request 付帯情報、一覧識別、更新時刻補正、raw detail 分離、劣化可視化を要求している。
  - 既存 design は current event 正規化と tool helper field を中心にしており、一覧 summary、raw 分離、conversation first の UI contract が不足していた。
- **Implications**:
  - design は merge ではなく現行要件 ID に合わせて再構成する。
  - traceability は 1.1〜8.5 の全 acceptance criteria を coverage する必要がある。

### 現行 Copilot CLI session data の外部確認
- **Context**: `current-copilot-cli-schema-compatibility` は外部 product の保存形式に依存するため、2026-04-28 時点の公式情報を確認した。
- **Sources Consulted**:
  - GitHub Docs: Copilot CLI configuration directory (`https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference`)
  - GitHub Docs: Best practices for Copilot CLI (`https://docs.github.com/en/copilot/how-tos/copilot-cli/cli-best-practices`)
  - GitHub Docs: Streaming events in the Copilot SDK (`https://docs.github.com/en/copilot/how-tos/copilot-sdk/use-copilot-sdk/streaming-events`)
- **Findings**:
  - CLI docs は `session-state/` が session ID ごとの履歴 data を含み、各 session directory が `events.jsonl` と workspace artifacts を保存すると説明している。
  - best practices docs も `~/.copilot/session-state/{session-id}/events.jsonl` を full session history として示している。
  - SDK streaming docs は `assistant.message` が `content` と `toolRequests` を持ち、turn event と tool execution event が別 event として流れることを示している。
  - ただし CLI の persisted `events.jsonl` field schema が公開安定 contract として宣言されているわけではない。
- **Implications**:
  - 保存 schema を固定的に信頼せず、観測済み type を classifier table に閉じ込め、unknown fallback と raw traceability を必須にする。
  - `assistant.message` の tool request は assistant 発話の付帯情報として扱えるが、`tool.execution_*` との完全相関は MVP では必須にしない。

### Project steering との整合
- **Context**: current / legacy 共存、raw files 正本、degraded 可視化は project memory にも定義されている。
- **Sources Consulted**:
  - `.kiro/steering/product.md`
  - `.kiro/steering/tech.md`
  - `.kiro/steering/structure.md`
- **Findings**:
  - raw files を正本とし、DB や search index は再生成可能な補助層として扱う。
  - format 差分は UI ではなく reader / `copilot_history` 境界で吸収する。
  - root failure と partial degradation を分け、読めた範囲を返す方針が既にある。
- **Implications**:
  - `session-store.db` や MySQL を transcript source にする案は採用しない。
  - `degraded` / `issues` の既存 model を current schema 互換にも拡張する。
  - API と UI の format 分岐を避けるため、backend projection を追加する。

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Frontend extraction | detail timeline や raw payload から frontend が会話を抽出する | backend 変更が少ない | source format 分岐が UI に漏れ、raw payload 分離と矛盾する | 不採用 |
| Presenter-only filtering | presenter が timeline から conversation を ad hoc に生成する | API 変更に近い場所で実装できる | index と detail で抽出条件が重複し、テスト境界が曖昧になる | 不採用 |
| Backend projection | normalizer の canonical event を入力に conversation / activity projection を生成する | index / detail / UI が同じ抽出条件を共有できる | projection type と spec が追加される | 採用 |
| Raw detail endpoint only | 通常 detail は軽量化し、raw は別 endpoint に分ける | raw 分離が明確 | endpoint 増加で controller/routing 変更が広がる | query param 方式を優先 |

## Design Decisions

### Decision: 主会話は `conversation` projection として API contract にする
- **Context**: 要件は detail 初期表示と index summary の両方で、内部 event ではなく user / assistant の本文を優先することを求めている。
- **Alternatives Considered**:
  1. frontend が `timeline` から抽出する
  2. presenter が画面ごとに抽出する
  3. backend projection が共通抽出条件を所有する
- **Selected Approach**: `ConversationProjector` が `NormalizedSession` から `conversation.entries` と `conversation_summary` を派生する。
- **Rationale**: 抽出条件を 1 箇所に固定でき、current / legacy の回帰も backend unit test で守れる。
- **Trade-offs**: projection type が増えるが、UI の source format 分岐を避けられる。
- **Follow-up**: task 生成時に index と detail の presenter 更新を同じ boundary にまとめる。

### Decision: activity は `detail` と `unknown` を分けて保持する
- **Context**: `assistant.turn_*`, `tool.execution_*`, `hook.*`, `skill.invoked`, unknown event は会話ではないが、調査可能性を失ってはいけない。
- **Alternatives Considered**:
  1. conversation から除外して捨てる
  2. すべて timeline のみに残す
  3. `ActivityProjector` が secondary activity として分離する
- **Selected Approach**: `ActivityProjector` が known internal event と unknown event を activity entries にし、会話 UI とは別に表示する。
- **Rationale**: 主会話の読みやすさと raw traceability を両立できる。
- **Trade-offs**: detail 画面に secondary section が増える。
- **Follow-up**: frontend は activity を初期折りたたみまたは控えめな section として扱う。

### Decision: raw payload は通常 detail から分離し、明示要求で含める
- **Context**: 要件 7 は巨大な raw detail が通常閲覧を圧迫しないことを求める一方、unknown の追跡可能性は必要である。
- **Alternatives Considered**:
  1. 既存通り全 event の raw payload を常に返す
  2. raw payload を完全に返さない
  3. `include_raw=true` の明示要求時だけ raw payload を含める
- **Selected Approach**: 通常 detail は `raw_included=false` と raw tracking metadata のみを返し、明示要求時に raw payload を含める。
- **Rationale**: 会話 first 表示の軽さを保ち、調査時の一次ソース確認も維持できる。
- **Trade-offs**: API 型とテストは raw included / omitted の 2 path を持つ。
- **Follow-up**: raw 専用 viewer はこの spec の範囲外に留める。

### Decision: 更新時刻は event timestamp を優先して補正する
- **Context**: workspace metadata の `updated_at` だけでは、実際に会話が追記された session が古く見える可能性がある。
- **Alternatives Considered**:
  1. workspace metadata のみを使う
  2. file mtime のみを使う
  3. event timestamp、file mtime、workspace metadata の順で fallback する
- **Selected Approach**: current session は最大 event timestamp を優先し、なければ `events.jsonl` mtime、最後に workspace metadata を使う。
- **Rationale**: 利用者が直近会話を探す体験に最も近く、timestamp 欠損時も実ファイル更新で補える。
- **Trade-offs**: fixture で file mtime を制御する test が必要になる。
- **Follow-up**: legacy session は既存 metadata を維持しつつ、一覧表示では同じ `updated_at` field として扱う。

### Decision: system message は raw event と activity に残し、主会話から除外する
- **Context**: 要件 1 と 3 は user / assistant の会話本文と system / internal activity の分離を求めている。
- **Alternatives Considered**:
  1. `system.message` を conversation に含める
  2. `system.message` を unknown にする
  3. canonical event と activity として残し、conversation から除外する
- **Selected Approach**: `EventNormalizer` は `system.message` を既知 message として保持し、`ActivityProjector` が system activity に写像する。
- **Rationale**: 生 event の意味は失わず、利用者の主会話読解を妨げない。
- **Trade-offs**: message kind と conversation entry の差を design / tests で明確にする必要がある。
- **Follow-up**: traceability では `NormalizedEvent` と `NormalizedConversationEntry` の責務を分けて扱う。

## Risks & Mitigations
- current schema に新 event type が追加される - backend classifier に閉じ込め、unknown fallback と issue で可視化する。
- raw payload の省略で調査性が落ちる - `sequence`, `raw_type`, `source_path`, `raw_available`, `include_raw=true` を contract に含める。
- index と detail の会話抽出条件がずれる - `ConversationProjector` を単一 source にして presenter tests で両方を確認する。
- tool arguments に秘密値が含まれる - preview 生成時に secret-like key を redact し、raw は明示要求時のみ返す。
- legacy 体験が後退する - mixed current / legacy fixture と frontend tests を task の完了条件に含める。

## Synthesis Outcomes
- **Generalization**: 「主会話抽出」「一覧会話数」「preview」「detail 初期表示」は同じ conversation projection の派生であり、別々に実装しない。
- **Build vs Adopt**: 新規 library は不要。Ruby / TypeScript の既存型と presenter / projection で十分に要件を満たせる。
- **Simplification**: tool execution の完全相関、raw 専用 viewer、DB 永続化は現在の要件から外し、read-only projection と API contract に限定する。

## References
- `backend/lib/copilot_history/current_session_reader.rb` - current session raw file reader
- `backend/lib/copilot_history/event_normalizer.rb` - canonical event classifier
- `backend/lib/copilot_history/api/presenters/session_detail_presenter.rb` - detail API response boundary
- `frontend/src/features/sessions/api/sessionApi.types.ts` - frontend DTO boundary
- `frontend/src/features/sessions/pages/SessionDetailPage.tsx` - current detail display composition
- GitHub Docs: Copilot CLI configuration directory - `https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference`
- GitHub Docs: Best practices for Copilot CLI - `https://docs.github.com/en/copilot/how-tos/copilot-cli/cli-best-practices`
- GitHub Docs: Streaming events in the Copilot SDK - `https://docs.github.com/en/copilot/how-tos/copilot-sdk/use-copilot-sdk/streaming-events`
