# Dependabot アラート通知運用 計画資料

## 目的

GitHub Actions の定時実行により、対象 Severity の Dependabot アラートを検知し、GitHub Issue 登録と Slack 通知 を行う。

一度通知・Issue 登録した脆弱性は State 管理用 Issue に記録し、次回以降の定期実行で重複通知・重複 Issue 登録を避ける。

## 方針

- GitHub Actions の `schedule` で週一実行する。
- 手動確認用に `workflow_dispatch` も有効化する。
- Dependabot alerts API から対象リポジトリの open alert を取得する。
- 対象 Severity は設定値で管理する。初期値は `high` / `critical` を想定する。
- Slack Incoming Webhook URL を使って Slack に通知する。
- 未通知の脆弱性ごとに GitHub Issue を作成する。
- 通知済み・Issue 登録済みの脆弱性 ID は State 管理用 Issue の本文に JSON として保存する。
- Issue 登録・Slack 通知の前に State 管理用 Issue を確認し、未登録の脆弱性のみ処理対象にする。
- 最悪 Issue 登録できていれば対応開始できるため、処理順は `Issue 登録 -> State 更新 -> Slack 通知` とする。
- Slack 通知は補助通知として扱い、失敗しても Issue 登録と State 更新は完了させる。
- Slack 通知は 1 workflow 実行につき 1 回とし、複数の対象アラートがある場合も 1 メッセージにまとめる。

## 全体構成

```text
GitHub Actions schedule / workflow_dispatch
  -> Dependabot alerts API で open alerts を取得
  -> 対象 Severity のみに絞り込み
  -> State 管理用 Issue から通知済み ID を取得
  -> 未通知アラートのみ抽出
  -> GitHub Issue 登録
  -> State 管理用 Issue に通知済み ID を追記
  -> Slack 通知
```

## 実行トリガー

週一実行と手動実行を併用する。

```yaml
on:
  schedule:
    - cron: "15 0 * * 1" # 毎週月曜 00:15 UTC = 日本時間 09:15
  workflow_dispatch:
```

補足:

- GitHub Actions の `schedule` は UTC 基準。
- `schedule` はデフォルトブランチ上の workflow で実行される。
- 毎時 00 分など混みやすい時刻は避け、15 分や 37 分などにずらす。
- `workflow_dispatch` を入れておくと、初回検証や障害時の再実行がしやすい。

## 必要な Secrets

| Secret 名 | 用途 |
| --- | --- |
| `DEPENDABOT_ALERT_PAT` | チーム共通 GitHub アカウントで発行した PAT。Dependabot alerts API と Issues API の操作に使う |
| `SLACK_WEBHOOK_URL` | Slack Incoming Webhook URL |

登録先:

```text
Repository Settings
  -> Secrets and variables
  -> Actions
  -> Secrets タブ
  -> Repository secrets
  -> New repository secret
```

Environment secrets ではなく Repository secrets に登録する。

## 必要な Variables

現時点では必須の GitHub Actions variables はない。

対象 Severity や監視対象 repository を workflow 外から変更したくなった場合に、必要に応じて Repository variables を追加する。

## PAT 認証方針

業務・チーム利用では管理の容易さを優先し、チーム共通の GitHub アカウントを作成して、そのアカウントで発行した PAT を使う。

GitHub Actions では Repository secret に保存した PAT を `GH_TOKEN` として GitHub CLI / REST API に渡す。

```text
GitHub Actions
  -> DEPENDABOT_ALERT_PAT を GH_TOKEN として設定
  -> Dependabot alerts API を参照
  -> GitHub Issue を作成・更新
  -> State 管理用 Issue を更新
```

PAT はチーム共通アカウントに紐づくため、個人の退職・異動・権限変更に左右されにくい。一方で長期利用される secret になるため、権限を最小化し、失効日・ローテーション・保管先を明確にする。

## PAT の権限

Fine-grained PAT を優先する。対象 repository は必要最小限に限定する。

| 権限 | 用途 |
| --- | --- |
| `Dependabot alerts: read` | Dependabot アラート取得 |
| `Issues: read and write` | 通知用 Issue 作成、State 管理用 Issue 読み書き |
| `Metadata: read` | リポジトリ参照に必要 |

注意点:

- PAT は workflow YAML に直書きしない。
- `DEPENDABOT_ALERT_PAT` は GitHub repository secrets または organization secrets に保存する。
- チーム共通アカウントは対象 repository へ必要な権限で参加させる。
- Fine-grained PAT では対象 repository を明示的に選択し、不要な repository への access を付けない。
- Expiration は無期限にせず、運用可能な範囲で期限を設定する。
- token を漏らした可能性がある場合は即時 revoke し、再発行して secret を更新する。
- 複数 repository / organization に展開する場合は、PAT の repository access とチーム共通アカウントの所属・権限を慎重に管理する。

