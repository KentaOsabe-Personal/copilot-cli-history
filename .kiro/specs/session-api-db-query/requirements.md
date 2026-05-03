# 要件定義書

## はじめに
GitHub Copilot CLI のローカル会話履歴を参照する利用者向けに、既存の session list/detail API を保存済み read model 参照へ切り替え、raw files を毎回読み直さずに一覧と詳細を返せるようにする。

この機能は、同期 API と frontend 同期導線が利用可能になった後の参照元切替を対象にし、一覧 API では日付範囲と件数制限を扱い、詳細 API では保存済み detail payload を返す。既存の read-only API 契約を保ちながら、保存済み read model が空の状態、日付不明のセッション、未登録セッションを利用側が判別できることを目的とする。

## 境界コンテキスト
- **In scope**: `GET /api/sessions` の保存済み read model 参照化、`from` / `to` / `limit` による一覧取得条件、未指定時の直近 30 日既定期間、履歴由来日時に基づく並び順、不正な一覧条件の client error、read model 空一覧の成功応答、`GET /api/sessions/:id` の保存済み detail payload 返却、未登録 detail の `session_not_found` 応答、既存一覧・詳細 response shape との互換性確認
- **Out of scope**: raw files への fallback、同期 service、`POST /api/history/sync`、frontend 同期ボタン、検索 UI、repo / branch / model filter UI、削除同期、認証・認可、保存済み read model の保存 contract 変更
- **Adjacent expectations**: `history-db-read-model` は一覧用 summary payload、詳細用 detail payload、履歴由来日時を保存済み read model として提供する。`history-sync-api` と frontend 同期導線は、API 参照元切替前に利用者が read model を最新化できる状態を提供する。`backend-session-api` の既存 list/detail 契約は、この feature の互換性基準になる。

## 要件

### 要件 1: セッション一覧の保存済み read model 参照
**Objective:** As a セッション履歴を閲覧する利用者, I want 一覧 API が保存済み read model からセッション候補を返してほしい, so that raw files の直接読取に依存せず一覧画面を開ける

#### 受け入れ基準
1. When クライアントがセッション一覧を要求したとき, the Backend Session API shall 保存済み read model に存在するセッションを既存の一覧 response shape で返す
2. When セッション一覧を返すとき, the Backend Session API shall 各セッションについてセッション ID、source format、作成日時、更新日時、作業コンテキスト、選択モデル、source state、会話要約、degraded 状態、issue 情報を利用側が識別できる形で含める
3. When 保存済み read model に current 形式と legacy 形式のセッションが含まれるとき, the Backend Session API shall どちらの source format でも共通の一覧契約として返す
4. If 保存済み read model に一覧対象のセッションが存在しないとき, the Backend Session API shall 失敗応答ではなく 200 の成功応答として空の `data` と件数 0 の `meta` を返す
5. The Backend Session API shall セッション一覧取得を read-only の取得操作として提供する

### 要件 2: 日付範囲と初期表示期間
**Objective:** As a 履歴を読み返したい利用者, I want 一覧 API が履歴由来日時で表示対象期間を絞り込んでほしい, so that 初期表示と期間指定で関係するセッションだけを確認できる

#### 受け入れ基準
1. When クライアントが `from` を指定してセッション一覧を要求したとき, the Backend Session API shall 履歴由来の表示日時が `from` 以降のセッションだけを一覧対象にする
2. When クライアントが `to` を指定してセッション一覧を要求したとき, the Backend Session API shall 履歴由来の表示日時が `to` 以前のセッションだけを一覧対象にする
3. When クライアントが `from` と `to` の両方を指定してセッション一覧を要求したとき, the Backend Session API shall 両端を含む日付範囲に一致するセッションだけを一覧対象にする
4. When クライアントが `from` と `to` を指定せずにセッション一覧を要求したとき, the Backend Session API shall 要求時点から直近 30 日を既定期間として一覧対象にする
5. While 履歴由来の更新日時が存在するセッションを日付判定するとき, the Backend Session API shall 更新日時を表示日時として扱う
6. While 履歴由来の更新日時が欠落し、履歴由来の作成日時が存在するセッションを日付判定するとき, the Backend Session API shall 作成日時を表示日時として扱う
7. If 履歴由来の更新日時と作成日時がどちらも欠落しているとき, the Backend Session API shall そのセッションを日付範囲に一致するセッションとして扱わない

