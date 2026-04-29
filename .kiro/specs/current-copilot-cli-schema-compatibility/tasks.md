# 実装タスク

- [x] 1. Foundation: current / legacy 共通 contract と検証 fixture を整える
- [x] 1.1 current schema の代表 fixture と degraded シナリオを整備する
  - 会話本文あり、空 assistant tool request、system message、tool execution、hook、skill、unknown event、invalid JSONL line、workspace-only session を再現できる fixture を用意する。
  - mixed current / legacy の一覧順と detail 表示を確認できる fixture を揃える。
  - 完了時には backend specs から正常系、workspace-only、partial degradation、unknown shape を同じ fixture 群で参照できる。
  - _Requirements: 1.1, 1.3, 1.4, 3.1, 5.4, 8.2_

- [x] 1.2 backend の共通 session / event / issue contract を拡張する
  - session が `complete`、`workspace_only`、`degraded` の状態を保持できるようにする。
  - conversation entry、activity entry、tool request summary、raw availability、event issue の責務を backend domain contract として表現する。
  - workspace-only 専用 issue と既存 partial / unknown issue を区別できる状態にする。
  - 完了時には reader、normalizer、projector、presenter が同じ contract を入力と出力に使える。
  - _Requirements: 3.4, 4.2, 4.3, 5.4, 7.3, 8.1, 8.2, 8.3_

- [x] 1.3 legacy session の会話回帰基準を固定する
  - legacy の user / assistant 会話が current 対応後も conversation projection に入る基準を確認する。
  - legacy の degraded issue と session state が current の新しい source state と衝突しないようにする。
  - 完了時には legacy session の会話数、preview、detail 表示が current 互換追加前と同等であることを検証できる。
  - _Requirements: 1.5, 5.5, 6.4, 8.5_

- [x] 2. Core: current raw files を補正済み normalized session に変換する
- [x] 2.1 current / legacy event を canonical taxonomy へ分類する
  - current の user / assistant / system message から role、content、timestamp、tool request を抽出する。
  - assistant turn、tool execution、hook、skill を internal detail として分類し、未対応 shape を unknown activity へ残す。
  - 空 content の assistant tool request は event として保持しつつ、主会話 entry にならない入力として扱える。
  - 完了時には current / legacy の message、detail、unknown が同じ normalized event shape で返る。
  - _Requirements: 1.1, 1.3, 1.4, 3.1, 4.4, 8.1, 8.2_

- [x] 2.2 current reader で部分成功、更新時刻補正、source state を扱う
  - event timestamp、events file mtime、workspace metadata の順で current session の更新時刻を決める。
  - events missing、events unreadable、workspace parse failure、JSONL parse failure、unknown / partial event の違いを issue と source state に反映する。
  - 完了時には workspace-only は通常会話 session と区別され、invalid line があっても読めた event は sequence 順に残る。
  - _Requirements: 1.2, 5.4, 6.1, 6.2, 6.3, 8.2, 8.4_

- [x] 2.3 tool request summary の redaction と partial 保持を実装する
  - assistant の本文付き発話に付く tool request から tool 名と入力要約を作る。
  - secret-like key を redact し、長い入力は切り詰め、欠損した tool 情報は partial として保持する。
  - 完了時には tool request の欠損や truncation が会話本文の表示を阻害せず、partial issue と summary で確認できる。
  - _Requirements: 4.1, 4.2, 4.3_

- [x] 3. Core: conversation / activity projection を作る
- [x] 3.1 (P) user / assistant の主会話 transcript を派生する
  - 非空本文を持つ user / assistant message だけを source sequence 順に conversation entry へ写す。
  - system、detail、unknown、空 assistant tool request を主会話から除外する。
  - conversation が空の場合に利用者向け empty reason を返せるようにする。
  - 完了時には current / legacy の主会話数、entry 順、tool 付帯情報、空状態が projection 単体で確認できる。
  - _Depends: 2.1, 2.3_
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.2, 3.2, 3.5, 4.1_
  - _Boundary: ConversationProjector_

- [x] 3.2 (P) internal activity と unknown traceability を派生する
  - system message、assistant turn、tool execution、hook、skill、unknown event を conversation と別の activity entry にする。
  - raw payload を通常 detail に入れなくても、sequence、raw type、source path、issue、raw availability で追跡できるようにする。
  - 完了時には activity が主会話本文と混在せず、unknown / partial event の調査に必要な参照情報を保持する。
  - _Depends: 2.1_
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 4.4, 4.5, 7.3, 7.4, 8.3_
  - _Boundary: ActivityProjector_