## PAT の導入・設定手順

### 1. チーム共通 GitHub アカウントを用意する

業務利用では個人アカウントではなく、チームで管理する GitHub アカウントを用意する。

手順:

1. チーム共通の GitHub アカウントを作成する。
2. 2FA や recovery code の管理方法をチーム内で決める。
3. 対象 repository または organization にアカウントを追加する。
4. Dependabot alerts の参照と Issue 作成・更新ができる権限を付与する。
5. アカウントの用途、管理者、token ローテーション周期を記録する。

### 2. Fine-grained PAT を発行する

チーム共通アカウントの Settings から fine-grained PAT を発行する。

手順:

1. GitHub の右上アイコンから Settings に移動する。
2. 左メニューの Developer settings を開く。
3. Personal access tokens を開く。
4. Fine-grained tokens を開く。
5. Generate new token を選択する。
6. Token name を入力する。
7. Expiration を設定する。
8. Repository access で対象 repository のみを選択する。
9. Repository permissions を設定する。
10. Generate token を押す。

Repository permissions:

| Permission | Access |
| --- | --- |
| Dependabot alerts | Read-only |
| Issues | Read and write |
| Metadata | Read-only |

補足:

- `Metadata: read` は fine-grained PAT に通常付与される基本権限。
- Dependabot alerts API は fine-grained PAT に対応している。
- Issue 登録と State 管理用 Issue 更新のため、Issues は read/write が必要。
- Classic PAT を使う場合は `security_events` scope と Issue 操作用の scope が必要になるため、原則として fine-grained PAT を使う。

### 3. PAT を secret に登録する

発行した PAT を GitHub Actions secret に保存する。

登録先:

```text
対象 repository
  -> Settings
  -> Secrets and variables
  -> Actions
  -> Secrets タブ
  -> Repository secrets
  -> New repository secret
```

```text
Secret name: DEPENDABOT_ALERT_PAT
Secret value: github_pat_xxxxxxxxxxxxxxxxxxxx
```

注意点:

- 登録先は Environment secrets ではなく Repository secrets。
- PAT は repository に commit しない。
- PAT の値は発行直後しか表示されないため、登録後は再表示できない。
- token を漏らした可能性がある場合は GitHub の token 設定画面で revoke し、再発行する。
- ローテーション時は新 token を発行し、`DEPENDABOT_ALERT_PAT` secret を更新してから旧 token を revoke する。

### 4. Actions で PAT を使う

workflow 内で `DEPENDABOT_ALERT_PAT` を `GH_TOKEN` に渡す。

```yaml
- name: Use team PAT
  env:
    GH_TOKEN: ${{ secrets.DEPENDABOT_ALERT_PAT }}
  run: |
    gh api "/repos/${{ github.repository }}/dependabot/alerts?state=open"
```

複数 repository を対象にする場合は、PAT の repository access と workflow 側の対象 repository 一覧を一致させる。

## State 管理用 Issue

State 管理用 Issue を 1 つ作成し、通知済みの脆弱性を JSON で管理する。

Issue 例:

```text
Title: [bot] Dependabot alert notification state
Labels: bot, dependabot-alert-state
```

Issue body 例:

```json
{
  "version": 1,
  "notified": [
    {
      "key": "owner/repo#123",
      "repository": "owner/repo",
      "alert_number": 123,
      "ghsa_id": "GHSA-xxxx-yyyy-zzzz",
      "cve_id": "CVE-2026-0001",
      "severity": "critical",
      "issue_number": 456,
      "notified_at": "2026-07-01T00:15:00Z"
    }
  ]
}
```

### 通知済み判定キー

基本は以下を組み合わせたキーで管理する。

```text
owner/repo#alert_number
```

理由:

- Dependabot alert には repository 内で一意な `number` がある。
- repository 横断で扱う可能性があるため、`owner/repo` も含める。
- `GHSA ID` や `CVE ID` は同じ脆弱性が複数 dependency / manifest で出る場合があるため、重複判定の主キーにはしない。

## GitHub Issue 登録

未通知の Dependabot アラートごとに Issue を作成する。

Issue title 例:

```text
[Dependabot][critical] package-name in owner/repo
```

Issue body 例:

```markdown
## Dependabot alert

- Repository: owner/repo
- Severity: critical
- Package: package-name
- Manifest: package-lock.json
- Advisory: GHSA-xxxx-yyyy-zzzz
- CVE: CVE-2026-0001
- Alert: https://github.com/owner/repo/security/dependabot/123
- Created at: 2026-07-01T00:00:00Z

## 対応メモ

- [ ] 影響範囲を確認する
- [ ] 修正版へアップデートする
- [ ] テストを実行する
- [ ] Dependabot alert が close されたことを確認する
```

Issue label 例:

- `security`
- `dependabot`
- `severity:critical`

## Slack 通知

Slack Incoming Webhook を使う。

通知内容の例:

```text
High/Critical Dependabot alerts detected: 2

1. [critical] package-name
   Repository: owner/repo
   Manifest: package-lock.json
   Advisory: GHSA-xxxx-yyyy-zzzz
   Issue: https://github.com/owner/repo/issues/456
   Alert: https://github.com/owner/repo/security/dependabot/123

2. [high] another-package
   Repository: owner/repo
   Manifest: requirements.txt
   Advisory: GHSA-aaaa-bbbb-cccc
   Issue: https://github.com/owner/repo/issues/457
   Alert: https://github.com/owner/repo/security/dependabot/124
```

実装上の注意:

- webhook URL は `SLACK_WEBHOOK_URL` secret から読む。
- token や webhook URL をログに出さない。
- Slack 通知は 1 workflow 実行につき 1 回だけ送る。
- 複数の未通知アラートがある場合は、作成した Issue URL と Dependabot alert URL を一覧化して 1 メッセージにまとめる。

## 処理フロー詳細

1. workflow を起動する。
2. `DEPENDABOT_ALERT_PAT` を `GH_TOKEN` として GitHub API / GitHub CLI に渡す。
3. State 管理用 Issue を検索する。
4. State 管理用 Issue がなければ新規作成する。
5. State 管理用 Issue の本文 JSON を読み込む。
6. Dependabot alerts API で open alerts を取得する。
7. 対象 Severity の alert のみに絞り込む。
8. `owner/repo#alert_number` が State に存在する alert を除外する。
9. 未通知 alert が 0 件なら終了する。
10. 未通知 alert ごとに GitHub Issue を作成する。
11. Issue 作成に成功した alert を State に追記する。
12. State 管理用 Issue の本文を更新する。
13. Issue 作成と State 更新が完了した alert を Slack に通知する。
14. Slack 通知に失敗しても、Issue 作成と State 更新が完了していれば処理成功として扱う。

## エラーハンドリング方針

### Issue 作成に失敗した場合

- State 更新は行わない。
- 次回実行時に再処理対象にする。
- 最低限 Issue 登録ができていることを重視するため、Issue 作成失敗時は workflow を failure にする。

### State 更新に失敗した場合

- Issue 作成は完了しているが、次回重複 Issue 登録・重複通知される可能性がある。
- ログで検知できるように workflow を failure にする。
- 将来的には Issue title で既存 Issue を検索して重複 Issue 作成を避ける。

### JSON パースに失敗した場合

- 自動修復せず workflow を failure にする。
- State 管理用 Issue の本文を手動修正する。

### Slack 通知に失敗した場合

- Issue 作成と State 更新はすでに完了しているため、処理全体は成功として扱う。
- 個人リポジトリで Slack Incoming Webhook を用意できない場合でも運用できる設計にする。
- Slack 通知失敗は warning としてログに出す。
- State には通知済みとして記録済みのため、次回実行時に同じ脆弱性を再通知・再 Issue 登録しない。

## 初期実装ステップ

1. Slack Incoming Webhook URL を発行する。
2. GitHub repository secret に `SLACK_WEBHOOK_URL` を登録する。
3. チーム共通 GitHub アカウントを作成または確認する。
4. チーム共通 GitHub アカウントを対象 repository に追加する。
5. チーム共通 GitHub アカウントで fine-grained PAT を発行する。
6. PAT に必要な repository permissions を設定する。
7. GitHub repository secret に `DEPENDABOT_ALERT_PAT` を登録する。
8. PAT の失効日・管理者・ローテーション周期を記録する。
9. State 管理用 Issue を作成する、または workflow 初回実行時に自動作成する。
10. `.github/workflows/dependabot-alert-notify.yml` を作成する。
11. `workflow_dispatch` で手動実行して検証する。
12. Issue 作成、State 更新、Slack 通知を確認する。
13. `schedule` による週一実行を有効化する。

## MVP の対象範囲

含める:

- 単一 repository の Dependabot alert 監視
- `high` / `critical` のみ通知
- Slack 通知
- GitHub Issue 作成
- State 管理用 Issue による重複通知回避
- 手動実行
- 週一実行

含めない:

- Slack の双方向操作
- アラートの自動 dismiss
- Dependabot alert 本体への独自ステータス付与
- AI による影響調査の自動実行

## AI 影響調査の自動化候補

最終目標は、Dependabot alert 検知後に AI が repository 内の利用状況・影響範囲・修正方針を調査し、その結果を Issue に記録すること。

現時点の業務導入前 MVP では、workflow が Dependabot alert ごとに Issue を作成し、人間が必要に応じて Copilot coding agent などへ調査を依頼する運用を想定する。

公式ドキュメント確認時点では、将来の自動化候補は大きく 2 つある。

### 候補 A: Actions から直接 AI 調査を実行する

実現可能性: 可能。ただし実装方式により性質が異なる。

#### A-1. GitHub Actions から Copilot CLI を実行する

GitHub 公式ドキュメントでは、GitHub Actions runner 上で Copilot CLI を install し、`COPILOT_GITHUB_TOKEN` に user token を渡して `copilot -p ... --no-ask-user` を実行する例が示されている。

この方式では、Dependabot alert workflow の中で以下のような処理ができる。

```text
Dependabot alert 検知
  -> Issue 作成
  -> Copilot CLI に「この alert の影響範囲を調査して markdown にまとめる」と依頼
  -> 生成された markdown を Issue comment または Issue body に追記
  -> State 更新
  -> Slack 通知
```

利点:

- workflow 内で同期的に AI 調査結果を受け取りやすい。
- 調査結果をそのまま Issue body / comment / Slack 通知に転記しやすい。
- 既存 workflow の処理順に組み込みやすい。

注意点:

- `GITHUB_TOKEN` ではなく、Copilot CLI 用に使える user token を secret として用意する必要がある。
- 現行方針のチーム共通アカウント PAT を使う場合、そのアカウントに Copilot 利用権限が必要になる可能性がある。
- Copilot 利用権限、課金、組織ポリシー、Actions runner からの実行可否を業務環境で確認する必要がある。
- AI が repository 内で参照・実行できる範囲を `--allow-tool` で慎重に制限する必要がある。
- AI 調査を Dependabot alert 件数分だけ実行すると、実行時間・利用量・コストが増えやすい。

#### A-2. Actions から Copilot cloud agent task API を呼ぶ

GitHub 公式ドキュメントでは、REST API で Copilot cloud agent task を開始できる。エンドポイントは以下。

```text
POST /agents/repos/{owner}/{repo}/tasks
```

必須 parameter は `prompt`。任意で `base_ref`、`model`、`create_pull_request` を指定できる。

ただし、公式ドキュメントでは agent tasks API は user-to-server token のみ対応で、server-to-server token は非対応とされている。

現行 workflow はチーム共通アカウントの PAT で Dependabot alerts API と Issues API を操作する方針のため、Copilot cloud agent task API でも同じ PAT を使える可能性がある。ただし、チーム共通アカウントに Copilot 利用権限があること、対象 repository で Copilot cloud agent が有効であること、PAT の権限が agent task 作成に足りることを別途検証する必要がある。

利点:

- Copilot cloud agent を API 経由で正式に起動できる。
- 将来的に agent task の一覧取得・状態確認と組み合わせて、調査タスク管理を自動化できる。

注意点:

- public preview の API であり、仕様変更リスクがある。
- user-to-server token が必要。業務導入では、チーム共通アカウントの PAT で運用できるか、権限・ライセンス・監査上の扱いを確認する必要がある。
- cloud agent は task / session として非同期に動くため、workflow 実行中に「調査結果 markdown」を即時取得して Issue に書き戻す用途では、Copilot CLI 実行より設計が複雑になる可能性がある。
- `create_pull_request` を使う場合、調査だけでなく branch / pull request 作成まで進む可能性があるため、脆弱性調査用途では prompt と設定を慎重に設計する必要がある。

### 候補 B: Issue 登録をトリガーに Copilot coding agent を呼び出す

実現可能性: 可能。公式ドキュメントでは、Issue 作成時または既存 Issue 更新時に `copilot-swe-agent[bot]` を assignee にし、`agent_assignment` を付ける REST API 例が示されている。

Issue 作成時の概念例:

