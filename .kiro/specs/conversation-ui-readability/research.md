# 調査と設計判断

## 要約
- **機能**: `conversation-ui-readability`
- **調査範囲**: Extension
- **主要な知見**:
  - 既存 UI は `frontend/src/features/sessions` 配下に API 型、presentation helper、components、hooks、pages がまとまっており、今回の改善は frontend 表示層と `useSessionIndex` の状態管理だけで完結できる。
  - 日時表示は全表示箇所が `formatTimestamp` を経由しているため、`Asia/Tokyo` と `JST` 明示は formatter の契約変更で一覧、詳細 header、会話、activity timeline に波及できる。
  - tool call と会話本文は `conversationContent.ts` と `TimelineContent.tsx` を共有して表示されているため、折りたたみ方針は presentation model に寄せ、実際の展開状態は component-local state として扱うのが最小変更になる。

## 調査ログ

### 既存 frontend 境界
- **背景**: 会話読解性改善が backend API 変更を必要とするかを確認した。
- **参照元**: `frontend/src/features/sessions/api/sessionApi.types.ts`, `frontend/src/features/sessions/components/ConversationTranscript.tsx`, `frontend/src/features/sessions/components/TimelineContent.tsx`, `frontend/src/features/sessions/presentation/conversationContent.ts`, `frontend/src/features/sessions/presentation/timelineContent.ts`
- **知見**:
  - `SessionConversationEntry` は `role`, `sequence`, `occurred_at`, `content`, `tool_calls`, `degraded`, `issues` を既に持つ。
  - `ConversationTranscript` は会話 entry 単位で描画しているが、発話の表示状態は持っていない。
  - `TimelineContent` は text / code / tool hint / detail を描画する共有 component で、tool call arguments は常時 `<pre>` 表示している。
  - `IssueList` は発話 issue と activity issue の表示に再利用できる。
- **示唆**: 発話単位の折りたたみ、role 別カード、tool call arguments の初期折りたたみは frontend component と presentation helper の拡張で実現できる。API DTO 変更は不要である。

### 日時表示の集約点
- **背景**: JST 表示を全日時箇所へ一貫適用できるか確認した。
- **参照元**: `frontend/src/features/sessions/presentation/formatters.ts`, `SessionSummaryCard.tsx`, `SessionDetailHeader.tsx`, `ConversationTranscript.tsx`, `TimelineEntry.tsx`, `ActivityTimeline.tsx`, `formatters.test.ts`
- **知見**:
  - 一覧 card、詳細 header、会話 entry、timeline entry、activity entry はすべて `formatTimestamp` を使っている。
  - 現在は `toISOString()` により UTC 表示へ固定されている。
  - null は `時刻不明`、解釈不能値は入力値を返す既存挙動である。
- **示唆**: `formatTimestamp` を `Intl.DateTimeFormat` と `timeZone: 'Asia/Tokyo'` に変更し、成功変換時だけ `JST` を付与する。欠落値と解釈不能値は JST 成功結果と誤認されない表示を維持する。

### 一覧データの再利用境界
- **背景**: 詳細から一覧へ戻ったときの待ち時間を、外部状態管理なしで抑制できるか確認した。
- **参照元**: `frontend/src/features/sessions/hooks/useSessionIndex.ts`, `useSessionIndex.test.tsx`, `SessionIndexPage.tsx`, `SessionDetailHeader.tsx`
- **知見**:
  - `useSessionIndex` は hook-local settled state を持つため、一覧 route が unmount されると成功状態を失う。
  - 詳細への遷移は React Router の通常 route 変更であり、一覧画面は再 mount される。
  - `UseSessionIndexOptions` は test client injection を持ち、client identity を cache boundary として扱える。
- **示唆**: `useSessionIndex.ts` 内に module-scope の直近成功 snapshot を置けば、同一 client の再 mount 時に success / empty を即時返せる。error は再利用せず、永続化や global store は導入しない。

### 関連 spec との整合
- **背景**: downstream / upstream の責務を越えない設計境界を確認した。
- **参照元**: `.kiro/specs/frontend-session-ui/design.md`, `.kiro/specs/backend-session-api/design.md`, `.kiro/specs/current-copilot-cli-schema-compatibility/design.md`
- **知見**:
  - `frontend-session-ui` は route-centric SPA、typed API client、page-local state、軽量 UI を前提としている。
  - `backend-session-api` は list / detail API 契約を所有し、frontend は response shape を変更しない前提で利用する。
  - `current-copilot-cli-schema-compatibility` は conversation / activity / tool call DTO を backend 側で正規化し、frontend が source format を直接判定しない境界を定めている。
- **示唆**: 今回の設計は `frontend/src/features/sessions` 内の表示改善と transient UI state に限定する。backend presenter、reader、DTO の shape 変更は revalidation trigger とする。

## アーキテクチャパターン評価

| 選択肢 | 説明 | 長所 | リスク / 制約 | 備考 |
|--------|------|------|----------------|------|
| Frontend presentation extension | 既存 DTO をそのまま使い、formatter、presentation helper、components、hook cache を拡張する | API 変更なし。既存 test 配置に沿う。実装範囲が小さい | UI state が component / hook に分散するため、所有範囲を明記する必要がある | 採用 |
| Backend DTO extension | role style や tool collapse hint を API から返す | frontend 判断が薄くなる | backend が表示方針を持つことになり、read-only API contract の責務を広げる | 不採用 |
| External data fetching library | cache と loading state を専用 library に任せる | 再利用や stale handling が体系化される | 新規依存が増え、今回の戻り操作改善には過剰 | 不採用 |

