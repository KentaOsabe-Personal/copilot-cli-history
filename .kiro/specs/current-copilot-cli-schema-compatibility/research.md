# Research & Design Decisions

## Summary
- **Feature**: `current-copilot-cli-schema-compatibility`
- **Discovery Scope**: Extension
- **Key Findings**:
  - 現行 Copilot CLI の `events.jsonl` は `type` と `data` を持つ二層 envelope で、会話イベントは `user.message` / `assistant.message` / `system.message`、非会話イベントは `assistant.turn_*` / `tool.execution_*` / `hook.*` / `skill.invoked` に分かれている。
  - 現在の backend は flat な `user_message` / `assistant_message` だけを `message | partial | unknown` へ正規化しており、current schema のままでは UI が source format 依存の分岐を抱え込む。
  - frontend は既に `raw_payload.toolRequests` を直接読んでいるが、current schema では `toolRequests` が `data` 配下にあるため、reader / presenter 側で共通 helper contract を追加する設計が必要になる。

## Research Log

### 既存 reader / API / UI の責務境界
- **Context**: 要件が「承認済み reader / API / UI の責務境界を保つ」ことを明示しているため、現行実装がどこまで format 差分を吸収しているかを確認した。
- **Sources Consulted**:
  - `backend/lib/copilot_history/current_session_reader.rb`
  - `backend/lib/copilot_history/event_normalizer.rb`
  - `backend/lib/copilot_history/api/presenters/session_detail_presenter.rb`
  - `frontend/src/features/sessions/api/sessionApi.types.ts`
  - `frontend/src/features/sessions/presentation/timelineContent.ts`
- **Findings**:
  - `CurrentSessionReader` は `workspace.yaml` と `events.jsonl` を読み、各行を `EventNormalizer` へ渡す単純な読み取り境界を持つ。
  - `EventNormalizer` は `user_message` / `assistant_message` のみを既知イベントとして扱い、role/content/timestamp が欠けた場合だけ `partial`、それ以外は `unknown` としている。
  - `SessionDetailPresenter` は `raw_payload` をそのまま timeline に出し、frontend は `raw_payload.toolRequests` を直接見て tool hint を描画している。
- **Implications**:
  - current schema 互換は reader 層で envelope を吸収し、API が frontend 向け helper field を出す設計にしないと、format 差分が UI へ漏れる。
  - controller や query は薄いまま維持し、変更中心は `copilot_history` 配下の type / normalizer / presenter と frontend の session feature に限定するのが妥当。

### 現行 Copilot CLI event schema の実データ確認
- **Context**: current schema の公式 schema 定義をこのリポジトリ内では保持していないため、実セッションの `events.jsonl` から代表形状を確認した。
- **Sources Consulted**:
  - `/Users/osabekenta/.copilot/session-state/ce757145-7031-469c-85c7-2c57f5b86b89/events.jsonl`
  - 抽出ログ `/var/folders/8d/4f0nx6n11ql4xvt5pt5ypdlh0000gn/T/copilot-tool-output-1777342459367-h3e4ie.txt`
- **Findings**:
  - `assistant.message` は root の `timestamp` と `data.content`, `data.toolRequests` を持ち、`toolRequests[*]` は `name` と `arguments` を含む。
  - `user.message` は `data.content` を持つが `data.role` は持たず、event type から会話 role を補完する必要がある。
  - 非会話イベントは `assistant.turn_start`, `assistant.turn_end`, `tool.execution_start`, `tool.execution_complete`, `hook.start`, `hook.end`, `skill.invoked` などに明確に分離されている。
- **Implications**:
  - current schema の会話 role は `data.role` だけでなく `type` prefix からも導出できる設計が必要。
  - tool request の「ツール名 + 入力要約」は assistant message から直接抽出できるため、別イベントとの相関を必須にしない設計で要件を満たせる。
  - 非会話イベントはすべて unknown 扱いにせず、少なくとも detail event として区別して timeline 上で誤認を防ぐ必要がある。

### プロダクト原則と互換方針
- **Context**: current / legacy 共存時の共通契約と degraded 可視化が、project steering と要件の両方で強く求められている。
- **Sources Consulted**:
  - `.kiro/steering/product.md`
  - `.kiro/steering/tech.md`
  - `.kiro/steering/structure.md`
  - `.kiro/specs/current-copilot-cli-schema-compatibility/requirements.md`
- **Findings**:
  - steering は raw files 正本、format 差分は reader で吸収、UI では format 分岐を増やさない方針を明示している。
  - 要件は read-only 契約を維持しつつ、current schema の会話本文、tool request 補助情報、非会話イベント、degraded 状態を区別して扱うことを求めている。
  - 既存 API には `degraded`, `issues`, `raw_payload` があり、空成功ではなく部分互換を示す器は既に存在する。
- **Implications**:
  - 新たな root failure や別 API は不要で、既存 issue / degraded モデルを current schema 互換にも拡張する方が boundary を保ちやすい。
  - UI では raw payload の完全可視化ではなく、API が正規化した tool call summary / detail summary を使う方が project 原則に合う。

