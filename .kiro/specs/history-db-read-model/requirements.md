# Requirements Document

## Introduction
GitHub Copilot CLI のローカル会話履歴を参照する利用者向けに、raw files reader が正規化したセッションを後続機能が再利用できる read model として保存する。  
この機能は、日付範囲指定や初期表示期間指定を将来の query で安定して扱えるように、セッション表示 payload、source metadata、同期実行結果を再生成可能な保存 contract として定義する。

## Boundary Context
- **In scope**: セッション単位の read model 保存 contract、summary / detail 表示 payload の保存 contract、source path と source fingerprint の保持、履歴由来日時と保存レコード日時の区別、同期実行結果の記録、後続 query が使う日付判断材料
- **Out of scope**: raw files の読取起動、明示同期の外部操作、既存の一覧 / 詳細取得の参照元切替、画面 UI、削除同期、非同期の自動実行、検索 UI、認証・認可
- **Adjacent expectations**: `backend-history-reader` は current / legacy raw files から正規化済みセッションと issue を提供し、`backend-session-api` の既存 presenter contract は表示 payload の基準になる。後続の `history-sync-api` は同期実行と upsert 判断を担当し、`session-api-db-query` は保存済み read model の query 表示を担当する

## Requirements

### Requirement 1: セッション read model の保存単位
**Objective:** As a バックエンド開発者, I want 正規化済みセッションをセッション単位の read model として保持したい, so that 後続機能が raw files を毎回読み直さずに履歴表示用データを参照できる

#### Acceptance Criteria
1. When 正規化済みセッションが保存対象として渡されたとき, the History DB Read Model shall セッション ID ごとに 1 件の read model として保持できる
2. When 同じセッション ID の保存内容が再生成されたとき, the History DB Read Model shall 同一セッションの read model を重複させず、後続処理が最新の保存内容を参照できる状態にする
3. When read model が参照されるとき, the History DB Read Model shall source format、source state、作業コンテキスト、選択モデル、履歴由来の作成日時、履歴由来の更新日時を後続処理が識別できる情報として提供する
4. While 履歴由来の作成日時または更新日時が欠落しているとき, the History DB Read Model shall 欠落を保存レコード自身の日時で暗黙に補完せず、後続処理が欠落として識別できる状態を保つ
5. The History DB Read Model shall 履歴由来の作成日時および更新日時を、保存レコード自身の作成日時および更新日時と区別できるようにする

### Requirement 2: 表示 payload の再利用
**Objective:** As a 後続表示機能の開発者, I want 一覧用と詳細用の表示 payload を read model から利用したい, so that 既存の表示契約を保ったまま参照元を保存済みデータへ切り替えられる

#### Acceptance Criteria
1. When 正規化済みセッションから一覧表示用 payload が作られるとき, the History DB Read Model shall セッション ID、source format、日時、作業コンテキスト、会話要約、劣化状態、issue 情報を後続の一覧表示で利用できる形として保持する
2. When 正規化済みセッションから詳細表示用 payload が作られるとき, the History DB Read Model shall ヘッダ情報、message snapshots、conversation、activity、timeline、劣化状態、issue 情報を後続の詳細表示で利用できる形として保持する
3. When current 形式または legacy 形式のセッションが保存対象になるとき, the History DB Read Model shall どちらの source format でも共通の read model contract として扱える payload を保持する
4. If 正規化済みセッションに session 単位または event 単位の issue が含まれるとき, the History DB Read Model shall issue を正常データと区別でき、後続表示が劣化状態を失わない形で保持する
5. The History DB Read Model shall 保存済みセッションの一覧表示および詳細表示に必要な payload を、raw files の再読取に依存せず参照できるようにする

### Requirement 3: source metadata と fingerprint
**Objective:** As a 同期機能の開発者, I want 保存済み read model と raw files の対応関係を比較できる材料がほしい, so that 後続同期で再生成の必要性を判断できる

#### Acceptance Criteria
1. When 正規化済みセッションが source path 情報を含むとき, the History DB Read Model shall source artifact の役割と path を後続処理が識別できる形で保持する
2. When source fingerprint が作られるとき, the History DB Read Model shall source artifact の path、更新時刻、サイズに基づく比較材料を提供する
3. While source artifact の path、更新時刻、サイズが変わらないとき, the History DB Read Model shall 同じセッションに対して安定した source fingerprint を提供する
4. When source artifact の path、更新時刻、またはサイズが変わったとき, the History DB Read Model shall 変更前と区別できる source fingerprint を提供する
5. If source fingerprint に必要な source metadata を取得できないとき, the History DB Read Model shall fingerprint が完全ではないことを後続処理が識別できる状態にする
6. The History DB Read Model shall source fingerprint を比較材料として提供し、同期時に保存を省略するか再生成するかの判断そのものはこの feature の契約に含めない

### Requirement 4: 同期実行結果の記録
**Objective:** As an 運用者, I want 履歴同期の実行結果を read model と別に確認したい, so that 保存済みセッションの有無と同期処理の成否を切り分けられる

#### Acceptance Criteria
1. When 後続同期処理が同期実行結果を記録するとき, the History DB Read Model shall 実行時刻、完了状態、処理件数、保存件数、失敗または劣化の概要を後続処理が参照できる形で保持する
2. If 同期処理がセッションを保存する前に失敗したとき, the History DB Read Model shall セッションが存在しない状態と同期実行失敗を区別できる記録を保持する
3. While 同期処理が一部セッションの劣化を含んで完了したとき, the History DB Read Model shall 完全成功と部分劣化を後続処理が区別できる記録を保持する
4. The History DB Read Model shall 同期実行結果の記録を提供し、raw files の読取開始、明示同期の外部操作入口、非同期の自動実行をこの feature の契約に含めない

### Requirement 5: 日付範囲 query への準備
**Objective:** As a 後続表示機能の開発者, I want read model が履歴由来日時に基づく並び替えや範囲指定に必要な情報を持っていてほしい, so that 将来の一覧取得が raw files を読まずに日付条件を処理できる

#### Acceptance Criteria
1. When 後続 query がセッションの日付判断材料を必要とするとき, the History DB Read Model shall 履歴由来の更新日時を優先し、欠落時は履歴由来の作成日時を使える情報として提供する
2. If 履歴由来の更新日時と作成日時の両方が欠落しているとき, the History DB Read Model shall そのセッションを保存レコード日時で履歴日付に見せかけず、日付不明として識別できるようにする
3. When 後続 query が新しい順の一覧表示を必要とするとき, the History DB Read Model shall raw files を再読取せずに履歴由来日時で並び替えられる情報を提供する
4. Where 後続 query が日付範囲指定を提供する場合, the History DB Read Model shall 範囲判定に使う履歴由来日時と日付不明セッションを区別できる情報を提供する

### Requirement 6: 再生成可能性と機能境界
**Objective:** As a プロダクト保守者, I want read model を raw files から再生成できる補助層として扱いたい, so that raw files を一次ソースとする方針を保ったまま段階的に DB 化できる

#### Acceptance Criteria
1. The History DB Read Model shall raw files 由来の正規化済みセッションから再生成可能な補助データとして扱われる
2. When 表示 payload の contract が変更されたとき, the History DB Read Model shall 同じセッション ID の保存済み payload を再生成結果で置き換えられる状態にする
3. The History DB Read Model shall raw files を一次ソースから外す契約を含めない
4. The History DB Read Model shall raw files が削除されたセッションを自動的に削除する契約を含めない
5. The History DB Read Model shall 既存の一覧 / 詳細取得の参照元切替、画面の同期導線、検索 UI をこの feature の契約に含めない
