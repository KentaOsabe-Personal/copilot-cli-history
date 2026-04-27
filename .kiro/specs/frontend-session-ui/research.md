# Research & Design Decisions

## Summary
- **Feature**: `frontend-session-ui`
- **Discovery Scope**: Extension / Light discovery
- **Key Findings**:
  - 既存 frontend は `App.tsx` の静的プレースホルダーだけで、routing・API client・画面状態管理の責務境界が未定義である。
  - backend-session-api は `GET /api/sessions` と `GET /api/sessions/:id` の read-only 契約、`404 session_not_found`、`503` 系 failure envelope、`degraded` / `issues` / `raw_payload` をすでに返しており、frontend は追加の backend 拡張なしで要件を満たせる。
  - 直接 URL 表示は React Router の declarative library mode で十分に満たせる。現スコープでは data router や global query library を導入するより、typed fetch + feature-local hooks の方が steering に整合する。

## Research Log

### 既存 frontend の拡張ポイント
- **Context**: どこに routing・fetch・UI state を配置するかを決める必要があった。
- **Sources Consulted**: `.kiro/steering/tech.md`, `.kiro/steering/structure.md`, `frontend/package.json`, `frontend/src/main.tsx`, `frontend/src/App.tsx`, `frontend/src/App.test.tsx`, `frontend/src/test/setup.ts`
- **Findings**:
  - frontend は React 19 / TypeScript 6 / Vite / Tailwind CSS 4 / Vitest の最小構成で、現状の `App.tsx` は static hero を描画するだけである。
  - `main.tsx` は `App` を直接 mount しており、router や config helper は存在しない。
  - path alias は未導入で、steering も相対 import と feature 近傍テストを前提にしている。
- **Implications**:
  - route host、typed API client、custom hook、page component を feature-local に追加する構成が最も自然である。
  - global state manager や shared UI framework を先行導入せず、`features/sessions/` 以下に責務を閉じる。

### backend-session-api 契約と runtime 前提
- **Context**: frontend 側が空状態、not found、fatal failure、degraded success をどう分離するかを確定したかった。
- **Sources Consulted**: `.kiro/specs/backend-session-api/design.md`, `backend/config/routes.rb`, `backend/app/controllers/api/sessions_controller.rb`, `backend/lib/copilot_history/api/presenters/session_index_presenter.rb`, `backend/lib/copilot_history/api/presenters/session_detail_presenter.rb`, `backend/spec/requests/api/sessions_spec.rb`, `backend/config/initializers/cors.rb`, `docker-compose.yml`
- **Findings**:
  - 一覧 API は `{ data, meta }` の 200 応答を返し、空配列と `503` error envelope を明確に区別する。
  - 詳細 API は 200 / 404 / 503 を使い分け、timeline event ごとに `sequence`, `kind`, `raw_type`, `occurred_at`, `role`, `content`, `raw_payload`, `degraded`, `issues` を返す。
  - Docker Compose は frontend に `VITE_API_BASE_URL=http://localhost:30000` を供給し、backend の CORS は `http://localhost:51730` と `http://127.0.0.1:51730` を許可している。
- **Implications**:
  - frontend は `VITE_API_BASE_URL` を唯一の API 接続点として扱い、status code と envelope を typed error union に正規化すべきである。
  - 一覧は backend が返した順序を保持して描画し、detail は timeline の `sequence` 順を維持して表示する。
  - degraded session は失敗扱いにせず、成功状態の中で badge と issue 説明を表示する。

### Routing 採用方針
- **Context**: 一覧から詳細への遷移と、詳細 URL の直接表示を最小依存で実現したい。
- **Sources Consulted**: `frontend/package.json`, `frontend/src/main.tsx`, React Router 公式 docs `https://reactrouter.com/start/library/installation`, `https://reactrouter.com/start/declarative/routing`, `https://reactrouter.com/api/declarative-routers/BrowserRouter`
- **Findings**:
  - React Router 公式の library mode は `react-router` package と `BrowserRouter` / `Routes` / `Route` / `Link` を用いる declarative 構成を推奨している。
  - `BrowserRouter` は browser history を用いた SPA routing を提供し、現在の Vite SPA 構成と整合する。
  - 今回必要なのは list route と detail route の 2 画面だけであり、data loader / action / framework mode を導入する必然性はない。
