# 要件定義書

## プロジェクト記述（入力）
**課題を抱える人:** GitHub Copilot CLI のローカル会話履歴を読み返す利用者。

**現状:** `frontend-session-ui` により、セッション一覧、詳細画面、会話本文、ツール呼び出し、issue 情報は read-only UI として表示できている。  
一方で、実際のセッションには長い `skill-context` や内部的なツール呼び出しが含まれるため、User / Assistant の発話差分、長いスキル呼び出し、UTC の時刻表示、一覧へ戻ったときの再取得待ちによって文脈を追いづらくなっている。

**変更したいこと:** 利用者がセッション詳細画面で会話の流れを素早く読み返せるようにする。  
日時は JST で表示され、User / Assistant の発話は視覚的に区別でき、長いスキル呼び出しは初期状態で折りたたまれる。各発話は個別に表示 / 非表示でき、一覧へ戻ったときは可能な範囲で既存の一覧データを即時再利用できるようにする。

## はじめに
この仕様は、GitHub Copilot CLI のローカル会話履歴を読み返す利用者が、セッション詳細画面で会話の流れを素早く把握できるようにするための要件を定義する。  
対象は既存の read-only 閲覧体験の読解性改善に限定し、日時表示、User / Assistant 発話の視覚的区別、発話単位の表示切り替え、長い tool call 表示の圧縮、一覧へ戻る操作の体感改善を含む。

## 境界コンテキスト
- **対象範囲**: セッション一覧・詳細・会話内の日時を JST として識別できる表示に統一すること、User / Assistant 発話を視覚的に区別すること、発話単位で本文を表示 / 非表示できること、`skill-context` と長い tool call arguments を初期状態で折りたたむこと、詳細画面から一覧へ戻ったときに可能な範囲で直前の一覧表示を即時再利用すること
- **対象外**: backend API contract の変更、履歴ファイルの読取・正規化ルールの変更、検索・絞り込み・並び替え条件の変更、タイムゾーン選択のユーザー設定、折りたたみ状態の永続化、raw payload 専用 viewer、詳細画面全体の再設計
- **隣接前提**: `frontend-session-ui` が一覧・詳細・会話表示の基礎を提供していること、`backend-session-api` が read-only のセッション一覧・詳細データを既存契約で返すこと、`current-copilot-cli-schema-compatibility` が user / assistant 発話と tool call 補助情報を表示可能な形で提供すること

## 要件

### 要件1: JST として識別できる日時表示
**目的:** ローカル履歴を読み返す利用者として、日常の作業時刻と照合しやすい日時表示がほしい。そうすることで、セッションや発話がいつ行われたかを誤解せず確認できる。

#### 受け入れ基準
1. セッション一覧が日時を表示するとき、Copilot History Application はその日時を JST として識別できる形式で表示する。
2. セッション詳細ヘッダーが日時を表示するとき、Copilot History Application はその日時を JST として識別できる形式で表示する。
3. 会話発話または activity timeline 項目が発生日時を表示するとき、Copilot History Application はその日時を JST として識別できる形式で表示する。
4. 日時値が欠落しているとき、Copilot History Application は既存の欠落表示を維持し、JST の日時として誤認される値を表示しない。
5. 日時値が解釈できないとき、Copilot History Application は入力値を成功した JST 変換結果として表示しない。

### 要件2: User / Assistant 発話の視覚的区別
**目的:** 会話の流れを追う利用者として、User と Assistant の発話を一目で見分けたい。そうすることで、長いセッションでも発話主体を読み違えずに文脈を追える。

#### 受け入れ基準
1. 会話 transcript が user 発話を表示するとき、Copilot History Application は user 発話であることを badge だけに依存せず視覚的に識別できる表示にする。
2. 会話 transcript が assistant 発話を表示するとき、Copilot History Application は assistant 発話であることを badge だけに依存せず視覚的に識別できる表示にする。
3. user 発話と assistant 発話が連続して表示されている間、Copilot History Application は両者の背景、枠線、または強調表示の違いによって発話主体を比較できるようにする。
4. 発話が degraded 状態または issue 情報を持つとき、Copilot History Application は role の識別表示を維持したまま、その発話が不完全であることも識別できるようにする。
5. Copilot History Application は role の視覚的区別によって発話本文、コードブロック、tool call 補助情報の可読性を低下させない。

