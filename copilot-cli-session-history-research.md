# GitHub Copilot CLI の会話履歴保存仕様と参照アプリ実装方針

## Executive Summary

GitHub Copilot CLI の会話履歴は、既定では `~/.copilot` 配下に保存され、会話そのものは主に `session-state/<session-id>/events.jsonl` を中心としたセッション単位のファイル群としてローカル保存されます。[^1][^2] 公式ドキュメント上、ここにはプロンプト、Copilot の応答、利用ツール、変更ファイル情報を含む「完全なセッション記録」が入ります。[^2] 保持期間について自動削除ポリシーは明記されておらず、削除されるのはユーザーが `session-state/` を消したときだけで、削除後は past session の再開もできなくなります。[^1][^2]

実装面では、会話履歴参照アプリの一次ソースは `session-state` 配下の raw ファイルに置き、`session-store.db` は存在すれば検索高速化に使う「補助インデックス」として扱うのが最も安全です。[^1][^2] さらに、旧形式の `history-session-state/*.json` も存在し得るため、アプリは新旧両形式を読み分ける互換レイヤーを持つべきです。[^3][^4]

## 1. どこに保存されるか

GitHub Copilot CLI は、設定・ログ・セッション履歴・各種カスタマイズを既定で `~/.copilot` にまとめて保存します。保存ルートは `COPILOT_HOME` 環境変数か `--config-dir` で変更できます。[^1] その配下で、会話履歴の中心となるのは `session-state/` ディレクトリです。公式 docs は `session-state/` を「Session history and workspace data」と説明し、各セッションが session ID ごとのサブディレクトリを持つとしています。[^1]

今回のローカル環境でも、`/Users/osabekenta/.copilot/session-state/dda50c8d-b1d4-4fb7-a283-9459654cfedf/` に現在のセッションが作られており、`workspace.yaml` には `id`、`cwd`、`git_root`、`repository`、`branch`、`created_at`、`updated_at` などのメタデータが入っていました。[^5] その同一ディレクトリには `events.jsonl` が存在し、セッション開始イベント、ユーザーメッセージ、アシスタント応答などが逐次追記されていました。[^6]

## 2. どのような形式で保存されるか

### 2.1 現行形式: `session-state/<session-id>/events.jsonl`

公式 docs は、各セッションが `events.jsonl` を含むと明記しており、これがセッション履歴の event log です。[^1] さらに session data の conceptual docs は、各セッションのファイル群が「complete record of the session」であり、ここから session resume を行うと説明しています。[^2]

実際のローカルファイルを見ると、`events.jsonl` は JSON Lines 形式で、各行が 1 イベントです。`session.start` イベントには `type`、`data`、`id`、`timestamp`、`parentId` が含まれ、`data.context` 内に `cwd`、`gitRoot`、`branch`、`repository`、`hostType` などが入っています。[^6] `user.message` イベントには元の入力内容と変換後コンテキストが入っており、`assistant.message` イベントには表示本文に加えて `toolRequests` のような構造化データも入っていました。[^7]

つまり、会話参照アプリが最低限扱うべき raw source は次の 2 つです。[^1][^5][^6][^7]

| ファイル | 役割 | アプリ上の扱い |
| --- | --- | --- |
| `workspace.yaml` | セッション一覧表示に必要なメタデータ | セッションヘッダ情報として取り込む |
| `events.jsonl` | 会話本文・イベント列・ツール呼び出し履歴 | 一次ソースとして逐次パースする |

### 2.2 補助形式: `session-store.db`

公式 docs は、`~/.copilot/session-store.db` を cross-session data 用の SQLite DB と説明しています。[^1] ただし conceptual docs では、これは raw session files の「subset」であり、`/chronicle` や過去履歴に対する質問応答を支える構造化ストアだとされています。[^2] したがって、会話履歴参照アプリにとって `session-store.db` は「あるなら使う」対象であり、会話履歴の完全再現という観点では source of truth ではありません。[^2]

### 2.3 旧形式: `history-session-state/*.json`

公式 changelog では、`0.0.342` で session logging format が刷新され、新しいセッションは `~/.copilot/session-state` に、旧来セッションは `~/.copilot/history-session-state` に置かれ、`copilot --resume` 時に新形式へ migrate されると明記されています。[^3] 実際のローカル環境にも `history-session-state` が残っており、そこには単一 JSON ファイルがありました。[^4]

その JSON はトップレベルに `sessionId`、`startTime`、`chatMessages`、`timeline`、`selectedModel` を持ち、`timeline` 配列の中に `info` イベントが積まれる構造でした。[^4] したがって、互換性を重視するなら legacy reader も必要です。[^3][^4]

## 3. どの程度の期間保存されるか

