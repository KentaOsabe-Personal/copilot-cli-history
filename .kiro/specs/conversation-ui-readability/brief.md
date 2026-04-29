# ブリーフ: conversation-ui-readability

## 課題

GitHub Copilot CLI のローカル会話履歴を読み返す利用者が、詳細画面で User / Assistant の発話差分、長いスキル呼び出し、時刻表示、一覧へ戻ったときの待ち時間によって文脈を追いづらくなっている。

既に会話履歴は表示できているが、実際のセッションには長い `skill-context` や内部的なツール呼び出しが含まれるため、読みたい発話の流れが埋もれやすい。さらに日時が UTC 表示のままだと、日常的な作業時刻と照合しづらい。

## 現状

`frontend-session-ui` により、セッション一覧、詳細画面、会話本文、ツール呼び出し、issue 情報は read-only UI として表示できる。

一方で、現在の UI には次のギャップがある。

- 日付表示が JST として明示されていない
- 詳細画面から一覧へ戻ると、一覧データを再取得して待ちが発生する
- User / Assistant の発話が role badge 以外では見分けにくい
- `skill-context` など長いツール呼び出しが初期表示で会話を圧迫する
- 発話単位で本文を隠せないため、長いセッションを俯瞰しづらい

## 目指す状態

利用者がセッション詳細画面で会話の流れを素早く読み返せるようになる。

完了時には、日時は JST で表示され、User / Assistant の発話は視覚的に区別でき、長いスキル呼び出しは初期状態で折りたたまれる。各発話は個別に表示 / 非表示でき、一覧へ戻ったときは可能な範囲で既存の一覧データを即時再利用できる。

## 方針

新しい backend API や永続化層を追加せず、既存の frontend 表示層と hook の範囲で改善する。

日時表示は `formatTimestamp` を `Asia/Tokyo` 明示の `Intl.DateTimeFormat` ベースに更新する。会話表示は `ConversationTranscript` と `TimelineContent` を中心に、role 別スタイル、発話単位の折りたたみ、長い tool call の折りたたみを追加する。一覧再取得抑制は、外部状態管理ライブラリを導入せず、`useSessionIndex` の軽量なモジュールスコープキャッシュで扱う。

この approach を選ぶ理由は、既存の軽量 SPA 方針と read-only API 契約を維持しつつ、利用者が感じている読解上の痛みに直接効くためである。

## スコープ

- **対象範囲**:
  - セッション一覧・詳細・会話内の日時を JST 表示に統一する
  - User / Assistant 発話カードの背景色、枠線、badge を分ける
  - 発話ごとの表示 / 非表示 UI を追加する
  - `skill-context` と長い tool call arguments を初期折りたたみにする
  - 詳細から一覧へ戻った際に一覧取得結果を再利用する軽量キャッシュを追加する
  - 上記に対応する frontend の単体・コンポーネントテストを追加 / 更新する
- **対象外**:
  - backend API contract の変更
  - セッション履歴の読取・正規化ロジックの変更
  - 検索、絞り込み、並び替え条件の変更
  - ユーザー設定としてのタイムゾーン選択
  - 折りたたみ状態の永続化
  - 外部状態管理ライブラリやデータ取得ライブラリの導入

## 境界候補

- **日時フォーマット境界**: API の UTC / ISO timestamp はそのまま受け取り、表示層の formatter で JST に変換する。
- **会話カード境界**: 発話単位の role 表現と表示 / 非表示は `ConversationTranscript` が所有する。
- **コンテンツブロック境界**: コード、テキスト、tool call の表示判断は presentation model と `TimelineContent` が所有する。
- **一覧キャッシュ境界**: セッション一覧の取得結果再利用は `useSessionIndex` 内に閉じ、ルーティングや backend には波及させない。

## 境界外

- raw payload の完全表示体験はこの spec では扱わない。
- 実データの欠損や schema 差分を補正する処理は backend reader / API specs の責務とする。
- 会話検索やフィルタ UI は将来の探索系 spec に委ねる。
- 詳細画面の活動タイムライン全体の再設計は行わず、今回の主対象は会話本文の読解性と戻り操作の体感改善に限定する。

## 上流 / 下流

- **上流**:
  - `frontend-session-ui`: 一覧画面、詳細画面、会話表示、ツール呼び出し表示の基礎 UI
  - `backend-session-api`: read-only のセッション一覧・詳細 API contract
  - `current-copilot-cli-schema-compatibility`: current schema の会話・tool call 情報を UI が利用できる形に正規化する前提
- **下流**:
  - 将来の検索・絞り込み UI
  - 会話本文の全文検索やハイライト表示
  - ユーザー設定による表示形式変更
  - 長大セッション向けのナビゲーション改善

## 既存 spec との接点

- **拡張元**:
  - `frontend-session-ui`: 既存の閲覧 UI を土台に、読解性と軽量な状態再利用を追加する
- **隣接**:
  - `backend-session-api`: API contract は変更しない前提で利用する
  - `backend-history-reader`: 履歴読取や degraded 判定は変更しない
  - `current-copilot-cli-schema-compatibility`: tool call や会話本文が既存型で提供されることを前提にする

## 制約

- Markdown / spec 文書は日本語で書く。
- フロントエンドは React 19 / TypeScript / Vite / Vitest / Tailwind CSS 4 の既存構成に従う。
- Docker Compose を開発・検証の正本とする。
- 新規ライブラリ導入は避け、既存の軽量 SPA 方針を維持する。
- API contract と backend 実装を変更しない。実データ上 API 変更が必要だと判明した場合は、この spec の範囲から切り出して別途扱う。
- 一覧再取得抑制は「複雑化するなら許容可能」な項目として扱い、実装中に過度な設計変更が必要になった場合はスコープ縮小を許容する。
