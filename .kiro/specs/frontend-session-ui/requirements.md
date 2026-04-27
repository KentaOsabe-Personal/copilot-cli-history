# Requirements Document

## Project Description (Input)
**Who has the problem:** GitHub Copilot CLI のローカル会話履歴を参照したい利用者。

**Current situation:** backend にはセッション一覧 API と単一セッション詳細タイムライン API があり、current / legacy の差分や degraded 情報を含めて read-only で返せる。  
一方 frontend は土台だけがあり、一覧画面、詳細画面、ナビゲーション、タイムライン表示ルールは未実装である。

**What should change:** 利用者がブラウザ上でセッション一覧を閲覧し、任意のセッションを選んで詳細タイムラインへ遷移できるようにする。  
詳細画面では会話の流れ、ツール呼び出し、コードブロック、劣化データの有無を識別しながら履歴を読み返せるようにする。

## Introduction
この仕様は、GitHub Copilot CLI のローカル会話履歴を、ブラウザ上で一覧から選んで詳細タイムラインまで読み返せる frontend UI の要件を定義する。  
対象は read-only の閲覧体験に限定し、一覧表示、詳細表示、画面間ナビゲーション、履歴の不完全さや取得失敗の可視化を含む。

## Boundary Context
- **In scope**: セッション一覧表示、一覧から詳細への遷移、詳細画面の直接表示、タイムライン表示、コードブロックとツール呼び出しの識別表示、degraded / issue の可視化、空状態と取得失敗の案内
- **Out of scope**: 検索、絞り込み、並び替え条件の変更、再読み込み操作、自動更新、履歴の編集や削除、認証・認可、backend API 契約の拡張
- **Adjacent expectations**: backend-session-api が read-only の一覧・詳細データと not found / 一時失敗を区別できる応答を返すこと、backend-history-reader が degraded / issue 情報を detail と summary に含めること、この feature は raw 履歴の読取や正規化を担わないこと

## Requirements

### Requirement 1: セッション一覧の閲覧
**Objective:** As a 履歴を読み返したい利用者, I want セッション候補を一覧で確認したい, so that 読み返したい会話をすぐに選べる

#### Acceptance Criteria
1. When 利用者がセッション一覧画面を開いたとき, the Frontend Session UI shall 利用可能なセッションを最新の更新順で一覧表示する。
2. The Frontend Session UI shall 各セッションについて、選択判断に必要な要約情報としてセッション ID、更新日時、作業コンテキスト、使用モデル、degraded 状態を表示する。
3. While セッション一覧を取得中のとき, the Frontend Session UI shall 一覧がまだ読み込み中であることを識別できる表示を行う。
4. If 表示対象のセッションが存在しないとき, the Frontend Session UI shall セッションが存在しないことを示す空状態メッセージを表示する。

### Requirement 2: 一覧と詳細の画面遷移
**Objective:** As a 履歴を追跡したい利用者, I want 一覧から詳細へ迷わず移動したい, so that 対象セッションの内容をすぐ確認できる

#### Acceptance Criteria
1. When 利用者が一覧内のセッションを選択したとき, the Frontend Session UI shall 選択したセッションの詳細タイムライン画面へ遷移する。
2. When 利用者がセッション詳細画面の URL を直接開いたとき, the Frontend Session UI shall 対応するセッションの詳細を一覧画面を経由せず表示できる。
3. While セッション詳細を取得中のとき, the Frontend Session UI shall 詳細画面が読み込み中であることを識別できる表示を行う。
4. The Frontend Session UI shall 詳細画面から一覧画面へ戻るための明確な導線を提供する。
5. If 指定されたセッションが存在しないとき, the Frontend Session UI shall 対象セッションが見つからないことを明示し、一覧画面へ戻れるようにする。

### Requirement 3: 詳細タイムラインの読解支援
**Objective:** As a 過去のやり取りを確認したい利用者, I want 会話と操作の流れを読み解きたい, so that 実装の経緯や判断を復元できる

#### Acceptance Criteria
1. When セッション詳細を表示するとき, the Frontend Session UI shall 会話と操作の流れを時系列で追える順序でタイムライン表示する。
2. The Frontend Session UI shall 各タイムライン項目について、利用者が文脈を追うために必要な項目種別、発話主体、発生順序または時刻、本文を区別して表示する。
3. When タイムライン項目の session detail data に frontend が識別可能なツール呼び出し情報が含まれるとき, the Frontend Session UI shall 通常の会話本文と区別できる見た目で表示する。
4. When タイムライン項目がコードブロックを含むとき, the Frontend Session UI shall 改行とコードの構造を保ったまま表示する。

### Requirement 4: degraded と取得失敗の可視化
**Objective:** As a 不完全な履歴も含めて確認したい利用者, I want 読める範囲と欠落範囲を把握したい, so that 情報の信頼性を判断できる

#### Acceptance Criteria
1. When セッションが不完全な履歴を含むとき, the Frontend Session UI shall 一覧画面と詳細画面の両方で、そのセッションが完全ではないことを識別できるように表示する。
2. When セッションに issue 情報が含まれるとき, the Frontend Session UI shall 利用者が欠落や破損の影響範囲を理解できる説明を表示する。
3. If セッション一覧または詳細の取得に失敗したとき, the Frontend Session UI shall 成功表示と誤認しないエラー表示を行い、利用者が一覧画面を基点に再判断できるようにする。
4. The Frontend Session UI shall 履歴の閲覧に限定され、編集、削除、検索、絞り込み、再読み込み、自動更新の操作を提供しない。