- **Implications**:
  - build vs adopt の観点では custom History API 実装ではなく `react-router` を採用する。
  - simplification の観点では data router や file-based routing を導入せず、`main.tsx` と `App.tsx` で明示的な route tree を定義する。

### タイムライン表示の制約
- **Context**: ツール呼び出し、コードブロック、partial / unknown event を backend 契約拡張なしでどう可視化するかを判断したかった。
- **Sources Consulted**: `.kiro/specs/frontend-session-ui/requirements.md`, `backend/lib/copilot_history/api/presenters/session_detail_presenter.rb`, `backend/spec/lib/copilot_history/api/presenters/session_detail_presenter_spec.rb`, `copilot-cli-session-history-research.md`
- **Findings**:
  - backend の canonical detail payload には dedicated な `tool_call` flag は存在せず、frontend が見られるのは `content` と `raw_payload` である。
  - 調査メモでは、現行 Copilot CLI の assistant event raw payload に `toolRequests` のような構造化データが含まれ得る。
  - `content` は code fence を含み得るため、HTML/Markdown をそのまま評価するより、text と fenced code を安全に segment 化する方が local-only viewer として安全である。
- **Implications**:
  - timeline renderer は canonical detail payload に既に現れる既知の構造化 hint だけを扱い、識別できない場合は plain message として扱う。
  - code block は client-side で fenced code を分離し、`pre` / `code` 相当の safe rendering に限定する。
  - unknown / partial event でも本文や raw type を捨てず、issue と同時に読める UI にする。

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Route-centric feature module | `react-router` による route host、typed API client、feature-local hooks、presentation helpers で構成する | 境界が明確、既存 frontend の最小構成と整合、task を page / hook / renderer に分割しやすい | file 数は増える | **採用** |
| Single `App.tsx` inline fetch | `App.tsx` に list/detail 判定、fetch、timeline rendering をすべて集約する | 初期差分は小さい | 責務が密結合になり、error 分岐と route 追加で崩れやすい | 却下 |
| Global query/store first | router loader、query cache、global store を先に導入する | 将来の検索・再読込に広げやすい | 現スコープには過剰で、steering の「軽量な SPA」を外れる | 将来 spec で再検討 |

## Design Decisions

### Decision: React Router の declarative library mode を採用する
- **Context**: 直接 URL 表示と一覧→詳細の遷移を、現在の Vite SPA に最小変更で導入する必要がある。
- **Alternatives Considered**:
  1. `window.history` と手書き route 判定で構築する
  2. `react-router` の declarative routing を採用する
  3. React Router framework/data mode へ拡張する
- **Selected Approach**: `react-router` を依存に追加し、`main.tsx` で `BrowserRouter` を mount、`App.tsx` で `/` と `/sessions/:sessionId` の route tree を宣言する。
- **Rationale**: adopt を優先しつつ、routing の責務だけを取り込める。React 19 / Vite に対する公式ドキュメントもあり、ユーザー操作と direct URL の両方を自然に扱える。
- **Trade-offs**: 静的ホスティングで SPA fallback が必要な runtime へ移る場合は revalidation が必要になる。
- **Follow-up**: 実装時は current dev runtime では Vite の history fallback に依存し、runtime が変わる場合のみ再評価する。

### Decision: API 統合は feature-local client + page hook に閉じる
- **Context**: 一覧と詳細は共通の backend 契約を使うが、画面ごとに loading / empty / not found / error の状態機械が異なる。
- **Alternatives Considered**:
  1. page component が `fetch` を直接呼ぶ
  2. `SessionApiClient` と `useSessionIndex` / `useSessionDetail` に責務分離する
  3. global query library を導入する
