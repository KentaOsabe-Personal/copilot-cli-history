# Requirements Document

## Introduction
GitHub Copilot CLI のローカル会話履歴を読み返す利用者は、セッション一覧と詳細画面で常に表示されるが判断材料になりにくい情報により、会話本文へ素早く辿り着きにくい。

この仕様は、一覧では開く価値のある差分だけを見つけやすくし、詳細では会話本文を最初に読めるようにするため、既定表示から常設ラベル、`不明` プレースホルダー、セッション単位の issue、ツール呼び出し補助情報、`skill-context`、内部 activity のノイズを減らす。

## Boundary Context
- **In scope**: セッション一覧の常設シグナル整理、値があるメタデータだけの表示、current 形式履歴のモデル名表示、詳細画面の conversation-first な初期表示、ツール呼び出し・`skill-context`・内部 activity の既定折りたたみ。
- **Out of scope**: 履歴データの編集・削除・共有、検索・絞り込み・並び替え、手動再読み込み、degraded 判定や issue 生成ルールの変更、生データ表示の見直し、詳細画面全体のレイアウト刷新。
- **Adjacent expectations**: current 形式と legacy 形式の履歴は引き続き同じ閲覧体験で扱われ、破損や欠損の事実は隠さず、利用者が必要に応じて確認できる状態を保つ。

## Requirements

### Requirement 1: 一覧で判断に効くセッションシグナルを優先する
**Objective:** As a ローカル会話履歴を読み返す利用者, I want セッション一覧で例外や差分だけを素早く見分けられる, so that 開くべきセッションをノイズに邪魔されず選べる

#### Acceptance Criteria
1. When 利用者がセッション一覧を表示する, the セッション履歴 UI shall 通常状態だけを示す常設ラベルを一覧カードの既定表示から除外する
2. If セッションが会話本文を持たない, the セッション履歴 UI shall そのセッションが通常の会話付きセッションではないことを一覧カード上で識別できる表示を行う
3. If セッションが部分的な欠損または読取上の制約を持つ, the セッション履歴 UI shall その制約を通常状態のラベルより目立つ例外シグナルとして表示する
4. While セッション一覧が複数形式の履歴を含む, the セッション履歴 UI shall current 形式と legacy 形式の通常セッションを同じ基準の既定表示で扱う
5. The セッション履歴 UI shall 一覧カードの既定表示で内部 activity 数を会話本文より優先される主要シグナルとして扱わない

### Requirement 2: 値があるメタデータだけを表示する
**Objective:** As a ローカル会話履歴を読み返す利用者, I want 不明な作業コンテキストやモデル名を見せられない, so that 実際に利用できるメタデータだけでセッションを判断できる

#### Acceptance Criteria
1. When セッション一覧のメタデータに作業コンテキストが存在しない, the セッション履歴 UI shall 作業コンテキストの項目と不明プレースホルダーを表示しない
2. When セッション詳細のメタデータに作業コンテキストが存在しない, the セッション履歴 UI shall 作業コンテキストの項目と不明プレースホルダーを表示しない
3. When セッション一覧または詳細のメタデータにモデル名が存在しない, the セッション履歴 UI shall モデル項目と不明プレースホルダーを表示しない
4. When セッション一覧または詳細のメタデータに作業コンテキストまたはモデル名が存在する, the セッション履歴 UI shall その値を利用者が読み取れるメタデータとして表示する
5. If 表示可能なメタデータが存在しない, the セッション履歴 UI shall 空のメタデータ領域や不明値だけの領域を残さず画面の読解性を保つ

### Requirement 3: current 形式履歴でもモデル名をセッション情報として読める
**Objective:** As a ローカル会話履歴を読み返す利用者, I want current 形式の履歴でもモデル名を一覧と詳細で確認できる, so that legacy 形式と同じ判断材料でセッションを比較できる

#### Acceptance Criteria
1. When current 形式の履歴がモデル情報を含む, the セッション履歴システム shall そのモデル名をセッション単位のメタデータとして利用可能にする
2. When current 形式の履歴のモデル名がセッション単位のメタデータとして利用可能である, the セッション履歴 UI shall legacy 形式と同じ表示方針でモデル名を表示する
3. If current 形式の履歴がモデル情報を含まない, the セッション履歴システム shall 推測値または不明プレースホルダーを生成しない
4. While current 形式と legacy 形式の履歴が同じ一覧に混在する, the セッション履歴 UI shall モデル名の有無を保存形式ではなく実データの有無に基づいて表示する
5. The セッション履歴システム shall 利用者がモデル名を確認するために詳細な内部データを読む必要がない状態を提供する

### Requirement 4: 詳細画面を conversation-first の初期表示にする
**Objective:** As a ローカル会話履歴を読み返す利用者, I want セッション詳細を開いた直後に会話本文を読める, so that 目的の発話や応答に短時間で辿り着ける

#### Acceptance Criteria
1. When 利用者がセッション詳細を開く, the セッション履歴 UI shall セッション単位の issue 一覧を会話本文より前に展開表示しない
2. When セッション単位の issue が存在する, the セッション履歴 UI shall その存在を必要時に確認できる状態で保持する
3. While 会話本文に発話単位の欠損または issue が存在する, the セッション履歴 UI shall その発話の近くで利用者が問題を識別できる表示を維持する
4. If セッションに表示可能な会話本文が存在しない, the セッション履歴 UI shall 会話本文が読めない理由または制約を利用者が確認できる表示を行う
5. The セッション履歴 UI shall 詳細画面の初期表示で read-only な閲覧境界を維持し、編集・削除・共有操作を追加しない

### Requirement 5: ツール呼び出しと `skill-context` を既定で折りたたむ
**Objective:** As a ローカル会話履歴を読み返す利用者, I want ツール呼び出しの詳細を必要なときだけ開ける, so that 会話の流れを先に読み取れる

#### Acceptance Criteria
1. When セッション詳細の会話本文が初期表示される, the セッション履歴 UI shall ツール呼び出し補助情報を既定で展開表示しない
2. When 会話本文にツール呼び出し補助情報が存在する, the セッション履歴 UI shall 利用者が明示操作でその情報を表示できる手段を提供する
3. When 利用者がツール呼び出し補助情報を表示する, the セッション履歴 UI shall 対象のツール名と関連する補助情報を会話本文と区別して表示する
4. Where ツール呼び出しが `skill-context` である, the セッション履歴 UI shall 詳細な引数や長い補助内容を追加の明示操作まで折りたたんだ状態に保つ
5. If ツール呼び出し補助情報に発話単位の issue が紐づく, the セッション履歴 UI shall 補助情報の既定折りたたみによって issue の存在を完全に隠さない

### Requirement 6: 内部 activity を必要時だけ確認できる表示にする
**Objective:** As a ローカル会話履歴を読み返す利用者, I want 内部 activity を必要なときだけ開ける, so that 詳細画面で会話本文より内部イベントが目立たない

#### Acceptance Criteria
1. When セッション詳細が初期表示される, the セッション履歴 UI shall 内部 activity セクションを既定で展開表示しない
2. When セッションに内部 activity が存在する, the セッション履歴 UI shall 利用者が明示操作で内部 activity を確認できる手段を提供する
3. When 利用者が内部 activity を展開する, the セッション履歴 UI shall activity の内容、時刻、状態、issue を会話本文と区別して表示する
4. If セッションに内部 activity が存在しない, the セッション履歴 UI shall 会話本文より前に空の内部 activity セクションを表示しない
5. While 内部 activity が折りたたまれている, the セッション履歴 UI shall 会話本文の表示順と読解性を維持する