公式 docs では、会話履歴はローカルに保存され、特定セッションを消すには対応する `session-state/<session-id>/` ディレクトリを削除し、全履歴を消すには `session-state/` 配下を削除すると説明されています。[^2] `~/.copilot` の構成説明でも、`session-state/` を削除すると「session history が失われ、past sessions を resume できなくなる」とされています。[^1]

この記述から読み取れる事実は次のとおりです。[^1][^2]

1. **自動削除の保持期間は公式に示されていない。**
2. **既定ではローカルに残り続ける前提で設計されている。**
3. **削除は手動で行う。**
4. **削除後、必要に応じて `session-store` 側は reindex が必要になる。**

したがって、実務上の結論は「保持期間は期限ベースではなく、ユーザーが明示削除するまで」です。[^1][^2]

## 4. 参照・再開・共有に関する公式機能

GitHub Copilot CLI には、保存済み会話履歴を利用する公式機能がすでにあります。`copilot --continue` や `copilot --resume`、対話中の `/resume` で過去セッションを再開できます。[^8] また `/share file [PATH-TO-FILE]` で現在セッションの会話を Markdown にエクスポートできます。[^8] 実験機能を有効にすると `/chronicle` で standup/tips/improve/reindex が利用でき、過去セッションに関する自然言語質問にも応答できます。[^2][^8][^9]

ただし、これらは「CLI から使うための機能」であり、外部アプリ向けの安定した公開ローカル API ではありません。[^2][^8][^9] したがって、アプリ実装では CLI UI の自動操作よりファイル読取ベースの方が安定します。[^1][^2]

## 5. 会話履歴参照アプリの実現方法

## 5.1 推奨方針

**推奨は「ローカルファイル直接読取 + 独自インデックス」方式です。** 根拠は、公式 docs が raw session files を complete record とし、`session-store.db` を subset と位置づけているためです。[^2]

アプリの責務を分解すると次の構成になります。

```text
COPILOT_HOME or ~/.copilot
├── session-state/
│   └── <session-id>/
│       ├── workspace.yaml
│       ├── events.jsonl
│       └── ...
└── history-session-state/
    └── *.json

            │
            ▼
  Format adapters
  - current JSONL reader
  - legacy JSON reader
  - optional session-store reader

            │
            ▼
  Normalized app database
  - sessions
  - events
  - messages
  - tool_calls
  - attachments / artifacts

            │
            ▼
  UI / API
  - セッション一覧
  - 会話タイムライン
  - 全文検索
  - フィルタ (repo / branch / date / model)
```

## 5.2 MVP でやるべきこと

### A. Config root 解決

1. `COPILOT_HOME` を優先し、なければ `~/.copilot` を使う。[^1]
2. `session-state/` と `history-session-state/` の両方をスキャンする。[^1][^3]

### B. 現行形式 reader

1. `workspace.yaml` を読んでセッションの基本情報を取る。[^5]
2. `events.jsonl` を 1 行ずつストリームパースする。[^1][^6]
3. `type` で振り分けて、少なくとも `session.start`、`user.message`、`assistant.message` を正規化する。[^6][^7]
4. 将来の形式変更に備え、生イベント JSON も丸ごと保持する。[^3]

### C. 旧形式 reader

1. `history-session-state/*.json` を検出する。[^3][^4]
2. `timeline` 配列を読み、legacy event を normalized event に変換する。[^4]
3. 旧形式は read-only とし、新形式への自動書換えは CLI に任せる。[^3]

### D. アプリ側 DB

以下のようなテーブルで十分に始められます。

| テーブル | 主なカラム | 用途 |
| --- | --- | --- |
| `sessions` | `id`, `source_format`, `cwd`, `git_root`, `repository`, `branch`, `created_at`, `updated_at`, `summary` | 一覧表示 |
| `events` | `id`, `session_id`, `parent_id`, `timestamp`, `type`, `raw_json` | 完全イベント保存 |
| `messages` | `event_id`, `role`, `content`, `transformed_content` | 会話表示・全文検索 |
| `tool_calls` | `event_id`, `tool_call_id`, `name`, `arguments_json` | ツール履歴表示 |

### E. 更新検知

`events.jsonl` は append-only 的に増えるため、watcher で監視して増分取り込みしやすいです。[^1][^6] ただし書込途中の不完全 JSON 行を読む可能性があるので、行末未完了時は再試行する設計が必要です。これは docs ではなく JSONL tail 実装上の一般的配慮ですが、この用途ではほぼ必須です。

## 5.3 `session-store.db` の位置づけ

`session-store.db` は公式には cross-session search や `/chronicle` を支える SQLite ですが、raw session files の subset です。[^1][^2] そのため、使い方は次のように割り切るのが安全です。