- [x] 3.3 session list 用 conversation summary を派生する
  - session ごとの会話有無、会話数、preview、activity count を conversation / activity projection から作る。
  - preview は user / assistant の本文だけから生成し、internal activity を preview 本文に使わない。
  - 完了時には current / legacy / workspace-only / degraded session の一覧識別情報が同じ summary contract で返る。
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 6.4_

- [x] 4. API: index / detail response を conversation-first contract に接続する
- [x] 4.1 session index response に会話 summary と補正済み状態を出す
  - 一覧の sort が補正済み updated_at を使い、current / legacy 混在時も利用者が時刻の意味を推測しなくてよいようにする。
  - conversation summary、source state、degraded issue を一覧 DTO に含める。
  - 完了時には一覧から会話あり session、workspace-only session、degraded session を開く前に判別できる。
  - _Depends: 2.2, 3.3_
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 6.1, 6.2, 6.3, 6.4_

- [x] 4.2 session detail response を conversation / activity / timeline に分離する
  - detail DTO に conversation、activity、timeline、raw_included、session issue、event issue を含める。
  - 通常 detail では raw payload を `nil` にし、classification と degraded 判断に必要な情報だけを返す。
  - 完了時には detail endpoint の初期 response が raw payload の量に依存せず、conversation first 表示に必要な情報を持つ。
  - _Depends: 3.1, 3.2_
  - _Requirements: 2.1, 2.3, 2.4, 7.1, 7.3, 8.1, 8.3, 8.4_

- [x] 4.3 raw 明示要求を controller から presenter へ伝搬する
  - `include_raw=true` のときだけ raw payload を detail response に入れ、それ以外の値や未指定は通常 detail と同じ扱いにする。
  - raw inclusion policy は query ではなく controller と presenter の API 境界に閉じる。
  - 完了時には通常 detail と raw 付き detail が同じ top-level shape を保ち、raw_included で違いを判別できる。
  - _Depends: 4.2_
  - _Requirements: 7.2, 7.4_

- [x] 5. Frontend: typed API と presentation helper を conversation-first に更新する
- [x] 5.1 frontend の session API 型と raw 明示取得 client を更新する
  - conversation、activity、timeline、conversation summary、source state、raw_included を型として表現する。
  - 通常 detail と raw 明示 detail を typed client から区別して取得できるようにする。
  - 完了時には frontend が source format や raw payload shape を直接判定せず、API contract だけで session data を扱える。
  - _Depends: 4.1, 4.2, 4.3_
  - _Requirements: 2.3, 2.4, 5.1, 7.2, 7.3_

- [x] 5.2 (P) conversation content helper で本文と tool hint を読解可能に整形する
  - 改行、コードブロック、長い本文を保持して conversation entry を表示用 block にする。
  - assistant 発話内の tool request を本文とは別の付帯情報として表示できる model にする。
  - 完了時には user / assistant の本文と tool hint が順序を崩さず、同じ helper から生成される。
  - _Depends: 5.1_
  - _Requirements: 2.5, 4.1, 4.2, 4.3_
  - _Boundary: Conversation presentation helper_

- [x] 5.3 (P) activity / timeline helper で internal activity と fallback 表示を分離する
  - activity entry の category、summary、mapping status、issue を message と混同しない表示 model にする。
  - conversation が未提供の response でも既存 timeline から同じ抽出条件で fallback 表示できるようにする。
  - 完了時には internal activity、unknown、partial event が主会話本文とは別の secondary 表示用 model になる。
  - _Depends: 5.1_
  - _Requirements: 2.4, 3.1, 3.2, 3.3, 3.4, 4.4, 8.3_
  - _Boundary: Activity timeline presentation helper_

- [x] 6. Frontend: session list と detail UI を conversation-first へ接続する
- [x] 6.1 SessionSummaryCard で会話あり session を選びやすくする
  - 会話有無、会話数、preview、source state、degraded 状態、補正済み更新時刻を一覧カードで表示する。
  - workspace-only session は通常会話 session と区別できる見え方にする。
  - 完了時には session list から会話本文を持つ session と metadata-only session を判別して選べる。
  - _Depends: 5.1_
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 6.4_

