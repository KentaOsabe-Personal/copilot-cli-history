# ユビキタス言語

updated_at: 2026-07-04

この文書は、Copilot CLI 履歴閲覧アプリで使う用語の意味を揃えるための辞書である。
実装名・API 名・仕様書では、ここに定義した意味から外れないようにする。

## 基本概念

| 用語 | 英語 / 実装上の名前 | 定義 | 使用上の注意 |
| --- | --- | --- | --- |
| ローカル履歴 | local history | 利用者の端末上に保存された Copilot CLI の履歴データ。 | 外部サービス上の履歴や共有済み履歴を含めない。 |
| raw files | raw files | Copilot CLI が保存した一次ソースのファイル群。 | アプリ側 DB より正本として扱う。 |
| 履歴ルート | history root | `COPILOT_HOME` または `~/.copilot` から解決される履歴探索の起点。 | ルートが読めない場合は root failure。 |
| セッションソース | session source | 1 つのセッションを読み取るための raw file または file set。 | current / legacy の形式情報を持つ。 |
| セッション | session / Copilot session | Copilot CLI で行われた一連の会話・操作の単位。 | アプリ内では `session_id` で識別する。 |
| セッション ID | session_id | セッションを一意に識別する ID。 | `CopilotSession` の一意キー。 |
| 現行形式 | current | `session-state` 系の保存形式。 | API / UI に形式差分を漏らさない。 |
| 旧形式 | legacy | `history-session-state` 系の保存形式。 | reader 層で現行形式と同じ contract に正規化する。 |

## 読取と正規化

| 用語 | 英語 / 実装上の名前 | 定義 | 使用上の注意 |
| --- | --- | --- | --- |
| 履歴読取 | history reading | 履歴ルートからセッションソースを探し、各セッションを読み取る処理。 | 通常表示 API では実行せず、同期時に閉じ込める。 |
| 正規化 | normalization | current / legacy の差分を吸収し、共通のセッション表現に変換すること。 | UI や controller で形式分岐を増やさない。 |
| 正規化セッション | NormalizedSession | raw files から作られる永続化前の共通セッション表現。 | `events`、`message_snapshots`、`issues`、作業コンテキストを持つ。 |
| イベント | event / NormalizedEvent | セッション内で発生した raw 由来の出来事。 | 表示用には conversation / activity に投影する。 |
| メッセージスナップショット | MessageSnapshot | 会話メッセージの読み取り結果を表す断面。 | 会話 preview や検索 projection の材料になる。 |
| ツール呼び出し | tool call / NormalizedToolCall | セッション中に実行されたツール操作。 | 会話詳細や activity 表示の対象。 |
| 会話投影 | conversation projection | event / message snapshot から会話タイムライン向けに作る表示用構造。 | raw event そのものとは区別する。 |
| アクティビティ投影 | activity projection | ツール実行や操作履歴を時系列表示向けに作る構造。 | 会話本文とは別の閲覧軸。 |
| 読取 issue | ReadIssue | セッション単位で発生した欠損・破損・未知形式などの問題。 | root failure とは区別する。 |

## 状態と失敗

| 用語 | 英語 / 実装上の名前 | 定義 | 使用上の注意 |
| --- | --- | --- | --- |
| complete | complete | セッションが通常どおり読み取れた状態。 | read model に永続化できる。 |
| workspace_only | workspace_only | workspace 情報だけが得られ、表示セッションとしては不十分な状態。 | 現在の同期では永続化対象から除外する。 |
| degraded | degraded | 一部の issue を持つが、読めた範囲は表示可能な状態。 | 失敗ではなく部分劣化として扱う。 |
| root failure | root failure | 履歴ルートの解決や探索自体が失敗した状態。 | セッション単位の issue ではなく同期失敗にする。 |
| 部分劣化 | degradation | セッション単位の破損や欠損により、完全ではないが表示可能な状態。 | `completed_with_issues` や `partial_results` の根拠になる。 |
| 読取失敗 | read failure | raw files の読み取りに関する失敗。 | root failure と session issue のどちらかを明確にする。 |

## 同期

