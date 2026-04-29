# Implementation Plan

- [ ] 1. 実装前提となる検証データと表示ケースを固める
- [x] 1.1 current 形式のモデル抽出と tool-only 会話を検証できる backend 側の fixture を用意する
  - モデル値を持つ current 形式、モデル値を持たない current 形式、tool call だけを持つ user / assistant event を含む履歴ケースを用意する
  - 空文字、空白、非文字列のモデル候補が採用されないことを確認できる入力を含める
  - 完了時には backend の reader / projector / request spec から同じ fixture を参照して、モデル抽出と tool-only 会話の期待値を検証できる
  - _Requirements: 3.1, 3.3, 3.5, 4.3, 5.2, 5.4, 5.5_

- [x] 1.2 frontend の一覧、詳細、tool、activity 表示を検証できる session データを整える
  - work context と model があるケース、欠損するケース、metadata-only / workspace-only / degraded の例外ケースを揃える
  - session issue、発話近傍 issue、tool call、skill-context、activity を別々に検証できる入力を揃える
  - 完了時には UI テストが保存形式ではなく実データの有無に基づく表示差分を assertion できる
  - _Requirements: 1.2, 1.3, 2.1, 2.2, 2.3, 2.4, 2.5, 3.2, 3.4, 4.2, 4.3, 5.5, 6.2, 6.3_

- [x] 2. backend の current metadata と会話投影を既存 contract に接続する
- [x] 2.1 current 形式の保存済み event から確認できるモデル名を session metadata として抽出する
  - 確認済みの model 候補を優先順に評価し、同一優先度では後続 event の非空値を採用する
  - model が存在しない、空、または文字列でない場合は推測値や placeholder を作らず欠損として扱う
  - 完了時には current 形式の session が既存の selected model contract を通じてモデル名または null を返す
  - _Requirements: 3.1, 3.3, 3.5_
  - _Boundary: CurrentSessionReader_

- [x] 2.2 (P) content が空でも tool call を持つ発話を会話 entry として残す
  - user / assistant の message は本文または tool call のどちらかがある場合に会話へ投影する
  - 本文も tool call もない空発話は従来どおり表示対象から外す
  - 完了時には skill-context などの tool-only event が詳細 response の会話順序内で確認でき、同じ発話の issue も保持される
  - _Requirements: 4.3, 4.4, 5.2, 5.4, 5.5_
  - _Boundary: ConversationProjector_

- [x] 2.3 backend の index / detail response が既存 field のまま新しい値を返すことを固定する
  - selected model は current / legacy 共通の nullable metadata として index と detail の両方に出す
  - tool-only 会話 entry と発話近傍 issue が detail response に到達することを確認する
  - 完了時には API response shape を増やさず、既存 presenter contract で一覧と詳細の判断材料を返せる
  - _Depends: 2.1, 2.2_
  - _Requirements: 3.1, 3.2, 3.3, 3.5, 4.3, 5.2, 5.5_
  - _Boundary: API presenters_

- [x] 3. frontend の表示 policy を helper 境界に集約する
- [x] 3.1 値がある metadata だけを表示項目に変換する
  - work context は利用可能な候補から読みやすい表示値を作り、全候補が欠損する場合は項目を生成しない
  - selected model は trim 後の非空文字列だけを表示対象にし、不明 placeholder は生成しない
  - 完了時には一覧と詳細の component が metadata item の有無だけで空領域を出すかどうかを判断できる
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 3.2, 3.4_
  - _Boundary: metadata display helpers_

- [x] 3.2 (P) tool arguments の初期折りたたみ方針を会話表示用 helper に集約する
  - arguments preview を持つ tool call は短さに関係なく初期 collapsed にする
  - skill-context と truncated / partial の状態を、展開前の見出しで識別できる表示情報として保持する
  - 完了時には tool 名は初期表示で読めるが、arguments の詳細は明示操作まで本文の流れを押し下げない
  - _Requirements: 5.1, 5.2, 5.3, 5.4_
  - _Boundary: conversationContent_

- [x] 4. 一覧 card と詳細 header から常設ノイズと不明値を除く
- [x] 4.1 セッション一覧 card を例外シグナルと実値 metadata 優先の表示にする
  - 通常状態だけを示す会話あり、正常、complete、内部 activity 数の主要表示を既定表示から外す
  - 会話本文なし、workspace-only、degraded、読取制約は一覧上で通常 session より目立つ例外として識別できるようにする
  - 完了時には current / legacy の通常 session が同じ基準で並び、metadata がない card には空の metadata 領域が残らない
  - _Depends: 3.1_
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.3, 2.4, 2.5, 3.2, 3.4_
  - _Boundary: SessionSummaryCard_

- [x] 4.2 (P) セッション詳細 header を値がある metadata だけの表示にする
  - work context と model は実値がある場合だけ表示し、不明 placeholder や placeholder だけの領域は出さない
  - degraded や読取制約の事実は header で確認できる状態を保つ
  - 完了時には詳細 header が read-only のまま、metadata 欠損時も余白だけの領域を残さない
  - _Depends: 3.1_
  - _Requirements: 2.2, 2.3, 2.4, 2.5, 3.2, 3.4, 4.5_
  - _Boundary: SessionDetailHeader_

