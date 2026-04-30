# 要件定義書

## はじめに
GitHub Copilot CLI のローカル会話履歴を raw files から読み取り、保存済み read model を利用者の明示操作で最新化できる同期 API を提供する。  
この機能は、raw files を一次ソースとして維持しながら、同期結果、保存件数、失敗、劣化状態を運用者と後続 UI が識別できる形で返す。

## 境界コンテキスト
- **In scope**: 明示同期 API、同期実行中の二重実行防止、raw files 読取結果からの insert / update / skip 判定、保存済み read model の更新、同期実行結果と件数の記録、root failure の失敗応答、session 単位の degraded を含む同期成功、backend request / service の検証
- **Out of scope**: background job、自動 file watch、raw files 削除に伴う read model 削除、frontend の同期ボタン、既存 session list/detail API の DB query 化、日付フィルタ UI、検索 UI、認証・認可、同期履歴取得 API
- **Adjacent expectations**: `history-db-read-model` は保存先、表示 payload、source fingerprint を提供する。`backend-history-reader` は root failure と session 単位の degraded を区別した読取結果を提供する。`frontend-history-sync-ui` はこの API を利用して利用者の同期操作を実装するが、同期処理そのものはこの feature が提供する。

## 要件

### 要件 1: 明示同期 API の実行
**Objective:** As a 利用者, I want 明示操作でローカル履歴を保存済み read model に同期したい, so that 画面表示を raw files の直接読取から段階的に切り替えられる

#### 受け入れ基準
1. When 利用者または後続 UI が履歴同期を要求したとき, the History Sync API shall raw files から読み取れるセッションを保存済み read model に同期する
2. When 同期要求が受け付けられたとき, the History Sync API shall 同期処理をリクエスト内で完了させ、完了状態を含む応答を返す
3. When 同期が正常に完了したとき, the History Sync API shall 成功応答として同期実行の状態、処理件数、保存件数、skip 件数、劣化件数を返す
4. The History Sync API shall raw files を一次ソースとして扱い、同期 API の実行だけで raw files を変更しない

### 要件 2: insert / update / skip 判定
**Objective:** As a バックエンド開発者, I want 同期時に保存が必要なセッションだけを更新したい, so that 既存 read model を重複させず効率的に最新化できる

#### 受け入れ基準
1. When raw files から読み取ったセッションが保存済み read model に存在しないとき, the History Sync API shall そのセッションを新規保存として扱う
2. When raw files から読み取ったセッションが保存済み read model に存在し、source fingerprint が保存済み fingerprint と異なるとき, the History Sync API shall そのセッションを更新保存として扱う
3. When raw files から読み取ったセッションが保存済み read model に存在し、source fingerprint が保存済み fingerprint と一致するとき, the History Sync API shall そのセッションを skip として扱い、表示 payload を再保存しない
4. When 同じセッション ID が再同期されるとき, the History Sync API shall 保存済み read model を重複させず、同一セッションの最新同期結果として参照できる状態にする
5. The History Sync API shall insert、update、skip の件数を同期結果として識別できるようにする

### 要件 3: 同期実行履歴と件数記録
**Objective:** As an 運用者, I want 同期の開始、終了、結果、件数を確認したい, so that DB が空なのか同期が失敗したのかを切り分けられる

#### 受け入れ基準
1. When 同期処理が開始されるとき, the History Sync API shall 同期実行を running 状態として記録する
2. When 同期処理が正常に完了したとき, the History Sync API shall 同期実行を終了時刻付きの succeeded 状態として記録する
3. While 同期処理が session 単位の degraded を含んで完了したとき, the History Sync API shall 同期実行を完全成功と区別できる完了状態として記録する
4. If 同期処理が完了できない失敗で終了したとき, the History Sync API shall 同期実行を終了時刻付きの failed 状態として記録する
5. When 同期実行が終了するとき, the History Sync API shall 処理件数、保存件数、skip 件数、失敗件数、劣化件数を後続処理が参照できる形で記録する

### 要件 4: root failure と error response
**Objective:** As a 利用者, I want 履歴ルートが読めない失敗を空の同期成功と区別したい, so that 原因を把握して環境を修正できる

#### 受け入れ基準
1. If raw files の履歴ルートを解決または読取できないとき, the History Sync API shall 同期実行を failed として記録する
2. If root failure が発生したとき, the History Sync API shall 成功応答ではなく失敗応答を返す
3. If root failure が発生したとき, the History Sync API shall 失敗応答に failure code と利用者または運用者が原因を識別できる詳細を含める
4. If root failure が発生したとき, the History Sync API shall 保存済み read model を空データとして上書きしない
5. The History Sync API shall root failure と session 単位の degraded を同じ失敗として扱わない

### 要件 5: degraded session の継続保存
**Objective:** As a 利用者, I want 一部壊れたセッションでも読める範囲を同期したい, so that 部分破損が全履歴の取り込みを妨げない

#### 受け入れ基準
1. When raw files から session 単位の degraded を含む読取結果が返されたとき, the History Sync API shall 読み取れたセッションの同期を継続する
2. When degraded session が保存対象になるとき, the History Sync API shall 劣化状態と issue 情報を後続表示が識別できる形で保存する
3. While degraded session を含む同期が完了したとき, the History Sync API shall 劣化件数を同期結果と同期実行履歴に含める
4. If session 単位の degraded だけが発生したとき, the History Sync API shall その状態を root failure の失敗応答として返さない

### 要件 6: 二重実行と実行境界
**Objective:** As an 運用者, I want 同期処理の二重実行を避けたい, so that 保存結果と実行件数を混乱させずに扱える

#### 受け入れ基準
1. While 未完了の同期実行が存在するとき, the History Sync API shall 新しい同期要求を conflict として拒否する
2. When 同期要求が conflict として拒否されるとき, the History Sync API shall 既存の running 同期を上書きせず、利用者または後続 UI が二重実行中であることを識別できる応答を返す
3. The History Sync API shall 初期実装で background job、進捗 polling、自動 file watch を提供しない
4. The History Sync API shall raw files から消えたセッションを同期処理によって保存済み read model から自動削除しない
5. The History Sync API shall 既存の session list/detail API の参照元切替をこの feature の完了条件に含めない