### 要件 3: 一覧の並び順と件数制限
**Objective:** As a セッション一覧を確認する利用者, I want 関連性の高い新しい履歴から安定して表示されてほしい, so that 一覧の順序が再取得ごとに揺れず目的の会話を探せる

#### 受け入れ基準
1. When セッション一覧を返すとき, the Backend Session API shall 履歴由来の表示日時が新しいセッションから順に返す
2. When 複数セッションの履歴由来の表示日時が同一のとき, the Backend Session API shall セッション ID 昇順による安定した順序で返す
3. When クライアントが正の整数の `limit` を指定してセッション一覧を要求したとき, the Backend Session API shall 日付範囲と並び順を適用した後、指定件数を超えない一覧を返す
4. When クライアントが `limit` を指定せずにセッション一覧を要求したとき, the Backend Session API shall 日付範囲に一致するすべてのセッションを既定の並び順で返す
5. If `limit` が正の整数として解釈できない値として指定されたとき, the Backend Session API shall 成功応答と区別できるクライアントエラーを返す

### 要件 4: セッション詳細の保存済み detail payload 返却
**Objective:** As a 過去セッションを読み返す利用者, I want 詳細 API が保存済み detail payload を返してほしい, so that 会話タイムラインを raw files の再読取なしで確認できる

#### 受け入れ基準
1. When クライアントが保存済み read model に存在するセッション ID を指定して詳細を要求したとき, the Backend Session API shall そのセッションの保存済み detail payload を既存の詳細 response shape で返す
2. When 詳細 payload を返すとき, the Backend Session API shall ヘッダ情報、message snapshots、conversation、activity、timeline、degraded 状態、issue 情報を利用側が識別できる形で含める
3. When current 形式または legacy 形式のセッション詳細を返すとき, the Backend Session API shall どちらの source format でも共通の詳細契約として返す
4. When 詳細 API に raw payload の取得を示す要求が含まれるとき, the Backend Session API shall raw files を再読取せず、保存済み detail payload の範囲だけを返す
5. The Backend Session API shall セッション詳細取得を read-only の取得操作として提供する

### 要件 5: 未登録セッションと一覧条件エラー契約
**Objective:** As a frontend 開発者, I want 未登録セッション、一覧空状態、不正な一覧条件を明確に区別したい, so that 利用者に適切な not found 表示、空状態、入力エラーを出せる

#### 受け入れ基準
1. If クライアントが保存済み read model に存在しないセッション ID を指定して詳細を要求したとき, the Backend Session API shall `session_not_found` のエラー応答を返す
2. If `session_not_found` を返すとき, the Backend Session API shall 404 status と対象セッション ID を含む error details を返す
3. If 保存済み read model が空のとき, the Backend Session API shall 一覧 API では空の成功応答を返し、詳細 API では指定 ID に対する `session_not_found` を返す
4. If `from` または `to` が日付範囲条件として解釈できない値として指定されたとき, the Backend Session API shall 成功応答と区別できるクライアントエラーを返す
5. If `from` が `to` より後の範囲として指定されたとき, the Backend Session API shall 成功応答と区別できるクライアントエラーを返す
6. The Backend Session API shall `session_not_found` を保存済み read model の未登録状態として扱い、履歴ルート読取失敗と同じエラーとして扱わない

### 要件 6: 参照元切替の互換性と境界
**Objective:** As a プロダクト保守者, I want 既存の session API 利用側への不要な影響を避けたい, so that 参照元切替後も一覧・詳細 UI を段階的に維持できる

#### 受け入れ基準
1. When セッション一覧または詳細を返すとき, the Backend Session API shall `backend-session-api` で定義済みの read-only list/detail 契約と互換性のある top-level response structure を保つ
2. When 保存済み payload に degraded 状態または issue 情報が含まれるとき, the Backend Session API shall その情報を正常データと区別できる形で返す
3. The Backend Session API shall この feature で raw files への fallback、同期実行、frontend 同期操作、検索、repo / branch / model filter、削除同期を提供しない
4. The Backend Session API shall raw files を一次ソースとするプロダクト方針を変更せず、保存済み read model を再生成可能な参照先として扱う
5. Where 保存済み read model 参照への切替が有効化される場合, the Backend Session API shall 利用者が同期操作によって read model を準備できる状態を前提にする
