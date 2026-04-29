# Brief: session-ui-noise-reduction

## Problem

GitHub Copilot CLI のローカル会話履歴を読み返す利用者が、セッション一覧と詳細画面で「常に出るが判断材料になりにくい情報」を見せられ続けるため、会話本文に素早く辿り着きにくい。

特に、一覧の `会話あり` / `一部欠損あり` / `degraded`、一覧・詳細の `作業コンテキスト不明` / `モデル不明`、詳細のセッション issue、会話中のツール呼び出し、`skill-context`、内部 activity が既定表示で並ぶことで、差分よりノイズの方が目立っている。

## Current State

`frontend-session-ui` により、一覧画面、詳細画面、会話本文、ツール呼び出し、issue 情報は read-only UI として表示できる。`current-copilot-cli-schema-compatibility` により current schema の会話本文や tool call 補助情報も UI に渡せている。

一方で、現在の UI には次のギャップがある。

- 一覧の常設バッジが差分として機能していない
- 詳細のセッション issue が常に表示され、会話本文の前にノイズになっている
- `作業コンテキスト` と `モデル` が実データに乏しく、ほぼ常に `不明` 表示になる
- current session の model は `system.message` に情報源があるのに session-level へ抽出されていない
- ツール呼び出しや内部 activity が既定表示で開いており、conversation-first になっていない

## Desired Outcome

利用者が一覧では「開く価値のある差分」だけを見てセッションを選べ、詳細では会話本文を最初に読めるようになる。

完了時には、不要な常設ラベルや `不明` プレースホルダーは既定表示から外れ、モデル名は current session でも表示可能になり、詳細ではセッション issue・ツール呼び出し・`skill-context`・内部 activity が会話本文を邪魔しない初期表示になる。

## Approach

新規 spec として、既存の `conversation-ui-readability` からは切り離して管理する。実装自体は既存 UI と API 契約を土台にしつつ、表示ポリシーの整理、current session の model 抽出、詳細画面の既定 disclosure 制御を一つの責務として束ねる。

backend では `CurrentSessionReader` に current schema 向けの model 抽出を追加し、frontend では表示 helper と detail page 周辺コンポーネントを更新する。API contract は既存の `selected_model` を再利用し、新しい field は増やさない。

## Scope

- **In**:
  - 一覧の常設バッジを「例外時のみ表示」に整理する
  - 一覧・詳細の `作業コンテキスト` / `モデル` を「値があるときだけ表示」にする
  - current session の `system.message` から model 名を抽出して `selected_model` に反映する
  - 詳細のセッション issue セクションを既定表示から外す
  - 詳細のツール呼び出し、`skill-context`、内部 activity を既定で閉じる
  - 上記に対応する backend / frontend テストの更新
- **Out**:
  - backend API contract の新規 field 追加
  - degraded 判定ロジックや issue 生成ルール自体の見直し
  - 検索、絞り込み、並び替え、手動再読み込みなどの新機能
  - raw payload viewer の再設計
  - 詳細画面全体のレイアウト刷新

## Boundary Candidates

- **一覧シグナル境界**: 一覧カードで何を「常時表示」し、何を「例外時のみ表示」にするか
- **session metadata 境界**: `work_context` と `selected_model` を UI 表示に載せる条件
- **current schema model 抽出境界**: `system.message` から session-level metadata を導出する責務
- **detail disclosure 境界**: セッション issue、tool hints、activity をどの初期状態で見せるか

## Out of Boundary

- event 単位 / 発話単位の issue 自体を無効化すること
- history reader の root 解決やイベント正規化全体の再設計
- session 一覧キャッシュや JST 表示など、別 spec で既に扱われている読解性改善の再定義
- raw payload の常時表示や debug 専用画面の追加

## Upstream / Downstream

- **Upstream**:
  - `frontend-session-ui` の既存一覧・詳細 UI
  - `backend-session-api` の read-only list / detail contract
  - `current-copilot-cli-schema-compatibility` の current schema 互換
- **Downstream**:
  - 将来の「詳細を開いたときの既定表示」改善全般
  - 検索や要約など、一覧の情報密度を上げる機能

## Existing Spec Touchpoints

- **Extends**: なし。この改善群は管理上、新規 spec として独立させる
- **Adjacent**:
  - `conversation-ui-readability`: 会話の読みやすさ改善と隣接
  - `current-copilot-cli-schema-compatibility`: model 抽出元の current schema 解釈と隣接
  - `frontend-session-ui`: 既存画面構造の土台

## Constraints

- Markdown / spec 文書は日本語で書く。
- API contract は既存 field の再利用を優先し、field 追加は行わない。
- read-only 境界は維持し、編集・削除・共有操作は追加しない。
- current / legacy の両方で表示回帰を起こさない。
- 既存の Docker Compose ベースのテスト導線に従う。
