# Requirements Document

## Introduction
GitHub Copilot CLI のローカル会話履歴を参照したい開発者向けに、backend で履歴ファイルを安定して読み取れる基盤を定義する。  
この機能は `COPILOT_HOME` または既定の `~/.copilot` を履歴ルートとして解決し、新形式 `session-state` と旧形式 `history-session-state` の両方を読み取り、後続の API 実装や永続化方式に依存しない共通オブジェクトへ正規化できることを目的とする。

## Boundary Context
- **In scope**: 履歴ルート解決、新形式 `workspace.yaml` / `events.jsonl` の読取、旧形式 JSON の読取、共通オブジェクトへの正規化、未知イベントの raw JSON 保持、呼び出し元が識別できる失敗結果の返却
- **Out of scope**: セッション一覧 API、セッション詳細 API、永続化スキーマ、増分同期や監視、フロントエンド表示整形
- **Adjacent expectations**: 実行環境はローカルの Copilot CLI 履歴ファイルへ読取アクセスを提供し、後続フェーズはこの機能が返す共通オブジェクトを利用する

## Requirements

### Requirement 1: 履歴ルート解決
**Objective:** As a バックエンド開発者, I want 履歴ファイルの参照先を一貫して解決したい, so that ローカル実行と Docker 実行のどちらでも同じ履歴ソースを扱える

#### Acceptance Criteria
1. When 履歴ルートの解決が要求されたとき, the Backend History Reader shall `COPILOT_HOME` が設定されている場合はそのパスを履歴ルートとして扱う
2. While `COPILOT_HOME` が未設定のとき, the Backend History Reader shall `~/.copilot` を既定の履歴ルートとして扱う
3. If 設定済みまたは既定の履歴ルートが存在しないか参照できないとき, the Backend History Reader shall 履歴ファイルが利用できないことを呼び出し元が識別できる結果を返す
4. The Backend History Reader shall 履歴ルート配下の raw files を会話履歴の一次ソースとして扱う

### Requirement 2: 現行形式セッション読取
**Objective:** As a バックエンド開発者, I want 現行形式の履歴ディレクトリを共通オブジェクトとして読み出したい, so that 後続機能がセッションメタデータとイベント列を同じ入力として扱える

#### Acceptance Criteria
1. When `session-state/<session-id>/workspace.yaml` が利用可能なとき, the Backend History Reader shall セッション ID、作業ディレクトリ、Git リポジトリ情報、作成日時、更新日時を取得できる共通オブジェクトを返す
2. When `session-state/<session-id>/events.jsonl` が読み取られるとき, the Backend History Reader shall 各行を元の出現順を保ったイベント列として扱う
3. If `workspace.yaml` の内容が解釈できないとき, the Backend History Reader shall そのセッションのメタデータを正常データと区別できる結果を返す
4. If `events.jsonl` に解釈できない行が含まれるとき, the Backend History Reader shall 当該セッションに解釈不能なイベントが存在したことを呼び出し元が識別できる結果を返す
5. The Backend History Reader shall `workspace.yaml` と `events.jsonl` から得た情報を単一セッションの共通オブジェクトとして扱う

### Requirement 3: 旧形式セッション読取
**Objective:** As a バックエンド開発者, I want 旧形式の履歴も現行形式と同じ責務境界で扱いたい, so that 形式差分の有無にかかわらず履歴参照機能を継続できる

#### Acceptance Criteria
1. When `history-session-state/*.json` が存在するとき, the Backend History Reader shall 旧形式セッションを読取対象として扱う
2. When 旧形式セッションが読み取られるとき, the Backend History Reader shall `sessionId`、`startTime`、`chatMessages`、`timeline`、`selectedModel` から得られる情報を共通オブジェクトへ変換する
3. If 旧形式 JSON が解釈できないとき, the Backend History Reader shall その失敗を他の正常なセッションと区別できる結果を返す
4. The Backend History Reader shall 新形式と旧形式のどちらを読んだ場合でも同じ種類の共通オブジェクトを後続の呼び出し元へ提供する

### Requirement 4: 共通正規化と未知イベント保持
**Objective:** As a バックエンド開発者, I want 解釈できないイベントも失わずに共通形式へ載せたい, so that 後続フェーズで情報欠落なく履歴を利用できる

#### Acceptance Criteria
1. When 既知の型に一致しないイベントが見つかったとき, the Backend History Reader shall raw JSON を保持したまま共通オブジェクトへ含める
2. When イベントの一部属性だけを共通項目へ対応付けられるとき, the Backend History Reader shall 共通項目と raw JSON の両方を呼び出し元が参照できるようにする
3. The Backend History Reader shall イベント種別にかかわらずセッション内のイベント順序を保持する
4. The Backend History Reader shall 後続の API 層または永続化層が未実装でも利用できる正規化済みセッションデータを返す

### Requirement 5: ローカル読取境界とアクセス失敗の可視化
**Objective:** As an 運用者, I want 読取基盤がローカル履歴へのアクセス条件を明確に扱ってほしい, so that 実行環境の不足や権限問題を早く切り分けられる

#### Acceptance Criteria
1. The Backend History Reader shall ローカルの Copilot CLI 履歴ファイルだけを読取対象とする
2. If 読取対象ファイルまたはディレクトリへの権限が不足しているとき, the Backend History Reader shall 権限不足を呼び出し元が識別できる結果を返す
3. Where Docker などの実行環境でローカル履歴ルートが mount されている場合, the Backend History Reader shall mount 済みの履歴ルートを通常の読取対象として扱う