| 用語 | 英語 / 実装上の名前 | 定義 | 使用上の注意 |
| --- | --- | --- | --- |
| 明示同期 | explicit sync / history sync | 利用者操作で raw files を読み、DB read model を更新する処理。 | 自動監視や都度読取とは区別する。 |
| 同期実行 | HistorySyncRun | 1 回の明示同期の実行履歴。 | status と件数を持ち、結果表示と競合制御に使う。 |
| running lock | running_lock_key | 同期の同時実行を防ぐためのロックキー。 | `running` の間だけ存在する。 |
| 同期競合 | sync conflict | 既に実行中の同期があるため、新しい同期を開始しない状態。 | 既存の running run を返す。 |
| succeeded | succeeded | 同期が問題なく完了した状態。 | degraded session がない。 |
| completed_with_issues | completed_with_issues | 同期は完了したが、degraded session が含まれる状態。 | ユーザーに issue の存在を示す。 |
| failed | failed | root failure または永続化失敗で同期全体が失敗した状態。 | partial degradation とは区別する。 |
| inserted | inserted | 新しい `CopilotSession` が作成されたこと。 | `HistorySyncRun.inserted_count` に数える。 |
| updated | updated | 既存の `CopilotSession` が更新されたこと。 | fingerprint や projection version が変わった場合など。 |
| skipped | skipped | 既存 read model が最新と判断され、保存を省略したこと。 | source fingerprint と projection version が判断材料。 |

## Read Model と検索

| 用語 | 英語 / 実装上の名前 | 定義 | 使用上の注意 |
| --- | --- | --- | --- |
| read model | read model | 表示・検索用に DB に保存された再生成可能な投影。 | raw files の代替正本ではない。 |
| 同期済みセッション | CopilotSession | DB に保存されたセッション read model。 | 一覧・詳細 API はこれを参照する。 |
| source fingerprint | source_fingerprint | source paths の状態から作る変更検出用 fingerprint。 | insert / update / skip 判定に使う。 |
| source paths | source_paths | セッションの由来となる raw file path 群。 | 原因追跡と fingerprint の材料。 |
| summary payload | summary_payload | 一覧 API 向けの保存済み JSON payload。 | 一覧表示の contract。 |
| detail payload | detail_payload | 詳細 API 向けの保存済み JSON payload。 | 詳細表示の contract。 |
| conversation preview | conversation_preview | 一覧で見せる会話の短い要約テキスト。 | 検索対象にも含まれる。 |
| 検索 projection | search_text | 会話・preview・issue を検索向けにまとめたテキスト。 | raw files を都度検索しない。`cwd` は API query 側で別条件として検索する。 |
| projection version | search_text_version | 検索 projection の生成規則のバージョン。 | 意味が変わったら再生成が必要。 |
| indexed_at | indexed_at | read model が作成または更新された時刻。 | raw source の作成・更新時刻とは区別する。 |

## 作業コンテキスト

| 用語 | 英語 / 実装上の名前 | 定義 | 使用上の注意 |
| --- | --- | --- | --- |
| cwd | cwd | セッション実行時のカレントディレクトリ。 | 検索や作業文脈の復元に使う。 |
| git root | git_root | セッションが属する Git 作業ツリーの root。 | cwd と同一とは限らない。 |
| repository | repository | セッションに紐づくリポジトリ名または識別情報。 | raw から得られる範囲で扱う。 |
| branch | branch | セッション時点の Git branch。 | 履歴探索の補助情報。 |
| selected model | selected_model | セッションで選択されていたモデル。 | 表示・検索メタデータとして扱う。 |

## API / UI

| 用語 | 英語 / 実装上の名前 | 定義 | 使用上の注意 |
| --- | --- | --- | --- |
| セッション一覧 | session index | 複数セッションを検索・絞り込みして表示する画面または API。 | `summary_payload` を使う。 |
| セッション詳細 | session detail | 1 つのセッションの会話・activity・issue を表示する画面または API。 | `detail_payload` を使う。 |
| 日付範囲 | date range | 一覧の絞り込みに使う from / to 条件。 | source timestamp を基準にする。 |
| 検索語 | search term | 一覧を絞り込む利用者入力。 | `search_text` と `cwd` に対する DB query で扱う。 |
| 部分結果 | partial results | 一覧結果に degraded session が含まれる状態。 | 全体失敗とは表示を分ける。 |
| error envelope | error envelope | API エラーを共通形式で返す JSON contract。 | root failure や not found で利用する。 |

## 避ける表現

- DB を「正本」と呼ばない。正本は raw files。
- degraded を「同期失敗」と呼ばない。同期は完了している可能性がある。
- workspace_only を「通常セッション」と呼ばない。表示対象から除外される可能性がある。
- raw event と会話表示項目を同一視しない。表示は projection。
- 自動更新と明示同期を混同しない。現在のドメインでは同期は利用者操作で始まる。
