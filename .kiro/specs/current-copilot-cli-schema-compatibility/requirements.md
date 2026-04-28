# Requirements Document

## Introduction
この仕様は、現行 Copilot CLI の `events.jsonl` schema から会話 transcript を主表示として安全に読み返すための要件を定義する。  
対象は read-only の履歴参照体験に限定し、current schema と legacy `history-session-state` が同じプロダクト文脈で共存しつつ、内部 event log のノイズではなくユーザーと Copilot の会話を最初に読めることを目的とする。

## Boundary Context
- **In scope**: 現行 schema の会話 transcript 抽出、会話-first の詳細表示、内部 activity と主会話の分離、tool request 補助情報の扱い、会話あり session の一覧識別、実更新時刻の補正、raw detail の通常閲覧からの分離、current / legacy 共存時の回帰防止
- **Out of scope**: `session-store.db` や `session.db` の transcript source 化、全文検索、MySQL 永続化、差分取り込み、tool execution の完全相関、raw payload 専用 viewer、外部共有や gist 連携
- **Adjacent expectations**: raw files は一次ソースとして維持し、完全 event log は失わない。この仕様は、主表示で会話を優先する利用者向け挙動を定義し、reader / API / UI の基礎責務そのものは再定義しない

## Requirements

### Requirement 1: 主会話 transcript の抽出
**Objective:** As a 履歴を読み返したい利用者, I want user と assistant の本文だけを会話順に読める, so that 内部ログに埋もれず会話経緯を追える

#### Acceptance Criteria
1. When current schema の session detail が表示対象になったとき, the Copilot History Application shall 非空本文を持つ `user.message` と `assistant.message` を主会話 transcript として識別できる情報を提供する
2. When current schema の主会話 transcript が提示されるとき, the Copilot History Application shall source event の発生順を保ったまま user と assistant の発話を表示できるようにする
3. If `assistant.message` が空本文または `null` 本文で tool request のみを含むとき, the Copilot History Application shall その event を空の assistant 発話として主会話 transcript に含めない
4. If current schema の event が `system.message`、detail、unknown、または非会話 activity として扱われるとき, the Copilot History Application shall その event を user / assistant の主会話本文として表示しない
5. The Copilot History Application shall current schema の主会話抽出によって legacy session の user / assistant 会話表示を後退させない

### Requirement 2: 詳細画面の conversation-first 体験
**Objective:** As a セッション内容を確認する利用者, I want 詳細画面を開いた直後に会話履歴を読める, so that 内部イベント一覧を先に解釈しなくて済む

#### Acceptance Criteria
1. When 利用者が会話本文を持つ session detail を開いたとき, the Copilot History Application shall 最初の主表示として user / assistant の会話履歴を提示する
2. When session detail の主会話 transcript が空のとき, the Copilot History Application shall 表示できる会話本文がないことを利用者に明示する
3. While detail response が主会話 transcript と完全 event timeline の両方を利用できるとき, the Copilot History Application shall 主表示では主会話 transcript を優先する
4. While detail response が主会話 transcript をまだ提供しないとき, the Copilot History Application shall 既存の完全 event timeline から同じ抽出条件で主会話を提示できる
5. The Copilot History Application shall 主会話表示で改行、コードブロック、長い本文を読解可能な形で保持する

### Requirement 3: 内部 activity と raw timeline の分離
**Objective:** As a 背景イベントも必要に応じて確認したい利用者, I want 内部 activity を主会話と混同せず確認できる, so that 会話の読みやすさと調査可能性を両立できる

#### Acceptance Criteria
1. When session に `system.message`、`assistant.turn_*`、`tool.execution_*`、`hook.*`、`skill.invoked`、または unknown event が含まれるとき, the Copilot History Application shall それらを主会話 transcript とは別の activity として扱う
2. While 利用者が session detail の通常表示を読んでいるとき, the Copilot History Application shall 内部 activity を主会話本文に混在させない
3. Where 内部 activity の確認機能が提供される場合, the Copilot History Application shall 初期状態で主会話の読解を妨げない形で activity を提示する
4. If event shape が既知の会話 event または補助情報へ十分に対応付けられないとき, the Copilot History Application shall その event を unknown activity として区別し、生の詳細情報を失わない
5. The Copilot History Application shall 内部 activity の存在によって主会話 transcript の順序や本文の読解を崩さない

### Requirement 4: tool request 補助情報の扱い
**Objective:** As a 会話と操作文脈の両方を確認したい利用者, I want tool request の痕跡を会話本文とは区別して読める, so that Copilot が何を実行しようとしたかを必要な範囲で把握できる

#### Acceptance Criteria
1. When assistant の本文付き発話に tool request 補助情報が含まれるとき, the Copilot History Application shall その補助情報を assistant 発話内の付帯情報として本文と区別できるようにする
2. When tool request 補助情報が表示対象になるとき, the Copilot History Application shall 少なくとも tool 名と入力要約を確認できる情報を提供する
3. If tool request 補助情報の一部項目が欠けているとき, the Copilot History Application shall 会話本文の表示を阻害せず、識別できる範囲の補助情報だけを保持する
4. If tool execution event が assistant 発話と完全に相関できないとき, the Copilot History Application shall その execution event を主会話ではなく内部 activity として扱う
5. The Copilot History Application shall MVP scope では tool request と tool execution の完全な相関表示を必須にしない

### Requirement 5: 一覧で会話あり session を選べること
**Objective:** As a 履歴一覧から目的の会話を探す利用者, I want 会話本文を持つ session を見分けられる, so that 空または metadata-only の session を開く手間を減らせる

#### Acceptance Criteria
1. When session list が表示されるとき, the Copilot History Application shall 各 session に表示可能な主会話本文が存在するかを利用者が判断できる情報を提供する
2. When session が一つ以上の主会話本文を持つとき, the Copilot History Application shall その会話数を一覧で確認できるようにする
3. Where 会話 preview が提供される場合, the Copilot History Application shall user または assistant の本文から短い preview を提示し、内部 activity を preview の本文として扱わない
4. If current schema の session directory が `workspace.yaml` のみを持ち `events.jsonl` を持たないとき, the Copilot History Application shall 通常の会話 session と区別できるようにする
5. The Copilot History Application shall 会話あり session の識別追加によって degraded session や legacy session の一覧表示を後退させない

### Requirement 6: session 更新時刻の利用者向け補正
**Objective:** As a 最近の会話を探す利用者, I want 実際に会話が追記された session が古く見えにくい, so that 一覧から直近の作業を選びやすい

#### Acceptance Criteria
1. When current schema の session に `events.jsonl` の event timestamp が存在するとき, the Copilot History Application shall session の更新時刻として会話 activity を反映した時刻を利用者に提示できる
2. If event timestamp が利用できないが session file の更新時刻が利用できるとき, the Copilot History Application shall session の更新時刻判断にその情報を利用できる
3. If event timestamp と session file の更新時刻がどちらも利用できないとき, the Copilot History Application shall workspace metadata の更新時刻または作成時刻を fallback として扱う
4. While current と legacy の session が同じ一覧に存在するとき, the Copilot History Application shall 利用者が更新時刻の意味を形式ごとに推測しなくて済む一貫した表示を提供する

### Requirement 7: raw detail の通常閲覧からの分離
**Objective:** As a 通常は会話だけを読みたい利用者, I want 巨大な raw detail が通常閲覧を圧迫しない, so that session detail を軽く読み始められる

#### Acceptance Criteria
1. While 利用者が通常の session detail を閲覧しているとき, the Copilot History Application shall 主会話表示を raw payload の量に依存させない
2. Where raw detail の取得または表示が明示的に要求される場合, the Copilot History Application shall 調査に必要な raw detail を確認できるようにする
3. If raw detail が通常閲覧で省略されるとき, the Copilot History Application shall 主会話 transcript、内部 activity の分類、degraded 状態の判断に必要な情報を失わない
4. The Copilot History Application shall raw detail の分離によって unknown event や部分解釈 event の追跡可能性を失わない

### Requirement 8: 劣化と互換不足の可視化
**Objective:** As an 運用者, I want schema 差分や部分破損の影響範囲を明確に把握したい, so that 空の成功結果や曖昧な表示と混同せずに切り分けできる

#### Acceptance Criteria
1. If current schema の event が部分的にしか解釈できないとき, the Copilot History Application shall 影響を受けた session または event が完全ではないことを識別できるようにする
2. If current schema 互換に起因する unknown shape または読取不足が発生したとき, the Copilot History Application shall 空の成功結果で隠さず、影響範囲を区別できる issue 情報として示す
3. When 劣化を含む session が表示されるとき, the Copilot History Application shall 利用者が読める範囲と信頼できない範囲を判断できる説明を提供する
4. While 一部の event が劣化しているとき, the Copilot History Application shall 読める current / legacy session の閲覧を継続できる
5. The Copilot History Application shall current schema 互換の追加によって legacy `history-session-state` の既存読取体験を後退させない