### 外部ドキュメント確認
- **Context**: current schema を external dependency とみなし、公開情報に event schema の安定契約があるかを確認した。
- **Sources Consulted**:
  - [GitHub Copilot CLI repository](https://github.com/github/copilot-cli)
  - [About GitHub Copilot CLI](https://docs.github.com/en/copilot/concepts/agents/about-copilot-cli)
- **Findings**:
  - 公開ドキュメントは CLI の利用形態と権限モデルを説明しているが、`events.jsonl` の保存 schema を安定 public contract としては定義していない。
  - したがって current schema 互換は「観測した実データ + raw payload 保持 + unknown fallback」で将来差分に備える必要がある。
- **Implications**:
  - schema 固定値を UI 側へ広げず、classifier table を backend に閉じ込める。
  - 未知 type を即 failure にせず raw payload を残した unknown event と warning issue へ落とす方が将来互換に強い。

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Frontend 分岐 | presenter は raw payload を維持し、frontend が current / legacy を判別して表示する | backend 変更が少ない | steering の責務境界に反し、format 分岐が UI に漏れる | 不採用 |
| 会話のみ正規化 | current の `*.message` だけ対応し、非会話はすべて unknown のまま残す | 実装量が少ない | Requirement 2 と 3 を満たせず、tool / detail 情報が読みにくい | 不採用 |
| Backend canonicalization | reader / normalizer / presenter が current / legacy を共通 timeline contract に正規化し、UI は contract だけを見る | 共通契約を守りやすく、degraded / unknown を一貫して扱える | timeline DTO の拡張が必要 | 採用 |

## Design Decisions

### Decision: current schema の envelope 吸収は backend reader 側で行う
- **Context**: `user.message` と `assistant.message` は `data` 配下に本文を持ち、legacy と field 位置が異なる。
- **Alternatives Considered**:
  1. frontend で current / legacy を分岐する
  2. presenter で raw payload をそのまま加工する
  3. normalizer で canonical event へ統一する
- **Selected Approach**: `EventNormalizer` が source format と raw type に応じて envelope を平坦化し、`NormalizedEvent` に canonical fields を載せる。
- **Rationale**: format 差分を読み取り層で閉じ込める steering と一致し、API / UI の contract を共通化しやすい。
- **Trade-offs**: normalizer の責務は増えるが、UI 側の複雑さと重複ロジックを避けられる。
- **Follow-up**: current fixture を増やし、legacy 回帰も同じ spec 群で守る。

### Decision: 非会話イベントは `detail` kind と `unknown` kind を分ける
- **Context**: `assistant.turn_*`, `tool.execution_*`, `hook.*`, `skill.invoked` を message と誤認させず、それでも必要な詳細は追える必要がある。
- **Alternatives Considered**:
  1. すべて unknown 扱いにする
  2. raw type ごとに frontend 専用コンポーネントを増やす
  3. backend で `detail` kind と summary を付与する
- **Selected Approach**: 既知の非会話 type 群は `detail` kind に分類し、`detail.category`, `detail.title`, `detail.body` を付与する。未対応形状だけを `unknown` に残す。
- **Rationale**: message と unknown の二択よりも誤認を減らせ、debug UI 拡張なしでも必要最小限の読解支援を提供できる。
- **Trade-offs**: current raw type の classifier table を保守する必要がある。
- **Follow-up**: detail summary は各 type の要点だけに絞り、相関が必要な複雑集約は今回の範囲外に留める。

### Decision: tool request は canonical helper field を API で出す
- **Context**: assistant message の `toolRequests` は current schema では `data` 配下にあり、legacy と current で raw payload の参照位置が異なる。
- **Alternatives Considered**:
  1. `raw_payload` だけ維持して frontend が自力抽出する
  2. backend が render 済み HTML を返す
  3. backend が `tool_calls` の配列を正規化して返す
- **Selected Approach**: timeline event に `tool_calls` を追加し、各要素は `name`, `arguments_preview`, `raw_payload` を持つ。
- **Rationale**: frontend は source format 非依存で tool hint を描画でき、raw payload も保持できる。
- **Trade-offs**: DTO が少し増えるが、UI ロジックは単純になる。
- **Follow-up**: `arguments_preview` は display 用要約に限定し、コマンド実行や解釈は行わない。

### Decision: degraded 可視化は既存 issue model を拡張利用する
- **Context**: current schema の部分互換や未知 type を「空の成功」と区別する必要がある。
- **Alternatives Considered**:
  1. current 専用の新 error envelope を追加する
  2. issue を増やさず silent fallback する
  3. 既存の `degraded` / `issues` を current schema にも適用する
- **Selected Approach**: `EVENT_PARTIAL_MAPPING` と `EVENT_UNKNOWN_SHAPE` を current schema にも適用し、必要に応じて message に raw type の文脈を含める。
- **Rationale**: session failure と partial degradation の境界を既存契約のまま保てる。
- **Trade-offs**: code 名だけでは source format が分からないが、session source format と event raw type で十分に切り分け可能。
- **Follow-up**: session detail spec と UI spec で degraded 表示の継続性を確認する。

## Risks & Mitigations
- current schema の新 event type 追加で classifier が追いつかない — unknown fallback と raw payload 保持を維持し、warning issue で可視化する。
- tool input が長大で読みにくい — `arguments_preview` を要約専用 field とし、UI は通常本文と別セクションで表示する。
- backend と frontend の timeline contract 変更がずれる — presenter spec と frontend API type / page test を同時更新し、detail contract を単一 source に保つ。

## References
- `backend/lib/copilot_history/current_session_reader.rb` — current session の raw file 読み取り境界
- `backend/lib/copilot_history/event_normalizer.rb` — 既存 canonical event 正規化
- `backend/lib/copilot_history/api/presenters/session_detail_presenter.rb` — session detail API contract の出口
- `frontend/src/features/sessions/presentation/timelineContent.ts` — 既存 tool hint / code block 描画ロジック
- `/Users/osabekenta/.copilot/session-state/ce757145-7031-469c-85c7-2c57f5b86b89/events.jsonl` — 現行 schema の実サンプル
- [GitHub Copilot CLI repository](https://github.com/github/copilot-cli) — 公開ドキュメントの基点
- [About GitHub Copilot CLI](https://docs.github.com/en/copilot/concepts/agents/about-copilot-cli) — CLI の公開説明