- [ ] 5. 詳細画面を conversation-first の折りたたみ表示へ組み替える
- [ ] 5.1 session issue と activity の共通 disclosure を用意する
  - 初期状態は collapsed とし、見出しには件数と警告状態を表示する
  - 展開時だけ body を描画し、開閉状態は component lifetime の local state に閉じる
  - 完了時には session issue と activity が会話本文の前に展開表示されず、存在だけは必要時に確認できる
  - _Requirements: 4.1, 4.2, 6.1, 6.2_
  - _Boundary: DisclosureSection_

- [ ] 5.2 (P) tool block を本文と区別しつつ arguments を初期折りたたみにする
  - collapsed 状態でも tool 名、partial / truncated の状態、展開操作を本文とは別の block として表示する
  - 展開後は tool 名と補助情報を同じ block 内で読み取れるようにする
  - 完了時には skill-context を含む tool arguments が初期表示で展開されず、明示操作でだけ詳細を確認できる
  - _Depends: 3.2_
  - _Requirements: 5.1, 5.2, 5.3, 5.4_
  - _Boundary: TimelineContent_

- [ ] 5.3 会話 transcript で tool-only 発話と発話近傍 issue を読める状態にする
  - content が空で tool call だけを持つ発話では、空本文 placeholder を増やさず tool block と発話 metadata を表示する
  - 発話単位の issue は本文と tool block の近くに表示し、tool arguments の collapsed 状態で完全に隠れないようにする
  - 完了時には会話 entry が表示されている限り、その entry の issue と tool の存在を同じ発話内で確認できる
  - _Depends: 5.2_
  - _Requirements: 4.3, 4.4, 5.5_
  - _Boundary: ConversationTranscript_

- [ ] 5.4 詳細 page の初期表示順を会話本文優先にする
  - 会話本文を session issue disclosure より先に描画し、session issue は collapsed summary として後続配置にする
  - activity がある場合だけ collapsed summary を表示し、ない場合は空 section を表示しない
  - activity 展開時には内容、時刻、状態、issue、既存 raw action を会話本文と区別して確認できる
  - 完了時には詳細を開いた直後に会話本文を読め、編集・削除・共有・永続 disclosure などの操作は追加されない
  - _Depends: 5.1, 5.3_
  - _Requirements: 4.1, 4.2, 4.4, 4.5, 6.1, 6.2, 6.3, 6.4, 6.5_
  - _Boundary: SessionDetailPage, ActivityTimeline_

- [ ] 6. backend / frontend の回帰テストで表示契約を固定する
- [ ] 6.1 backend reader と projector の単体テストを追加する
  - current model の優先候補、欠損、空値、非文字列値の扱いを検証する
  - tool-only message が会話 entry に残り、空 message は除外されることを検証する
  - 完了時には backend の正規化層だけでモデル抽出と tool-only 会話投影の境界条件を再現できる
  - _Requirements: 3.1, 3.3, 3.5, 4.3, 5.2, 5.4, 5.5_

- [ ] 6.2 backend request と presenter の結合テストを追加する
  - index と detail が current session の selected model を既存 field で返すことを検証する
  - model がない current session は null のままで、推測値を返さないことを検証する
  - 完了時には API response shape を変更せず、一覧と詳細の表示に必要な値だけが返ることを request spec で確認できる
  - _Requirements: 3.1, 3.2, 3.3, 3.5, 4.3, 5.2_

- [ ] 6.3 frontend の一覧と詳細 header の表示テストを追加する
  - 通常 session に会話あり、正常、complete、内部 activity 数の主要表示が出ないことを検証する
  - work context と model の不明 placeholder が表示されず、実値だけが metadata として表示されることを検証する
  - 完了時には current / legacy の通常 session と例外 session の一覧表示差分を UI テストで固定できる
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.4, 2.5, 3.2, 3.4_

- [ ] 6.4 frontend の会話、tool、issue、activity disclosure の表示テストを追加する
  - 詳細初期表示で会話が session issue より先に読め、session issue と activity は明示操作で展開できることを検証する
  - tool arguments は初期 collapsed で、展開後に tool 名と補助情報を同じ block 内で読めることを検証する
  - 完了時には tool arguments が collapsed のままでも発話近傍 issue が表示され、activity の内容・時刻・状態・issue も展開後に確認できる
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 5.1, 5.2, 5.3, 5.4, 5.5, 6.1, 6.2, 6.3, 6.4, 6.5_

- [ ] 6.5 read-only 境界と既存品質コマンドで最終確認する
  - backend と frontend の既存 test / lint / build 導線を実行し、追加した contract が破綻していないことを確認する
  - UI に編集、削除、送信、共有、専用 raw viewer、折りたたみ永続化の新規操作が増えていないことを確認する
  - 完了時には既存品質コマンドが成功し、仕様範囲外の操作追加なしで会話優先表示を検証済みにできる
  - _Requirements: 4.5_