## 設計判断

### 判断: JST 表示は `formatTimestamp` に集約する
- **背景**: 一覧、詳細 header、会話、activity timeline の日時を同じ規則で JST として識別可能にする必要がある。
- **検討した代替案**:
  1. 各 component で `Intl.DateTimeFormat` を直接使う。
  2. `formatTimestamp` の契約を JST 表示へ変更する。
- **採用方針**: `formatTimestamp(value: string | null): string` を唯一の日時表示境界とし、成功変換時だけ `YYYY-MM-DD HH:mm:ss JST` 相当の表示を返す。
- **理由**: 既存 component はすでに formatter を経由しており、変更範囲を最小化できる。
- **トレードオフ**: formatter の既存 UTC snapshot test は更新が必要になる。
- **フォローアップ**: null と invalid input が JST 成功表示に見えないことを `formatters.test.ts` で固定する。

### 判断: 折りたたみ状態は永続化しない local state とする
- **背景**: 発話単位の表示 / 非表示と tool call arguments の展開は、セッション外へ永続化しない要件である。
- **検討した代替案**:
  1. URL query や localStorage へ保存する。
  2. `ConversationTranscript` と `TimelineContent` の component-local state に閉じる。
- **採用方針**: 発話 visibility は `ConversationTranscript` が `sequence` 単位で保持し、tool arguments disclosure は `TimelineContent` が block 単位で保持する。
- **理由**: 要件は transient UI state のみを求めており、永続層や route contract を増やす必要がない。
- **トレードオフ**: page reload や別 session への遷移で状態は初期化される。
- **フォローアップ**: 発話非表示時にも sequence、role、日時、degraded が残ることを component test で確認する。

### 判断: tool call 折りたたみ方針は presentation model に持たせる
- **背景**: `skill-context` と複数行 arguments preview と truncated preview は初期折りたたみ対象だが、tool call の存在と tool 名は常に見える必要がある。
- **検討した代替案**:
  1. `TimelineContent.tsx` で文字列条件を直接判定する。
  2. `conversationContent.ts` の visual block に初期折りたたみ理由を含める。
- **採用方針**: tool hint block に `argumentsDefaultCollapsed` と `collapseReason` を含め、`TimelineContent` はその state を描画する。
- **理由**: 判定と表示を分離でき、conversation と timeline の共有表示でも同じ規則を使える。
- **トレードオフ**: presentation model の型と test を更新する必要がある。
- **フォローアップ**: `skill-context`、複数行、truncated、短い単一行 preview の各分岐を `conversationContent.test.ts` と `TimelineContent.test.tsx` で固定する。

### 判断: 一覧再利用は `useSessionIndex` の module-scope cache に限定する
- **背景**: 詳細から一覧へ戻ったときに直前の成功一覧または空状態を即時再表示したいが、検索や refresh の新操作は追加しない。
- **検討した代替案**:
  1. React context や external store を追加する。
  2. `useSessionIndex.ts` 内で同一 client の直近 success / empty を保持する。
- **採用方針**: `SessionIndexCacheSnapshot` を module-scope に置き、hook 初期状態に利用する。background fetch は既存どおり行い、成功時に snapshot を更新する。
- **理由**: route 間の体感改善に必要な最小範囲であり、既存の軽量 SPA 方針に合う。
- **トレードオフ**: process reload や別 browser tab には共有されない。
- **フォローアップ**: cache hit 時に selectable な success / empty を即時返し、未取得時は loading を返すことを `useSessionIndex.test.tsx` で確認する。

## リスクと対策
- `Intl.DateTimeFormat` の locale 差分で test が不安定になる — `formatToParts` または deterministic な整形 helper に寄せ、成功時の suffix を明示的に組み立てる。
- tool call arguments が非常に長い場合に展開後も画面を圧迫する — 既存の `overflow-x-auto` と `whitespace-pre-wrap` を維持し、初期状態では本文を優先する。
- module-scope cache が test 間で残る — test 専用の clear helper を export するか、client identity を分けて干渉を避ける設計にする。
- role 別 styling が code block や issue 表示の contrast を落とす — role の背景・枠線は外側 card に限定し、本文 block の既存配色は読みやすさを保つ。

## 参考資料
- `.kiro/steering/product.md` — local-first、read-only、壊れたデータも隠さない原則。
- `.kiro/steering/tech.md` — React 19 / TypeScript / Vite / Vitest / Tailwind CSS 4 と軽量 SPA 方針。
- `.kiro/steering/structure.md` — frontend feature 近傍配置、relative import、UI 近傍 test の構成。
- `.kiro/specs/frontend-session-ui/design.md` — 既存 route-centric SPA と session UI 境界。
- `.kiro/specs/backend-session-api/design.md` — list / detail API contract の ownership。
- `.kiro/specs/current-copilot-cli-schema-compatibility/design.md` — conversation / activity / tool call DTO の既存契約。
