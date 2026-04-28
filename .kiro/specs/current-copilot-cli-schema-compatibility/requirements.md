# Requirements Document

## Introduction
この仕様は、現行 Copilot CLI の `events.jsonl` schema を、このリポジトリの承認済み reader / API / UI の責務境界を保ったまま互換対象として扱うための要件を定義する。  
対象は read-only の履歴参照体験に限定し、current schema と legacy `history-session-state` が同じプロダクト文脈で共存しつつ、会話の主タイムラインを安全に読み返せることを目的とする。

## Boundary Context
- **In scope**: 現行 schema の会話イベント互換、会話本文とツール要求補助情報の読解支援、非会話イベントの安全な退避、current / legacy 共存時の共通読取体験、互換不足や部分破損の可視化
- **Out of scope**: `backend-history-reader` / `backend-session-api` / `frontend-session-ui` の基礎責務の再定義、Phase 7 の永続化、検索・監視、自動更新、詳細な debug UI 拡張、外部共有機能
- **Adjacent expectations**: `backend-history-reader` は raw files を正本として形式差分を吸収し、`backend-session-api` は read-only の共通契約を返し、`frontend-session-ui` はその契約を使って履歴を表示する。この仕様は責務の移動ではなく、現行 schema 互換で各層がそろうべき利用者向け挙動を定義する

## Requirements

### Requirement 1: 現行 schema の会話イベント互換
**Objective:** As a 履歴を読み返したい利用者, I want 現行 Copilot CLI schema のセッションでも会話主体と本文を同じ流れで読みたい, so that 保存形式の違いを意識せずに会話経緯を追える

#### Acceptance Criteria
1. When 現行 schema のセッションが表示対象になったとき, the Copilot History Application shall `user.message`、`assistant.message`、`system.message` を会話イベントとして区別できる情報を提供する
2. When 会話イベントが本文を含むとき, the Copilot History Application shall current / legacy のどちらでも同じ主タイムラインの文脈で読めるように扱う
3. While 会話イベントの役割、本文、または発生時刻の一部が欠けているとき, the Copilot History Application shall 読めた情報を保持しつつ完全な会話イベントと区別できるようにする
4. The Copilot History Application shall 現行 schema の会話イベントによって legacy 互換の読取体験を損なわない

### Requirement 2: 会話本文とツール要求補助情報の読解支援
**Objective:** As a 会話と操作文脈の両方を確認したい利用者, I want 本文とツール要求の痕跡を区別して読みたい, so that 応答内容だけでなく何が実行されようとしたかも把握できる

#### Acceptance Criteria
1. When 現行 schema の会話イベントが本文を含むとき, the Copilot History Application shall 改行、コードブロック、通常本文の違いを読解に必要な範囲で保った表示情報を提供する
2. When 現行 schema のイベントがツール要求補助情報を含むとき, the Copilot History Application shall 少なくともツール名と入力要約を通常本文と区別して表示できる情報を提供する
3. If ツール要求補助情報の一部項目が欠けているとき, the Copilot History Application shall 会話本文の表示を阻害せず、識別できる範囲の情報だけを保持する
4. The Copilot History Application shall ツール要求補助情報の有無によって会話本文の順序や読解可能性を損なわない

### Requirement 3: 非会話イベントの安全な取り扱い
**Objective:** As a 背景イベントも含めて履歴を確認したい利用者, I want 非会話イベントを会話本文と混同せずに扱いたい, so that 主タイムラインの理解を壊さず必要な詳細だけを追える

#### Acceptance Criteria
1. When セッションに `assistant.turn_*`、`tool.execution_*`、`hook.*`、`skill.invoked` などの非会話イベントが含まれるとき, the Copilot History Application shall それらを user / assistant の会話本文と誤認しない形で扱う
2. When 非会話イベントが会話理解の主対象ではないとき, the Copilot History Application shall 主タイムラインでは会話理解を優先しつつ、必要時に確認できる詳細情報を保持する
3. If イベント形状が既知の会話イベントまたは補助情報へ十分に対応付けられないとき, the Copilot History Application shall そのイベントを未知イベントとして区別し、生の詳細情報を失わない
4. The Copilot History Application shall 非会話イベントの存在によって会話イベントの順序や本文の読解を崩さない

### Requirement 4: current / legacy 共存時の共通読取体験
**Objective:** As a 履歴参照アプリ利用者, I want current と legacy の両形式を同じ使い方で読みたい, so that 保存形式ごとに別の操作や判断を強いられずに済む

#### Acceptance Criteria
1. When current または legacy のセッションが一覧または詳細に表示されるとき, the Copilot History Application shall 同じ主要項目の意味づけで読める共通契約を維持する
2. While current と legacy のセッションが同時に存在するとき, the Copilot History Application shall 利用者に schema ごとの切替や専用導線を要求しない
3. Where source format の違いにより取得できる付帯情報が異なる場合, the Copilot History Application shall 項目未提供と読取失敗を区別できるようにする
4. The Copilot History Application shall current schema 互換の追加によって既存の legacy セッション参照を後退させない

### Requirement 5: 劣化と互換不足の可視化
**Objective:** As an 運用者, I want schema 差分や部分破損の影響範囲を明確に把握したい, so that 空の成功結果や曖昧な表示と混同せずに切り分けできる

#### Acceptance Criteria
1. If 現行 schema のイベントが部分的にしか解釈できないとき, the Copilot History Application shall 影響を受けたセッションまたはイベントが完全ではないことを識別できるようにする
2. If 現行 schema 互換に起因する未知形状または読取不足が発生したとき, the Copilot History Application shall 空の成功結果で隠さず、影響範囲を区別できる issue 情報として示す
3. When 劣化を含むセッションが表示されるとき, the Copilot History Application shall 利用者が読める範囲と信頼できない範囲を判断できる説明を提供する
4. The Copilot History Application shall 一部のイベントが劣化していても、読める current / legacy セッションの閲覧は継続できる
