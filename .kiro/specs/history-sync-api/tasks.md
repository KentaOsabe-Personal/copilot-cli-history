# 実装計画

- [ ] 1. 同期実行の永続化基盤を拡張する
- [x] 1.1 同期実行に insert/update 件数と running lock を保存できるようにする
  - 同期実行に insert 件数、update 件数、running 中だけ有効な lock key を保持できる永続項目を追加する
  - running lock key は nullable unique として扱い、terminal row が複数残っても running row は同時に 1 件だけになる
  - schema load 後の状態で新しい件数項目と unique lock index が確認できる
  - _Requirements: 2.5, 3.1, 3.5, 6.1_
  - _Boundary: HistorySyncRun_

- [x] 1.2 同期実行の lifecycle と件数不変条件を model で保証する
  - running status は開始時刻と running lock を持ち、終了時刻なしで保存できる
  - succeeded、failed、completed_with_issues は終了時刻を必須にし、running lock を解放した状態だけを有効にする
  - insert/update/saved/skip/failure/degraded 件数は非負整数で、保存件数は insert 件数と update 件数の合計と一致する
  - model spec で running、terminal、invalid count、lock 解放、保存件数整合性を観測できる
  - _Requirements: 2.5, 3.1, 3.2, 3.3, 3.4, 3.5, 6.1, 6.2_
  - _Boundary: HistorySyncRun_

- [x] 1.3 (P) 保存属性生成で事前計算済み fingerprint を再利用できるようにする
  - 保存対象 session の attributes 生成時に、呼び出し元が渡した fingerprint をそのまま保存値として使える
  - fingerprint が渡されない場合は既存と同じ計算経路を維持する
  - builder は保存、skip/update 判定、削除判断を持たず、attributes 生成だけを行うことが spec で確認できる
  - _Requirements: 2.1, 2.2, 2.3, 5.2_
  - _Boundary: SessionRecordBuilder, SourceFingerprintBuilder_

- [ ] 2. 同期結果と API 表現の契約を固定する
- [x] 2.1 service が返す同期結果を成功、conflict、失敗として区別できるようにする
  - 成功結果は terminal sync run を保持し、controller が同期完了状態を自由文字列で解釈しなくてよい
  - conflict 結果は既存 running sync run を保持し、既存実行を上書きしない応答に使える
  - 失敗結果は terminal sync run、failure code、message、details を保持し、root failure と永続化失敗を区別できる
  - result spec で各結果が必要な公開値を持つことを確認できる
  - _Requirements: 1.2, 4.2, 6.2_
  - _Boundary: SyncResult_

- [x] 2.2 同期結果を HTTP status と JSON payload に変換する presenter を用意する
  - 成功時は sync run の状態、開始/終了時刻、processed/inserted/updated/saved/skipped/failed/degraded 件数を data payload に含める
  - running conflict は 409 の error envelope として返し、既存 running sync run の識別情報を details で確認できる
  - root failure は upstream failure code と path を含む 503、永続化失敗は sync run と failure class を含む 500 として返す
  - degraded だけを含む完了は失敗応答ではなく completed_with_issues の成功 payload として確認できる
  - _Requirements: 1.3, 2.5, 4.2, 4.3, 5.3, 5.4, 6.2_
  - _Boundary: HistorySyncPresenter_

- [ ] 3. request 内で完了する同期 service を実装する
- [x] 3.1 同期開始時に running run を作成し、二重実行を conflict に変換する
  - reader を呼ぶ前に running sync run を作成し、同時実行中であることを DB state として観測できる
  - 既存 running row または unique lock 競合がある場合は、新しい run を開始せず conflict 結果を返す
  - conflict 時も既存 running row の status、started_at、counts が変わらないことを spec で確認できる
  - _Depends: 1.2, 2.1_
  - _Requirements: 3.1, 6.1, 6.2, 6.3_
  - _Boundary: HistorySyncService, HistorySyncRun_

- [x] 3.2 root failure を failed run と失敗結果に変換する
  - reader が root failure を返した場合、session 保存へ進まず run を failed、終了時刻付き、failed count 付きに更新する
  - failed run には原因を識別できる failure summary と lock 解放状態を残す
  - root failure では read model が空データで上書きされず、既存 session row も変更されないことを確認できる
  - 返却結果には upstream failure code、message、path が含まれ、degraded session と同じ扱いにならない
  - _Depends: 3.1_
  - _Requirements: 3.4, 4.1, 4.2, 4.3, 4.4, 4.5_
  - _Boundary: HistorySyncService, HistorySyncRun_

- [x] 3.3 read success 時に insert/update/skip 判定と read model 保存を行う
  - raw files から読めた session ごとに source fingerprint を一度計算し、未保存 session は insert、差分あり session は update、一致 session は skip に分類する
  - insert/update のみ保存属性を生成して read model を変更し、skip では表示 payload と indexed timestamp を再保存しない
  - 同じ session ID の再同期では read model が重複せず、最新 row として参照できる
  - processed/inserted/updated/saved/skipped 件数が判定結果と一致し、raw files への write と read model の deletion が発生しないことを確認できる
  - _Depends: 1.3, 3.1_
  - _Requirements: 1.1, 1.4, 2.1, 2.2, 2.3, 2.4, 2.5, 6.4_
  - _Boundary: HistorySyncService, CopilotSession_

