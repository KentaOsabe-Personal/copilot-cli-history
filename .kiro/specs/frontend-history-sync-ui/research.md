# 調査・設計判断

## Summary
- **Feature**: `frontend-history-sync-ui`
- **Discovery Scope**: Extension
- **Key Findings**:
  - 既存 frontend は `features/sessions` 配下に API client、hook、page、component、近傍 test を集約しており、同期 UI も同じ feature slice に閉じるのが最小変更である。
  - `POST /api/history/sync` は既に成功、root failure、backend failure、二重実行 conflict を区別する JSON 契約を持つため、frontend は backend 同期処理を再設計せず typed client と状態表示を追加すればよい。
  - 既存 `useSessionIndex` は初回取得と成功/空 snapshot 再利用に特化しており、同期成功後の「明示再取得」と「再取得失敗を同期成功一覧と誤認させない状態」を扱う契約が必要である。

## Research Log

### 既存 frontend extension point
- **Context**: 一覧画面へ同期導線を追加するため、既存の責務境界と変更範囲を確認した。
- **Sources Consulted**:
  - `frontend/src/features/sessions/api/sessionApi.ts`
  - `frontend/src/features/sessions/api/sessionApi.types.ts`
  - `frontend/src/features/sessions/hooks/useSessionIndex.ts`
  - `frontend/src/features/sessions/pages/SessionIndexPage.tsx`
  - `frontend/src/features/sessions/components/StatusPanel.tsx`
  - `.kiro/specs/frontend-session-ui/design.md`
- **Findings**:
  - API client は `VITE_API_BASE_URL`、browser `fetch`、`AbortSignal`、typed result union を既に使っている。
  - 一覧 hook は `loading | empty | success | error` の union と module-level reusable snapshot を持つ。
  - 一覧 page は hook の state に応じて `StatusPanel` と `SessionList` を切り替えるだけで、詳細画面への導線は `SessionSummaryCard` と `SessionList` が維持している。
  - `StatusPanel` は行動ボタンを持たないため、空状態内の主要操作や同期失敗後の再試行導線には拡張または専用コンポーネントが必要である。
- **Implications**:
  - 同期 API は `sessionApi.ts` に同居させ、`SessionApiClient` に `syncHistory` を追加する。
  - 一覧再取得は `useSessionIndex` に `reload` 契約を追加し、同期 hook から呼び出せるようにする。
  - 表示は `SessionIndexPage` に composition を置き、`SessionList` と詳細画面は変更しない。

### 同期 API 契約
- **Context**: frontend がどの HTTP status と payload を区別すべきか確認した。
- **Sources Consulted**:
  - `backend/config/routes.rb`
  - `backend/app/controllers/api/history_syncs_controller.rb`
  - `backend/lib/copilot_history/api/presenters/history_sync_presenter.rb`
  - `backend/spec/requests/api/history_syncs_spec.rb`
  - `.kiro/specs/history-sync-api/design.md`
- **Findings**:
  - `POST /api/history/sync` は body なしで同期を request 内完了し、成功時は `data.sync_run` と `data.counts` を返す。
  - 二重実行は 409 と `history_sync_running`、root failure は 503 と root failure code、永続化など backend failure は 500 と `history_sync_failed` を返す。
  - 503/500 では error envelope に加えて `meta.sync_run` と `meta.counts` が返る場合があるが、利用者表示に必要な判定は error code と message で足りる。
  - 同期 API は background job、progress polling、自動更新を提供しない。
- **Implications**:
  - frontend は 409 を conflict 表示として扱い、同期成功とは別 state にする。
  - 503/500/network/config は再試行判断用の error state に正規化する。
  - 成功時の counts は詳細な監査表示ではなく、同期完了を判断できる最小限の保存件数/劣化件数に限定して表示する。

### 既存閲覧体験との共存
- **Context**: 同期中に一覧や詳細導線を壊さない境界を確認した。
- **Sources Consulted**:
  - `.kiro/specs/frontend-session-ui/design.md`
  - `frontend/src/features/sessions/components/SessionList.tsx`
  - `frontend/src/features/sessions/components/SessionSummaryCard.tsx`
  - `frontend/src/features/sessions/pages/SessionIndexPage.test.tsx`
- **Findings**:
  - 既存一覧は backend の順序を維持し、frontend で sort しない設計である。
  - `SessionList` は summary cards の描画だけを担い、同期状態を持たない。
  - 詳細画面は route param と `useSessionDetail` に閉じており、この feature の同期 UI から変更する必要がない。
- **Implications**:
  - 同期中でも既に表示可能な `SessionList` は隠さない。
  - 同期成功後の再取得が失敗した場合は既存 snapshot を表示し続けてもよいが、「最新一覧として確認できていない」banner を必ず表示する。
  - 空状態は loading/error と区別し、同じ `syncHistory` 契約を呼ぶ primary action を持つ。

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Page-local sync state | `SessionIndexPage` が `useSessionIndex` と `useHistorySync` を組み合わせる | 既存 feature slice に閉じ、詳細画面や global state を増やさない | 一覧画面以外から同期したくなった場合は再利用境界を再検討する必要がある | 採用 |
| Global store | 同期状態と一覧 state を app 全体の store に置く | 複数画面共有に強い | 現在の要件に対して過剰で、steering の lightweight SPA 方針に反する | 不採用 |
| React Router action | route action と navigation state で POST を扱う | route 中心に統一できる | 現在の app は data router を使っておらず、導入範囲が大きい | 不採用 |

