# 実装計画

- [x] 1. 履歴同期 API contract を frontend client に追加する
- [x] 1.1 同期 API の success と failure を既存の typed result と同じ形で扱えるようにする
  - 履歴同期の成功 payload と件数情報を frontend の型安全な結果として受け取れるようにする
  - 同期 request は body なしの明示的な POST として送信され、既存の一覧・詳細取得は GET のまま動く
  - 409 conflict、backend failure、network failure、API base URL 設定不備が、status と error code を失わずに呼び出し側へ返る
  - 完了時には同期 hook が conflict と通常失敗を判定できる observable な result が得られる
  - _Requirements: 1.2, 2.1, 4.1, 4.2, 4.3, 4.5_
  - _Boundary: SessionApiClient_

- [x] 1.2 同期 API client の契約をテストで固定する
  - success payload が同期 run と counts を保持したまま返ることを確認する
  - conflict、root failure、backend failure、network failure、config failure の分類を確認する
  - 一覧・詳細 API の既存 request と error normalization が変わっていないことを確認する
  - 完了時には同期 API と既存 session API の client-level regression が自動テストで観測できる
  - _Requirements: 1.2, 4.1, 4.2, 4.3, 5.1_
  - _Boundary: SessionApiClient_

- [x] 2. セッション一覧の明示 reload contract を追加する
- [x] 2.1 一覧取得 state から同期後に再取得できる settled outcome を返す
  - 初回表示の loading、empty、success、error の既存状態を保ったまま、利用者操作後に一覧を再取得できるようにする
  - reload 中は既に表示できている一覧または空状態を不必要に消さず、refreshing 状態だけを追加で識別できる
  - reload の結果は success、empty、error のいずれかとして呼び出し側へ返り、backend が返した session order は維持される
  - 完了時には同期成功後の一覧再取得結果を page-local orchestration から判定できる
  - _Requirements: 2.1, 2.2, 2.4, 3.1, 5.2_
  - _Boundary: useSessionIndex_

- [x] 2.2 reload 中の snapshot 維持と settled outcome をテストで固定する
  - reload success で新しい session list と meta が返ることを確認する
  - reload empty が loading や error と区別されることを確認する
  - reload error が既存一覧を最新化済みとして扱わず、呼び出し側へ error outcome を返すことを確認する
  - stale response と unmount/abort が画面 state を上書きしないことを確認する
  - 完了時には明示 reload の success、empty、error、abort の挙動が hook test で観測できる
  - _Requirements: 2.1, 2.2, 2.4, 3.1, 5.2_
  - _Boundary: useSessionIndex_

- [x] 3. 履歴同期の page-local state machine を実装する
- [x] 3.1 明示操作から同期を開始し、成功後 reload と失敗分類を管理する
  - start が呼ばれるまで同期 request を開始せず、自動同期を行わない
  - syncing 中の再実行は新しい request を出さず、UI が disabled にできる状態を返す
  - 同期成功後は一覧 reload を一度だけ実行し、sessions あり、empty、refresh error を別状態へ分類する
  - 409 conflict は既に同期中の可能性として、network/config/backend failure は同期失敗として区別する
  - terminal state からの再実行は新しい同期 request として扱われる
  - 完了時には idle、syncing、synced_with_sessions、synced_empty、refresh_error、conflict、sync_error が page から観測できる
  - _Requirements: 1.2, 1.3, 1.4, 1.5, 2.1, 2.3, 2.4, 3.3, 3.4, 3.5, 4.1, 4.2, 4.3, 4.4, 4.5_
  - _Boundary: useHistorySync_

- [x] 3.2 同期 state machine の主要遷移をテストで固定する
  - 初期状態では同期 request が発行されないことを確認する
  - 同期中の二重実行抑止と、失敗後の再試行で新しい request が発行されることを確認する
  - success 後の reload success、reload empty、reload error が別状態になることを確認する
  - conflict と network/config/backend failure が別表示に渡せる state になることを確認する
  - 完了時には同期 lifecycle と reload 呼び出し順序が hook test で観測できる
  - _Requirements: 1.2, 1.3, 1.4, 1.5, 2.1, 2.3, 2.4, 3.3, 3.4, 3.5, 4.1, 4.2, 4.3, 4.4, 4.5_
  - _Boundary: useHistorySync_

- [ ] 4. 同期操作と状態表示の presentation component を追加する
- [ ] 4.1 既存 status panel に action を載せられる表示余地を追加する
  - loading、empty、error の既存表示文脈を壊さず、必要な場合だけ action を表示できる
  - action がない既存利用箇所では見た目とアクセシビリティ上の意味が変わらない
  - 完了時には空状態に primary action を置ける一方で、既存 loading/error panel の表示回帰がない
  - _Requirements: 3.1, 3.2, 5.1_
  - _Boundary: StatusPanel_

- [ ] 4.2 (P) 一覧上部の履歴最新化操作を表示する
  - 一覧画面の見出し付近に利用者が明示的に同期を開始できる操作を表示する
  - syncing 中は操作を disabled にし、同期中であることが button 表示から分かる
  - terminal state 後は再試行できる通常操作へ戻る
  - この task は 3.1 の props/state contract を使う presentation 境界に閉じ、hook や API client の挙動は変更しない
  - 完了時には click または keyboard activation の user event でのみ同期 callback が呼ばれる
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_
  - _Boundary: HistorySyncControl_
  - _Depends: 3.1_