| 使い方 | 推奨度 | 理由 |
| --- | --- | --- |
| これだけを読んで会話履歴 UI を作る | 低い | subset であり完全履歴ではない[^2] |
| 検索インデックスや集計の高速化に使う | 高い | structured data としては便利[^1][^2] |
| 存在しない場合は raw files だけで動くようにする | 必須 | docs 上も top-level items は on-demand 作成がある[^1] |

## 5.4 `/share file` ベースの代替案

CLI の `/share file` は現在セッションを Markdown に書き出せるため、「手動エクスポートされた履歴を読むビューア」を作るだけならこれでも成立します。[^8] ただしこの方式は、リアルタイム性・構造化検索・過去全セッション自動収集の点で弱く、会話履歴ブラウザ用途の第一候補にはなりません。[^8]

## 6. 実装上の注意点

### 6.1 機密性

公式 docs は、session data がローカルに保存され、ユーザーアカウントからアクセス可能であると説明しています。[^2] 同時に、過去履歴に関する質問や `/chronicle` 実行時には、その session data が通常の Copilot CLI と同様に AI model に送られ得るとも書かれています。[^2] 参照アプリを作る場合も、**まずローカル限定の閲覧アプリとして実装し、外部送信は明示 opt-in にする**のが妥当です。[^2]

### 6.2 形式変更耐性

公式 changelog は、保存形式が実際に刷新されたことを示しています。[^3] よって、`events.jsonl` の内部 schema は「非公式内部形式」と見なし、次を守るべきです。

1. 不明 event type を捨てず `raw_json` に残す。[^3][^6][^7]
2. reader を versioned adapter に分ける。[^3]
3. source file path と parser version を DB に保存する。これは将来 migration を楽にするための設計判断です。

### 6.3 旧形式互換

legacy `history-session-state` はすでに実機にも残っており、changelog 上も移行対象です。[^3][^4] したがって、初期版から新旧両対応にしておく価値があります。[^3][^4]

## 7. 推奨結論

最も現実的で壊れにくい方法は、**`~/.copilot` 配下を直接読み、`session-state/<id>/events.jsonl` を一次ソース、`workspace.yaml` をメタデータ、`history-session-state/*.json` を旧形式互換として扱うローカル専用アプリ**です。[^1][^2][^3][^4][^5][^6][^7]

そのうえで、`session-store.db` が存在する場合だけ検索・集計の高速化に利用し、CLI の `/share file` は人に渡すための export 機能として補助的に扱う、という構成が最もバランスが良いです。[^1][^2][^8]

## Confidence Assessment

- **高い確度で確定していること**: 既定保存先が `~/.copilot` であること、会話履歴の中心が `session-state` であること、各セッションが complete record として保存されること、`session-store.db` が subset であること、手動削除前提であること、`/resume`・`/share file`・`/chronicle` が公式機能として存在すること。[^1][^2][^8][^9]
- **高い確度で観測できたこと**: 現行セッションでは `workspace.yaml` と `events.jsonl` が存在し、`events.jsonl` が JSONL の event stream であること、旧形式 `history-session-state/*.json` が単一 JSON であること。[^4][^5][^6][^7]
- **推論を含むこと**: 参照アプリの最適設計、`session-store.db` を補助インデックス扱いにする設計、raw JSON を保存して schema 変更に備えるべきという提言。これらは docs と観測事実に基づく設計判断ですが、GitHub が外部アプリ向けに安定 schema を保証しているわけではありません。[^1][^2][^3]

## Footnotes

[^1]: GitHub Docs, “GitHub Copilot CLI configuration directory,” https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference
[^2]: GitHub Docs, “About GitHub Copilot CLI session data,” https://docs.github.com/en/copilot/concepts/agents/copilot-cli/chronicle
[^3]: [github/copilot-cli](https://github.com/github/copilot-cli/blob/283f6fc340bf95892c9709fcf5cc4d3b2a239e0e/changelog.md#L1525-L1528)
[^4]: `/Users/osabekenta/.copilot/history-session-state/session_ea8fde27-f09c-4c6e-9553-7f9b8c882d22_1760150550820.json:1-50`
[^5]: `/Users/osabekenta/.copilot/session-state/dda50c8d-b1d4-4fb7-a283-9459654cfedf/workspace.yaml:1-10`
[^6]: `/Users/osabekenta/.copilot/session-state/dda50c8d-b1d4-4fb7-a283-9459654cfedf/events.jsonl:1-7`
[^7]: `/Users/osabekenta/.copilot/session-state/dda50c8d-b1d4-4fb7-a283-9459654cfedf/events.jsonl:6-8`
[^8]: GitHub Docs, “Using GitHub Copilot CLI session data,” https://docs.github.com/en/copilot/how-tos/copilot-cli/chronicle
[^9]: GitHub Docs, “GitHub Copilot CLI command reference,” https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference

