# Implementation Plan

- [x] 1. JST 日時表示の基礎契約を整える
- [x] 1.1 日時表示を JST として識別できる成功時表示に統一する
  - 欠落値は既存の欠落表示を維持し、JST 変換済みの日時として見えない状態にする
  - 解釈不能な値は成功した JST 変換結果と同じ形式や suffix で表示しない
  - UTC timestamp が Asia/Tokyo の日時に変換され、画面上で JST と分かる文字列として表示される
  - null、invalid、UTC から JST への変換を固定する単体テストが通る
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_
  - _Boundary: formatTimestamp_

- [x] 1.2 一覧、詳細、会話、activity の日時表示が共通の JST 契約に乗っていることを確認する
  - 一覧 card、詳細 header、会話発話、activity timeline が個別の timezone 判定を持たず同じ表示規則を使う
  - 欠落または invalid な日時が含まれても、表示可能なセッションや発話の閲覧を妨げない
  - 関連する既存表示テストまたは追加テストで、各表示面に JST 表示が出ることを確認できる
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 6.3, 6.4_
  - _Boundary: Existing session display components_

- [x] 2. 会話本文と tool call の表示モデルを拡張する
- [x] 2.1 (P) tool call arguments の初期折りたたみ方針を表示モデルに追加する
  - `skill-context`、複数行 arguments、truncated arguments が初期折りたたみ対象として判定される
  - 短い単一行 arguments は tool 名、status、preview を保持し、必要以上に初期折りたたみされない
  - arguments が折りたたみ対象でも、tool の存在、tool 名、status、truncated 状態は表示モデルから失われない
  - collapse policy の分岐を固定する単体テストが通る
  - _Requirements: 4.1, 4.2, 4.3, 4.5, 6.4_
  - _Boundary: conversationContent_

- [x] 2.2 (P) User / Assistant 発話を badge 以外でも識別できる視覚状態にする
  - user と assistant の発話 card が背景、枠線、または accent の違いで比較できる
  - degraded 状態や issue 情報がある発話でも、role の識別と partial 表示が同時に残る
  - 本文、code block、tool call 補助情報が role styling に埋もれず読める配色と余白になる
  - component test で user / assistant が badge 以外の識別可能な marker または class を持つことを確認できる
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 6.3_
  - _Boundary: ConversationTranscript_

- [x] 2.3 (P) 一覧の直近成功状態を同一閲覧 flow で再利用できるようにする
  - 成功した一覧または空状態だけが直近 snapshot として保持される
  - 初回未取得時は既存 loading が表示され、error は再利用 snapshot として保存されない
  - 詳細から一覧へ戻る再 mount 相当の状況で、直前の一覧または空状態が即時に返る
  - hook test で success reuse、empty reuse、初回 loading、error 非 reuse を確認できる
  - _Requirements: 5.1, 5.3, 5.4, 5.5, 6.2_
  - _Boundary: useSessionIndex_

- [x] 3. 表示モデルを既存 UI に統合する
- [x] 3.1 tool call arguments の disclosure UI を会話と activity の共有表示に統合する
  - 折りたたみ中も tool call の visual block、tool 名、status、truncated badge が本文とは別に表示される
  - 展開後は同じ tool block 内で arguments preview、tool 名、status、truncated 状態を確認できる
  - arguments preview がない tool call では不要な展開操作を出さず、tool の存在だけを表示する
  - 初期折りたたみ、展開後表示、truncated 表示維持を component test で確認できる
  - _Depends: 2.1_
  - _Requirements: 2.5, 3.2, 3.3, 4.1, 4.2, 4.3, 4.4, 4.5, 6.4_
  - _Boundary: TimelineContent_

- [x] 3.2 発話単位の表示 / 非表示操作を会話 transcript に追加する
  - 各発話に本文の表示 / 非表示を切り替える操作があり、状態は component lifetime 内だけで保持される
  - 非表示時は本文、code block、tool call 補助情報、発話内 issue 詳細が DOM 上から隠れる
  - 非表示時も発話番号、role、JST 日時、degraded 状態は確認できる
  - 再表示時に本文、code block、tool call 補助情報、発話内 issue 詳細が再び確認できる
  - hide/show と metadata 維持を component test で確認できる
  - _Depends: 1.1, 2.2, 3.1_
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 6.3, 6.4_
  - _Boundary: ConversationTranscript_

- [x] 3.3 cached 一覧状態を一覧画面の既存導線に接続する
  - cached success を表示している間も、既存の session link 群から詳細へ移動できる
  - cached empty の場合も、詳細から戻った直後に空状態が即時に表示される
  - 一覧再利用のために検索、絞り込み、並び替え、自動更新、手動再読み込みの新操作を追加しない
  - page-level test で cached success state の一覧 link が選択可能であることを確認できる
  - _Depends: 2.3_
  - _Requirements: 5.1, 5.2, 5.4, 5.5, 6.1, 6.2_
  - _Boundary: SessionIndexPage, SessionList_

- [x] 4. read-only 境界と current / legacy 表示の回帰を検証する
- [x] 4.1 current / legacy session の詳細表示が既存情報を維持することを確認する
  - current session と legacy session の本文、activity、degraded、issue 情報が引き続き確認できる
  - tool call または本文が欠落している発話があっても、他の発話や activity の閲覧が妨げられない
  - 詳細表示の regression test で、会話本文、activity、degraded、issue 情報が残っていることを確認できる
  - _Depends: 3.1, 3.2_
  - _Requirements: 6.2, 6.3, 6.4_
  - _Boundary: SessionDetailPage_

- [x] 4.2 feature 全体が read-only と非永続 UI state の境界を越えていないことを確認する
  - 編集、削除、送信、共有の操作が追加されていない
  - タイムゾーン選択、折りたたみ状態の永続化、raw payload 専用 viewer が追加されていない
  - backend list / detail response shape の変更を必須にしないまま frontend tests が通る
  - frontend の lint と test で、この feature の表示改善が既存契約内に収まることを確認できる
  - _Depends: 3.1, 3.2, 3.3, 4.1_
  - _Requirements: 3.5, 5.5, 6.1, 6.2, 6.5_
  - _Boundary: Frontend validation_