- [ ] 4.3 (P) 同期結果を成功一覧と誤認しない status banner として表示する
  - 同期完了と一覧再取得完了を、保存件数と劣化件数だけの最小情報で表示する
  - 同期後も empty の場合は失敗ではない空状態として表示する
  - refresh error、conflict、sync error をそれぞれ異なる失敗・保留状態として表示する
  - この task は 3.1 の state contract を表示へ変換する presentation 境界に閉じ、同期実行や一覧 reload は変更しない
  - 完了時には同期成功、同期後空、再取得失敗、conflict、同期失敗を画面文言と variant で判別できる
  - _Requirements: 1.3, 2.3, 2.4, 2.5, 3.5, 4.1, 4.2, 4.3, 4.4_
  - _Boundary: HistorySyncStatus_
  - _Depends: 3.1_

- [ ] 4.4 空状態から同じ同期要求を開始できる primary action を表示する
  - セッションが空である状態を loading/error と区別して表示する
  - 空状態内の履歴取り込み操作は一覧上部と同じ同期 callback を使う
  - syncing 中は空状態 action も disabled になり、二重実行できない
  - synced_empty の場合は取り込み後も表示対象がないことを失敗と区別して補足する
  - 完了時には初回空状態から同期を開始でき、同期中と同期後空状態が見分けられる
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_
  - _Boundary: SessionEmptyState_
  - _Depends: 3.1, 4.1_

- [ ] 4.5 presentation component の表示契約をテストで固定する
  - 同期 control の通常、syncing、terminal 後再試行状態を確認する
  - status banner の success、empty、refresh error、conflict、sync error 表示を確認する
  - empty state の primary action、disabled、synced_empty 補足を確認する
  - status panel の action なし既存表示と action あり表示を確認する
  - 完了時には同期 UI の表示差分と callback 発火条件が component test で観測できる
  - _Requirements: 1.1, 1.3, 1.4, 2.3, 2.4, 2.5, 3.1, 3.2, 3.4, 3.5, 4.1, 4.2, 4.3_
  - _Boundary: HistorySyncControl, HistorySyncStatus, SessionEmptyState, StatusPanel_

- [ ] 5. 一覧 page へ同期 UI と既存閲覧体験を統合する
- [ ] 5.1 同期 control、status、empty action、既存 list rendering を同じ一覧 route で合成する
  - 一覧 page の見出し付近に同期 control を表示し、空状態には同じ同期要求を開始する primary action を表示する
  - 同期成功後は reload outcome に応じて既存 session list または空状態を表示し、完了状態も併せて示す
  - 初回一覧取得 error と同期 error は混同せず、別の状態として表示する
  - 詳細画面、検索、日付 filter、自動更新、polling、認証、raw files 編集や backend 同期処理には新しい導線を追加しない
  - 完了時には一覧 route だけで同期操作から再取得後表示まで到達でき、詳細 route の表示構成は変わらない
  - _Requirements: 1.1, 1.2, 1.5, 2.2, 2.3, 3.1, 3.2, 3.3, 4.1, 5.1, 5.3, 5.4, 5.5_
  - _Boundary: SessionIndexPage_
  - _Depends: 2.1, 3.1, 4.2, 4.3, 4.4_

- [ ] 5.2 page 側の表示合成で同期中・失敗時の閲覧状態を保つ
  - 既に session list が表示されている場合、syncing banner や disabled 操作が出ても page 側の条件分岐で list を隠さない
  - 同期失敗や refresh error のとき、既存一覧を同期成功後の最新一覧として扱う表示を出さない
  - 詳細 link と summary card は既存 component contract をそのまま使い、SessionList 自体は変更しない
  - 完了時には既存一覧あり、空状態、一覧取得 error の各状態で同期 UI と閲覧導線が page 上で破綻しない
  - _Requirements: 1.3, 1.4, 2.2, 2.4, 4.4, 4.5, 5.1, 5.2, 5.3_
  - _Boundary: SessionIndexPage_
  - _Depends: 5.1_

- [ ] 5.3 page integration test で主要ユーザーフローを固定する
  - 一覧上部の同期操作と空状態の取り込み操作が同じ同期要求を開始することを確認する
  - 同期中は上部操作と空状態 action が disabled になり、二重実行されないことを確認する
  - 同期成功後の sessions 表示、同期後 empty、refresh error、conflict、sync error を確認する
  - 既存 session cards と詳細 link が同期中も残ることを確認する
  - 完了時には一覧 page の主要フローが Testing Library で user event と observable UI として検証される
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.3, 3.4, 3.5, 4.1, 4.2, 4.3, 4.4, 4.5, 5.1, 5.2, 5.3_
  - _Boundary: SessionIndexPage_
  - _Depends: 5.1, 5.2_

- [ ] 6. Feature 全体の regression と境界を検証する
- [ ] 6.1 frontend の lint、build、test を通して統合回帰を確認する
  - frontend の型検査と build が通り、新しい同期型・hook・component の import 境界に破綻がないことを確認する
  - frontend test suite が通り、既存 detail page、session list、summary card、status panel の回帰がないことを確認する
  - 差分が frontend の一覧同期導線に閉じ、backend 同期処理、raw files 編集、検索/filter/auto refresh/polling/auth の機能追加がないことを確認する
  - 完了時には既存閲覧体験を保ったまま同期 UI の実装が検証コマンドで再現できる
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_
  - _Boundary: Frontend validation_