- [x] 3.4 degraded session を保存継続し、completed_with_issues として完了させる
  - session 単位の issue がある場合も読めた session の同期を継続し、保存対象であれば degraded state と issue 情報を read model に残す
  - degraded session が 1 件以上ある完了は completed_with_issues、degraded がない完了は succeeded として terminal run に記録する
  - degraded count と degradation summary が run と成功 payload の両方から確認できる
  - degraded だけの同期では root failure 用の失敗結果が返らないことを spec で確認できる
  - _Depends: 3.3_
  - _Requirements: 3.2, 3.3, 3.5, 5.1, 5.2, 5.3, 5.4_
  - _Boundary: HistorySyncService, HistorySyncRun, CopilotSession_

- [x] 3.5 永続化失敗時に部分保存を rollback し、run を failed として終了させる
  - session 保存中の予期しない永続化失敗では session mutation を rollback し、可能な限り run を failed、終了時刻付き、lock 解放済みに更新する
  - 失敗結果には sync run と failure class が含まれ、presenter が 500 応答を作れる
  - 失敗した同期の後に新しい同期要求を開始できる状態になっていることを確認できる
  - _Depends: 3.3_
  - _Requirements: 3.4, 3.5, 4.4_
  - _Boundary: HistorySyncService, HistorySyncRun_

- [ ] 4. HTTP endpoint と同期 service を統合する
- [x] 4.1 明示同期用の POST endpoint を追加し、service result を presenter 経由で返す
  - 明示 POST request が request body なしでも同期 service を 1 回だけ起動する
  - controller は reader、fingerprint、DB 判定を直接持たず、service result と presenter の status/payload を render する
  - 初期実装では background job、progress polling、自動 file watch を起動せず、既存 session list/detail API の参照元も変更しない
  - endpoint から success、conflict、root failure、persistence failure の status/payload を観測できる
  - _Depends: 2.2, 3.5_
  - _Requirements: 1.2, 4.2, 6.3, 6.5_
  - _Boundary: Api::HistorySyncsController, HistorySyncPresenter_

- [x] 4.2 request spec で成功系と再同期系の API 契約を固定する
  - mixed current/legacy fixture の POST で read model に session が保存され、200 response と terminal sync run が返る
  - 同じ fixture の再同期では fingerprint 一致 session が skip になり、payload と indexed timestamp が変わらない
  - raw file 変更後の再同期では update count が増え、同じ session ID の row が重複しない
  - response payload の sync run と counts が DB に記録された値と一致することを確認できる
  - _Depends: 4.1_
  - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 2.4, 2.5, 3.2, 3.5_
  - _Boundary: Request Specs, HistorySyncService, CopilotSession, HistorySyncRun_

- [x] 4.3 request spec で failure、degraded、conflict の API 契約を固定する
  - root missing/unreadable fixture で 503 error envelope、failed run、session write なしを確認できる
  - degraded fixture で 200 completed_with_issues、degraded count、保存済み issue 情報を確認できる
  - running row が存在する状態の POST で 409 error envelope が返り、既存 running row が上書きされない
  - session list/detail API がこの feature の完了条件として変更されていないことを regression として確認できる
  - _Depends: 4.1_
  - _Requirements: 3.3, 4.1, 4.2, 4.3, 4.4, 4.5, 5.1, 5.2, 5.3, 5.4, 6.1, 6.2, 6.3, 6.5_
  - _Boundary: Request Specs, HistorySyncPresenter, HistorySyncRun_

- [ ] 5. 実装全体の検証を完了する
- [x] 5.1 service spec で同期判定と transaction 境界を網羅する
  - reader success/failure を制御した service spec で insert、update、skip、degraded、root failure、running conflict を個別に確認できる
  - 永続化失敗の spec で session mutation が rollback され、failed run と lock 解放が残ることを確認できる
  - raw files を一次ソースとして読み取るだけで、同期 service が raw files への write/delete を行わないことを確認できる
  - _Depends: 3.5_
  - _Requirements: 1.1, 1.4, 2.1, 2.2, 2.3, 2.4, 2.5, 3.1, 3.2, 3.3, 3.4, 3.5, 4.1, 4.4, 4.5, 5.1, 5.2, 5.3, 5.4, 6.1, 6.2, 6.4_
  - _Boundary: Service Specs, HistorySyncService_

- [x] 5.2 backend spec suite で migration、model、builder、presenter、request の回帰を確認する
  - schema/model specs で sync run の count と running lock の不変条件が確認できる
  - builder/presenter/request specs で fingerprint reuse、JSON contract、HTTP status mapping が確認できる
  - backend の対象 spec または既存 CI コマンドが成功し、この feature の runtime prerequisite が Docker Compose 標準に乗っていることを確認できる
  - _Depends: 4.3, 5.1_
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3, 2.4, 2.5, 3.1, 3.2, 3.3, 3.4, 3.5, 4.1, 4.2, 4.3, 4.4, 4.5, 5.1, 5.2, 5.3, 5.4, 6.1, 6.2, 6.3, 6.4, 6.5_
  - _Boundary: Backend Test Suite_