- [x] 6.2 ConversationTranscript を detail 画面の主表示にする
  - detail 画面で user / assistant の会話を最初の主 content section として表示する。
  - conversation が空の場合は表示できる会話本文がないことを明示し、activity や raw payload の量で主表示を埋めない。
  - 完了時には detail 画面を開いた直後に会話履歴または会話なし状態が読める。
  - _Depends: 5.2_
  - _Requirements: 2.1, 2.2, 2.3, 2.5, 7.1_

- [x] 6.3 ActivityTimeline と issue 表示を secondary section として接続する
  - internal activity、unknown event、partial mapping、event issue を主会話の下で控えめに確認できるようにする。
  - raw 明示 action 後だけ raw payload を詳細として参照できる状態にする。
  - 完了時には利用者が読める範囲と信頼できない範囲を detail 画面上で判断できる。
  - _Depends: 5.3, 6.2_
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 4.4, 7.2, 7.4, 8.3_

- [x] 6.4 session detail hook で通常 detail と raw 明示 detail の状態遷移を扱う
  - 初回は通常 detail を取得し、raw 明示 action が呼ばれた場合だけ raw 付き detail を再取得する。
  - loading、error、not found、raw included の状態が既存 detail 画面の制御と矛盾しないようにする。
  - 完了時には raw 明示 action 後も同じ detail page で conversation / activity / timeline が維持される。
  - _Depends: 5.1, 6.3_
  - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [ ] 7. Validation: backend / frontend / integration 回帰を固定する
- [ ] 7.1 backend specs で normalizer、reader、projection の contract を固定する
  - current message、empty assistant tool request、system/detail/unknown、tool redaction、partial tool、invalid JSONL、workspace-only、updated_at fallback を検証する。
  - legacy session が current 互換追加後も conversation projection と source state で後退しないことを検証する。
  - 完了時には backend unit specs が current / legacy の会話抽出、activity 分離、degraded 可視化を失敗で検知できる。
  - _Depends: 2.1, 2.2, 2.3, 3.1, 3.2, 3.3_
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 3.1, 3.4, 4.2, 4.3, 5.4, 6.1, 6.2, 6.3, 8.1, 8.2, 8.4, 8.5_

- [ ] 7.2 backend API specs で index / detail / raw inclusion を固定する
  - current schema fixture から conversation、activity、timeline、issues、raw_included=false が返ることを確認する。
  - `include_raw=true` だけ raw payload が入り、未指定または `true` 以外では通常 detail になることを確認する。
  - mixed current / legacy で sort、conversation summary、workspace-only、degraded state が一貫することを確認する。
  - 完了時には API response contract の破壊が request / presenter specs で検知できる。
  - _Depends: 4.1, 4.2, 4.3_
  - _Requirements: 2.1, 2.3, 5.1, 5.2, 5.3, 5.5, 6.4, 7.1, 7.2, 7.3, 7.4, 8.3, 8.4_

- [ ] 7.3 frontend tests で conversation-first 表示と activity 分離を固定する
  - detail 画面で user / assistant conversation が最初に表示され、activity が主会話に混在しないことを確認する。
  - 会話なし状態、tool hint、code block、partial issue、unknown activity、raw 明示 action を確認する。
  - 一覧カードで会話有無、会話数、preview、source state、updated_at、degraded 状態を確認する。
  - 完了時には current / legacy の両 session が同じ frontend flow で読めることがテストで固定される。
  - _Depends: 6.1, 6.2, 6.3, 6.4_
  - _Requirements: 2.1, 2.2, 2.3, 2.5, 3.2, 3.3, 4.1, 4.2, 4.4, 5.1, 5.2, 5.3, 5.4, 6.4, 7.1, 7.2, 8.3, 8.5_

- [ ] 7.4 Docker Compose 経由で backend / frontend の既存検証を通す
  - backend は RSpec / CI 導線で current / legacy 互換と raw 分離の specs を実行する。
  - frontend は Vitest / build 導線で conversation-first UI と API 型の整合を確認する。
  - 完了時には既存の Compose ベース検証で backend と frontend の両方が成功し、実装タスク全体の完了判断に使える。
  - _Depends: 7.1, 7.2, 7.3_
  - _Requirements: 1.5, 5.5, 8.5_
