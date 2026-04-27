# Requirements Document

## Introduction
GitHub Copilot CLI のローカル会話履歴を参照する利用者向けに、`backend-history-reader` が正規化したセッションデータを read-only の HTTP API として提供する。  
この機能はセッション一覧取得と単一セッションの詳細タイムライン取得を対象にし、frontend や将来の利用側が raw files を直接読まずに、正常系と識別可能な失敗系の両方を扱えることを目的とする。

## Boundary Context
- **In scope**: セッション一覧取得、単一セッションの詳細タイムライン取得、current / legacy 両形式を共通契約で返すこと、セッション単位 / イベント単位の issue 可視化、利用側が分岐可能なエラー契約
- **Out of scope**: repo / branch / date / model の検索・フィルタ、永続化スキーマ、増分同期や監視、frontend の表示実装、認証・認可
- **Adjacent expectations**: `backend-history-reader` は raw Copilot 履歴 files から正規化済みセッションと failure / issue を提供し、この feature はその結果を API 契約へ写像する

## Requirements

### Requirement 1: セッション一覧取得
**Objective:** As a フロントエンド開発者, I want セッション一覧を単一 API で取得したい, so that 一覧画面が履歴ファイルの形式差分や reader 呼び出しを意識せずに表示できる

#### Acceptance Criteria
1. When クライアントがセッション一覧を要求したとき, the Backend Session API shall 読み取り可能な current 形式と legacy 形式のセッションを同じ一覧契約で返す
2. When セッション一覧を返すとき, the Backend Session API shall 各セッションについて UI が識別に使うセッション ID、source format、作成日時、更新日時、作業コンテキストを識別する要約情報を含める
3. While 履歴ルートが読み取り可能で一部セッションだけに reader issue があるとき, the Backend Session API shall 他の読み取り可能なセッションの一覧返却を継続し、issue を持つセッションを利用側が識別できるようにする
4. The Backend Session API shall セッション一覧取得を read-only の取得操作として提供する

### Requirement 2: セッション詳細タイムライン取得
**Objective:** As a 履歴参照アプリ利用者, I want 単一セッションの詳細タイムラインを取得したい, so that 会話の流れとツール実行の文脈を時系列で確認できる

#### Acceptance Criteria
1. When クライアントが既存のセッション ID を指定して詳細を要求したとき, the Backend Session API shall そのセッションのヘッダ情報とタイムラインを単一レスポンスで返す
2. When タイムラインを返すとき, the Backend Session API shall 読み取り元で観測されたイベント順序を保持する
3. When タイムライン内に user message、assistant message、tool 関連イベント、または部分的にしか正規化できないイベントが含まれるとき, the Backend Session API shall 利用側が各イベントの種別、発生順、表示可能な内容、劣化有無を識別できる情報を返す
4. If 指定されたセッション ID が読み取り可能な履歴ルート内に存在しないとき, the Backend Session API shall 履歴ルート障害と区別できるセッション未検出のエラー応答を返す

### Requirement 3: 障害と劣化の可視化
**Objective:** As an 運用者, I want 履歴取得失敗と部分劣化を利用側が明確に識別できてほしい, so that 空データや曖昧な失敗として誤解されずに切り分けできる

#### Acceptance Criteria
1. If Copilot 履歴ルートが存在しない、参照できない、または権限不足のとき, the Backend Session API shall 失敗理由を識別できるエラー応答を返し、誤解を招く空のセッション一覧または空のタイムラインを返さない
2. If セッション固有の metadata 読取失敗や壊れた event data が検出されたとき, the Backend Session API shall その劣化を正常データと区別できる形で返す
3. When 部分正規化または未知イベント形状に由来する劣化データを返すとき, the Backend Session API shall 影響を受けたセッションまたはイベントに対応づけられる機械判別可能な issue 情報を含める
4. The Backend Session API shall セッション一覧取得と詳細取得の両方で一貫したエラー契約を使い、利用側が自由文メッセージの解釈に依存せず分岐できるようにする

### Requirement 4: API 契約の一貫性と MVP 境界
**Objective:** As a 将来の API 利用者, I want current / legacy の差分や未対応機能を明確に扱える契約がほしい, so that MVP の範囲内で安定した連携を組める

#### Acceptance Criteria
1. When current 形式または legacy 形式のセッションが API から返されるとき, the Backend Session API shall どちらの source format でも共通のセッション契約として扱う
2. Where source format ごとに取得できる付帯情報が異なる場合, the Backend Session API shall 同じレスポンス契約の中で利用可能情報と欠落情報を区別して返す
3. The Backend Session API shall この feature でセッション一覧取得と単一セッション詳細取得だけを提供対象とする
4. The Backend Session API shall repo、branch、date、model による検索・フィルタ、永続化、監視をこの feature の契約に含めない