### 要件3: 発話単位の表示 / 非表示
**目的:** 長い会話履歴を俯瞰したい利用者として、発話ごとに本文を隠せるようにしたい。そうすることで、必要な発話だけを開きながら流れを確認できる。

#### 受け入れ基準
1. 会話 transcript が表示可能な発話を表示するとき、Copilot History Application は各発話に本文の表示 / 非表示を切り替える操作を提供する。
2. 利用者が表示中の発話を非表示にしたとき、Copilot History Application はその発話の本文、コードブロック、tool call 補助情報、発話内 issue 詳細を折りたたむ。
3. 利用者が非表示の発話を再表示したとき、Copilot History Application はその発話の本文、コードブロック、tool call 補助情報、発話内 issue 詳細を再び確認できるようにする。
4. 発話が非表示の間、Copilot History Application は発話番号、role、日時、degraded 状態を確認できる状態に保つ。
5. Copilot History Application は発話の表示 / 非表示状態をセッション外へ永続化しない。

### 要件4: 長い tool call 表示の初期折りたたみ
**目的:** 会話本文を優先して読みたい利用者として、長い tool call arguments が初期表示で会話を圧迫しないようにしたい。そうすることで、User / Assistant のやり取りを先に追える。

#### 受け入れ基準
1. tool call 補助情報が `skill-context` を示すとき、Copilot History Application はその arguments preview を初期状態で折りたたんで表示する。
2. tool call 補助情報が複数行の arguments preview を持つとき、Copilot History Application はその arguments preview を初期状態で折りたたんで表示する。
3. tool call 補助情報が truncated として示されるとき、Copilot History Application は truncated であることを識別できる表示を維持したまま、arguments preview を初期状態で折りたたんで表示する。
4. 利用者が折りたたまれた tool call を展開したとき、Copilot History Application は tool 名、status、truncated 状態、arguments preview を確認できるようにする。
5. tool call arguments が折りたたまれている間、Copilot History Application は tool call の存在と tool 名を会話本文とは区別して確認できるようにする。

### 要件5: 一覧へ戻ったときの即時再利用
**目的:** 複数セッションを見比べる利用者として、詳細から一覧へ戻ったときに直前の一覧をすぐ見たい。そうすることで、セッション間の確認を待ち時間で中断されにくくできる。

#### 受け入れ基準
1. 利用者がセッション一覧を一度表示したあと詳細画面へ移動し、同じ閲覧フローで一覧へ戻ったとき、Copilot History Application は直前に成功表示した一覧データを即時に再表示する。
2. 直前の一覧データを即時再表示している間、Copilot History Application は利用者が一覧のセッションを選択できる状態を保つ。
3. 一覧データがまだ一度も成功取得されていないとき、Copilot History Application は既存の読み込み中表示を行う。
4. 直前の一覧取得が空状態だったとき、Copilot History Application は詳細画面から一覧へ戻った場合でも空状態を即時に再表示できる。
5. Copilot History Application は一覧再利用によって検索、絞り込み、並び替え、自動更新、または手動再読み込みの新しい操作を追加しない。

### 要件6: 既存契約と read-only 境界の維持
**目的:** 履歴参照アプリの利用者として、読みやすさの改善で既存の履歴表示が壊れないことを望む。そうすることで、current / legacy session をこれまで通り安全に参照できる。

#### 受け入れ基準
1. Copilot History Application はこの feature によって履歴の編集、削除、送信、共有の操作を提供しない。
2. Copilot History Application はこの feature によって backend が返すセッション一覧・詳細データの契約変更を必須にしない。
3. current session または legacy session が表示対象になるとき、Copilot History Application は既存の会話本文、activity、degraded、issue 情報を引き続き確認できるようにする。
4. tool call 補助情報または発話本文が欠落しているとき、Copilot History Application は表示可能な他の発話情報の閲覧を妨げない。
5. Copilot History Application はこの feature でタイムゾーン選択、折りたたみ状態の永続化、raw payload 専用 viewer を提供しない。