```json
{
  "title": "Issue title",
  "body": "Issue description.",
  "assignees": ["copilot-swe-agent[bot]"],
  "agent_assignment": {
    "target_repo": "OWNER/REPO",
    "base_branch": "main",
    "custom_instructions": "",
    "custom_agent": "",
    "model": ""
  }
}
```

既存 Issue に後から assignee を追加する API も用意されている。

この方式では、既存 workflow を以下のように拡張できる。

```text
Dependabot alert 検知
  -> Issue 作成
  -> Issue に Copilot coding agent を assign
  -> Copilot が影響調査または修正作業を実行
  -> 人間が agent の出力・PR・コメントを確認
```

利点:

- 現行の「Issue 登録」中心の運用を保ったまま拡張できる。
- Issue 自体が依頼文・Dependabot alert 情報・調査結果の集約点になる。
- 人間が手動 assign している運用を API assign に置き換えやすい。
- `agent_assignment.custom_instructions` に、影響調査観点や期待する出力形式を渡せる。

注意点:

- こちらも user token が必要。現行方針では、チーム共通アカウントの PAT を使えるかを検証する。
- fine-grained PAT を使う場合は、metadata read と actions / contents / issues / pull requests の read/write が必要になる可能性がある。
- Copilot cloud agent が repository で有効かどうかを、GraphQL の `suggestedActors(capabilities: [CAN_BE_ASSIGNED])` に `copilot-swe-agent` が含まれるかで確認する必要がある。
- agent は Issue の assignee として動くため、調査結果がどの artifact に残るか（Issue comment、branch、PR、session log）は運用検証が必要。
- 調査だけを依頼したい場合でも、agent が修正 branch / PR 作成に進む可能性があるため、Issue body と `custom_instructions` で「まず影響調査結果を Issue にコメントし、人間承認前に修正しない」などの制約を明記する必要がある。

### 現時点の推奨方針

業務導入前の次段階としては、候補 B を優先する。

理由:

- 現行 workflow の自然な延長で、Issue 作成後の手動 assign を自動 assign に置き換えられる。
- Dependabot alert ごとの追跡単位が Issue に残る。
- 人間レビューの gate を残しやすい。

一方で、「AI 調査結果を workflow 内で同期的に受け取り、そのまま Issue に追記する」ことを重視する場合は、候補 A-1 の Copilot CLI on Actions が適している可能性がある。

業務導入に向けて追加検証すべき点:

- 業務 organization で Copilot cloud agent が有効化できるか。
- `copilot-swe-agent[bot]` が対象 repository の assignable actor として取得できるか。
- チーム共通アカウントの PAT で Copilot cloud agent / Copilot CLI 連携まで扱えるか。
- PAT の失効・ローテーション・監査ログ確認・権限棚卸しの運用。
- agent に渡す prompt / custom instructions の標準文面。
- agent が作成する branch / PR / comment / session log の実際の挙動。
- Dependabot alert 1 件あたりの実行時間、利用量、料金、失敗時の再実行ルール。

## 将来拡張

- 複数 repository 対応
- repository 一覧を YAML / JSON で管理
- severity のしきい値を workflow input で変更
- Slack メンション先を severity ごとに変更
- 既存 Issue 検索による二重 Issue 作成防止
- チーム共通アカウントの organization 配下での権限管理
- PAT の対象 repository 追加・削除フロー整備
- PAT の定期ローテーションと権限棚卸し
- 対応期限や担当者の自動設定
- 対応済み Issue と Dependabot alert close 状態の同期
- Copilot coding agent への自動 assign
- Copilot CLI on Actions による影響調査 comment の自動追記
- Copilot cloud agent task API による非同期調査 task の作成・状態追跡
- 月次レポート作成

## 参考ドキュメント

- GitHub Actions workflow triggers: https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows
- GitHub Actions secrets: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets
- Managing your personal access tokens: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens
- Permissions required for fine-grained personal access tokens: https://docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens
- Dependabot alerts REST API: https://docs.github.com/en/rest/dependabot/alerts
- Slack Incoming Webhooks: https://api.slack.com/messaging/webhooks
- GitHub Copilot cloud agent: https://docs.github.com/en/copilot/concepts/agents/cloud-agent/about-cloud-agent
- Kick off a task with Copilot agents on GitHub: https://docs.github.com/en/copilot/how-tos/copilot-on-github/use-copilot-agents/kick-off-a-task
- Using Copilot cloud agent via the API: https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/use-cloud-agent-via-the-api
- Automating tasks with Copilot CLI and GitHub Actions: https://docs.github.com/en/copilot/how-tos/copilot-cli/automate-copilot-cli/automate-with-actions