- **Selected Approach**: `sessionApi.types.ts` に API contract と error union を定義し、`sessionApi.ts` が HTTP 正規化、hooks が page-specific state machine を提供する。
- **Rationale**: generalization として HTTP contract 解釈は 1 箇所へ寄せつつ、list/detail の状態差分は各 hook に閉じ込められる。steering の「過度な状態管理を持ち込まない」にも合う。
- **Trade-offs**: cache や再利用 state は持たないため、route ごとに fetch が走る。
- **Follow-up**: 実装時に request abort と config error を明示的に state へ反映させる。

### Decision: タイムライン本文は safe text / code / recognizable tool hint の 3 系統で描画する
- **Context**: 要件は tool 呼び出しと code block の識別表示を求めるが、backend は専用 UI flag を持たない。
- **Alternatives Considered**:
  1. Markdown / HTML renderer を導入して content 全体を解釈する
  2. `content` と canonical detail payload から必要最小限の visual block を導出する
- **Selected Approach**: `timelineContent.ts` が `content` の fenced code を抽出し、canonical detail payload に既に現れている recognized structured hint の限定 allowlist から tool hint を導出し、`TimelineContent.tsx` は text / code / tool hint block だけを安全に描画する。
- **Rationale**: build vs adopt の観点では、フル Markdown renderer を足すよりもこの feature に必要な表現だけを組み立てる方がスコープと安全性に合う。`dangerouslySetInnerHTML` を避けつつ、frontend が current / legacy 差分の吸収責務を持たないで済む。
- **Trade-offs**: 未知の rich formatting は plain text fallback になる。
- **Follow-up**: 実装時は recognized hint が存在しない payload や未知 schema でも本文表示を失わないことをテストで固定する。

### Decision: 画面状態は page-local で明示し、自動再試行や再読込 UI は導入しない
- **Context**: requirements は loading、empty、not found、failure の視認性を求める一方、再読み込み操作や自動更新は out of scope である。
- **Alternatives Considered**:
  1. 背景再試行や refresh button を追加する
  2. 1 回の request 結果を明示状態として画面に出す
- **Selected Approach**: `StatusPanel` と page components が `loading` / `empty` / `not_found` / `error` を描画し、ユーザーの再判断導線は一覧リンクに限定する。
- **Rationale**: simplification と boundary-first を優先し、成功表示と失敗表示の混同を避ける。要件 4.4 の non-goal を UI でも守れる。
- **Trade-offs**: 一時的 failure からの回復はブラウザ再訪問に依存する。
- **Follow-up**: 実装時は error panel が list link を常に提供することを page test で確認する。

## Risks & Mitigations
- backend response shape や error code が変わると frontend state 分岐が崩れる — API client の contract test と `sessionApi.types.ts` の集中定義で drift を検知する。
- static host が SPA fallback を提供しない runtime へ移ると direct URL が壊れる — current runtime は Vite dev を前提とし、deploy 形態が変わるときだけ revalidation trigger にする。
- raw payload の hint schema が変わると tool hint が欠落する — structured parse は限定 allowlist の best-effort に留め、fallback を plain text 表示に固定する。
- タイムラインが長い session で描画コストが増える — 本 spec では virtualization を導入せず、実測で問題化したら別 spec で扱う。

## References
- `.kiro/specs/frontend-session-ui/requirements.md` — 要件 ID と boundary
- `.kiro/specs/backend-session-api/design.md` — 依存する backend 契約
- `frontend/package.json` — 現行 frontend 依存関係
- `frontend/src/main.tsx`, `frontend/src/App.tsx`, `frontend/src/App.test.tsx` — 既存 frontend 構造
- `backend/spec/requests/api/sessions_spec.rb` — list/detail HTTP 契約
- `backend/lib/copilot_history/api/presenters/session_detail_presenter.rb` — detail payload shape
- `backend/config/initializers/cors.rb`, `docker-compose.yml` — frontend/backend 接続前提
- [React Router Installation](https://reactrouter.com/start/library/installation) — declarative library mode の導入手順
- [React Router Declarative Routing](https://reactrouter.com/start/declarative/routing) — route 宣言と dynamic segment
- [React Router BrowserRouter](https://reactrouter.com/api/declarative-routers/BrowserRouter) — browser history router の公式説明
