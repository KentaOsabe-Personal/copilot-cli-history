# 要件定義書

## はじめに
GitHub Copilot CLI のローカル会話履歴を参照する frontend 一覧画面に、利用者が明示的に履歴を最新化できる導線を追加する。  
この機能は、DB read model へ段階的に移行しても初期状態の一覧が空のまま放置されないようにし、同期中・成功後・失敗時の状態を利用者が誤解なく判断できることを目的とする。

## 境界コンテキスト
- **In scope**: 一覧画面の履歴最新化操作、同期中の disabled / loading 表示、同期成功後の一覧再取得、同期失敗の error state、DB 空状態の履歴取り込み導線、既存一覧表示との共存、必要に応じた初回同期説明
- **Out of scope**: backend 同期処理そのもの、session list/detail API の DB query 化、日付フィルタ UI、検索 UI、自動更新、background sync の進捗 polling、認証・認可、詳細画面の再設計、raw files の削除や DB の手動編集
- **Adjacent expectations**: `history-sync-api` は明示同期操作を受け付け、同期成功・失敗・二重実行 conflict を区別できる応答を返す。既存 session list API は同期後に再取得できる一覧データを返す。将来の `session-api-db-query` は、この UI が DB 空状態から履歴取り込みへ誘導できることを前提にできる。

## 要件

### 要件 1: 一覧画面からの明示同期操作
**Objective:** As a 履歴を読み返したい利用者, I want 一覧画面から履歴を最新化したい, so that DB が空または古い状態でも画面上で取り込みを開始できる

#### 受け入れ基準
1. When 利用者がセッション一覧画面を開いたとき, the Frontend History Sync UI shall 履歴を最新化する明示操作を一覧画面上に表示する
2. When 利用者が履歴最新化操作を実行したとき, the Frontend History Sync UI shall 利用者の明示操作として履歴同期を要求する
3. While 履歴同期を要求中のとき, the Frontend History Sync UI shall 同期中であることを識別できる表示を行う
4. While 履歴同期を要求中のとき, the Frontend History Sync UI shall 同じ画面操作からの二重実行を防ぐ
5. The Frontend History Sync UI shall 利用者が明示操作を行うまで自動的に履歴同期を開始しない

### 要件 2: 同期成功後の一覧更新
**Objective:** As a 履歴を確認する利用者, I want 同期後に最新の一覧へ切り替わってほしい, so that 取り込まれたセッションをすぐ選択できる

#### 受け入れ基準
1. When 履歴同期が成功したとき, the Frontend History Sync UI shall セッション一覧を再取得する
2. When 同期成功後の再取得で表示可能なセッションが返されたとき, the Frontend History Sync UI shall 既存の一覧表示ルールに沿って最新のセッション一覧を表示する
3. When 同期成功後の再取得で表示可能なセッションが返されたとき, the Frontend History Sync UI shall 利用者が同期完了後の一覧であることを識別できる状態を表示する
4. If 履歴同期は成功したが一覧の再取得に失敗したとき, the Frontend History Sync UI shall 最新一覧を表示できないことを成功一覧と誤認しないエラー表示で知らせる
5. The Frontend History Sync UI shall 同期結果の詳細表示を、利用者が完了または失敗を判断するために必要な最小限の情報に限定する

### 要件 3: 空状態からの履歴取り込み導線
**Objective:** As a 初回利用者, I want 空の一覧から履歴取り込みを開始したい, so that DB 未投入状態でも次に取るべき操作が分かる

#### 受け入れ基準
1. If セッション一覧が空のとき, the Frontend History Sync UI shall 表示対象が存在しない状態を loading または error と区別して表示する
2. If セッション一覧が空のとき, the Frontend History Sync UI shall 履歴を取り込むための主要操作を空状態内に表示する
3. When 利用者が空状態の履歴取り込み操作を実行したとき, the Frontend History Sync UI shall 一覧画面の履歴最新化操作と同じ同期要求を開始する
4. While 空状態からの履歴同期を要求中のとき, the Frontend History Sync UI shall 空状態の取り込み操作を二重実行できない状態にする
5. If 同期成功後も表示可能なセッションが存在しないとき, the Frontend History Sync UI shall 取り込み操作後も表示対象がないことを失敗表示と区別して示す

### 要件 4: 同期失敗と conflict の誤認防止
**Objective:** As a 利用者, I want 同期が失敗した理由を成功状態と区別したい, so that 環境や実行状態を確認して再試行を判断できる

#### 受け入れ基準
1. If 履歴同期要求が失敗したとき, the Frontend History Sync UI shall 同期が完了していないことを成功表示と誤認しない error state として表示する
2. If 履歴同期要求が二重実行 conflict として拒否されたとき, the Frontend History Sync UI shall 既に同期中の可能性を利用者が識別できる表示を行う
3. If 履歴同期要求が network、設定、または backend failure により失敗したとき, the Frontend History Sync UI shall 利用者が再試行可否を判断できる失敗表示を行う
4. When 同期失敗を表示するとき, the Frontend History Sync UI shall 既に表示中のセッション一覧を同期成功後の最新一覧として扱わない
5. When 同期失敗後に利用者が再度履歴最新化操作を実行したとき, the Frontend History Sync UI shall 新しい同期要求として扱う

### 要件 5: 既存閲覧体験と機能境界の維持
**Objective:** As a 既存 UI の利用者, I want 同期導線が追加されても一覧と詳細の閲覧をこれまで通り使いたい, so that 履歴参照の主要導線が壊れない

#### 受け入れ基準
1. When セッション一覧が表示されるとき, the Frontend History Sync UI shall 既存の session list rendering と詳細画面への選択導線を維持する
2. While 履歴同期を要求中のとき, the Frontend History Sync UI shall 既に表示可能なセッション一覧または一覧取得状態を不必要に隠さない
3. The Frontend History Sync UI shall 詳細画面の表示構成をこの feature の対象に含めない
4. The Frontend History Sync UI shall 日付フィルタ、検索、自動更新、進捗 polling、認証・認可の操作をこの feature の対象に含めない
5. The Frontend History Sync UI shall raw files の削除、保存済みデータの手動編集、または backend 同期処理の変更をこの feature の対象に含めない