## Design Decisions

### Decision: 同期 API は既存 `SessionApiClient` に追加する
- **Context**: session list/detail と同じ backend origin、同じ error envelope、同じ config validation を使う。
- **Alternatives Considered**:
  1. 独立した `historySyncApi.ts` を作る。
  2. 既存 `sessionApi.ts` と `SessionApiClient` に `syncHistory` を追加する。
- **Selected Approach**: `sessionApi.types.ts` に同期 response 型を追加し、`SessionApiClient.syncHistory(signal?)` を `sessionApi.ts` に実装する。
- **Rationale**: `VITE_API_BASE_URL`、`requestJson`、HTTP error normalization を共有でき、API 接続先の重複設定を避けられる。
- **Trade-offs**: `SessionApiClient` の責務名は session 参照から history sync まで広がるが、feature slice が sessions 閲覧体験を所有しているため許容する。
- **Follow-up**: 将来 sync run history API が増える場合は `historySyncApi.ts` への分割を再検討する。

### Decision: 一覧 hook は明示再取得契約を持つ
- **Context**: 同期成功後に `GET /api/sessions` を再取得する必要があり、再取得失敗を成功一覧と誤認させてはいけない。
- **Alternatives Considered**:
  1. `window.location.reload()` で全体を再読み込みする。
  2. `useSessionIndex` に `reload()` を追加し、typed outcome を返す。
- **Selected Approach**: `UseSessionIndexResult` に `reloadSessions(): Promise<SessionIndexState>` と `isRefreshing` を追加する。
- **Rationale**: 既存 snapshot と詳細導線を維持しつつ、同期 hook が再取得結果を判定できる。
- **Trade-offs**: hook の状態管理は現在より複雑になるため、abort と stale response の test を追加する。
- **Follow-up**: 将来 search/filter が入る場合は reload が current query 条件を保持することを再検証する。

### Decision: 同期状態は一覧ページ専用 hook に分離する
- **Context**: 同期状態には `idle | syncing | succeeded | sync_error | conflict | refresh_error` が必要で、一覧取得 state と混ぜると責務が曖昧になる。
- **Alternatives Considered**:
  1. `useSessionIndex` に同期 POST も取り込む。
  2. `useHistorySync` を新設し、一覧 page で composition する。
- **Selected Approach**: `useHistorySync` が `syncHistory` 実行、二重実行防止、成功後 reload 呼び出し、失敗分類を担当する。
- **Rationale**: API mutation と read model 表示取得を分離し、詳細画面や `SessionList` に同期責務を漏らさない。
- **Trade-offs**: page composition は hook 2 つを扱うが、境界が明確で task 分割しやすい。
- **Follow-up**: backend が polling 型へ変わる場合はこの hook の状態 machine を再設計する。

### Decision: 表示詳細は最小限にする
- **Context**: 要件は完了/失敗判断に必要な最小限の情報へ限定している。
- **Alternatives Considered**:
  1. sync run counts を全件 table で表示する。
  2. 完了文言、保存件数、劣化件数、再取得失敗/空状態の判定だけを表示する。
- **Selected Approach**: 成功 banner は保存件数と劣化件数を簡潔に表示し、失敗は error code と再試行可能性を示す。
- **Rationale**: 一覧閲覧が主目的であり、同期 API の監査画面ではない。
- **Trade-offs**: 詳細な run 情報は UI から見えないが、backend API と DB には残る。
- **Follow-up**: 運用向け sync history 画面が必要になった場合は別 spec とする。

## Risks & Mitigations
- 同期成功後の一覧再取得失敗が旧 snapshot と混同されるリスク — `refresh_error` state と banner で「最新一覧を確認できていない」と明示する。
- 409 conflict を通常失敗と同じ文言で扱い、利用者が二重実行中と判断できないリスク — `history_sync_running` を専用 conflict state に分類する。
- `useSessionIndex` の reusable snapshot が明示再取得結果を隠すリスク — reload path は返却 outcome を必ず同期 hook に返し、error は snapshot reuse だけで握りつぶさない。
- UI 拡張が詳細画面や backend 同期処理へ広がるリスク — File Structure Plan と Boundary Commitments で変更対象を sessions 一覧 UI と typed client に限定する。

## References
- `.kiro/steering/product.md` — raw files を一次ソース、DB を再生成可能な補助層として扱う方針。
- `.kiro/steering/tech.md` — React 19 / TypeScript 6 / Vite / Vitest / Tailwind CSS 4 と Docker Compose 前提。
- `.kiro/steering/structure.md` — frontend feature slice と近傍 test の配置方針。
- `.kiro/specs/history-sync-api/design.md` — `POST /api/history/sync` の upstream API 契約。
- `.kiro/specs/frontend-session-ui/design.md` — 既存一覧/詳細 UI の境界と dependency direction。
