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
| `APP_PRIVATE_KEY` | GitHub App の private key。installation access token 発行に使う |
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

| Variable 名 | 用途 |
| --- | --- |
| `APP_CLIENT_ID` | GitHub App の Client ID。`actions/create-github-app-token` で使う |

登録先:

```text
Repository Settings
  -> Secrets and variables
  -> Actions
  -> Variables タブ
  -> Repository variables
  -> New repository variable
```

Environment variables ではなく Repository variables に登録する。

## GitHub App 方針

業務・チーム利用を最終目的とするため、MVP 段階から GitHub App を使う。

GitHub Actions 内で GitHub App の installation access token を発行し、その token を `GH_TOKEN` として GitHub CLI / REST API に渡す。

```text
GitHub Actions
  -> APP_CLIENT_ID と APP_PRIVATE_KEY から installation access token を発行
  -> Dependabot alerts API を参照
  -> GitHub Issue を作成・更新
  -> State 管理用 Issue を更新
```

Fine-grained PAT より初期設定は増えるが、対象 repository と権限を明確に制限でき、個人 token に依存しないためチーム運用に向いている。

## GitHub App の権限

必要な repository permissions の目安:

| 権限 | 用途 |
| --- | --- |
| `Dependabot alerts: read` | Dependabot アラート取得 |
| `Issues: read and write` | 通知用 Issue 作成、State 管理用 Issue 読み書き |
| `Metadata: read` | リポジトリ参照に必要 |

注意点:

- private key は workflow YAML に直書きしない。
- `APP_PRIVATE_KEY` は GitHub repository secrets または organization secrets に保存する。
- `APP_CLIENT_ID` は GitHub repository variables または organization variables に保存する。
- GitHub App は対象 repository のみに install する。
- Webhook は今回の仕組みでは使わないため、GitHub App 作成時に Active を無効化してよい。
- 複数 repository / organization に展開する場合は、GitHub App の install 対象と repository access を慎重に管理する。

## GitHub App の導入・設定手順

### 1. GitHub App を作成する

個人検証では個人アカウント配下、本番では organization 配下に GitHub App を作成する。

手順:

1. GitHub の右上アイコンから Settings に移動する。
2. 左メニューの Developer settings を開く。
3. GitHub Apps を開く。
4. New GitHub App を選択する。
5. GitHub App name を入力する。
6. Homepage URL を入力する。専用サイトがなければ対象 repository URL や organization URL でよい。
7. Webhook は使わないため、Active のチェックを外す。
8. Repository permissions を設定する。
9. Where can this GitHub App be installed? は、個人検証なら `Only on this account`、将来他 organization にも入れる可能性があるなら `Any account` を選ぶ。
10. Create GitHub App を押す。

### 2. GitHub App の権限を設定する

Repository permissions:

| Permission | Access |
| --- | --- |
| Dependabot alerts | Read-only |
| Issues | Read and write |
| Metadata | Read-only |

補足:

- `Metadata: read` は GitHub App に通常付与される基本権限。
- Dependabot alerts API は GitHub App installation access token に対応している。
- Issue 登録と State 管理用 Issue 更新のため、Issues は read/write が必要。

### 3. Private key を発行する

GitHub App の設定画面で private key を generate し、`.pem` ファイルをダウンロードする。

ダウンロードした private key の内容全体を GitHub Actions secret に保存する。

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
Secret name: APP_PRIVATE_KEY
Secret value:
-----BEGIN RSA PRIVATE KEY-----
...
-----END RSA PRIVATE KEY-----
```

注意点:

- `BEGIN` / `END` 行を含めて保存する。
- `.pem` ファイルをアップロードするのではなく、テキストエディタで開いて中身をすべてコピーして貼り付ける。
- 登録先は Environment secrets ではなく Repository secrets。
- private key は repository に commit しない。
- key を漏らした可能性がある場合は GitHub App の設定画面で削除し、再発行する。

### 4. Client ID を登録する

GitHub App の設定画面に表示される Client ID を GitHub Actions variable に保存する。

登録先:

```text
対象 repository
  -> Settings
  -> Secrets and variables
  -> Actions
  -> Variables タブ
  -> Repository variables
  -> New repository variable
```

```text
Variable name: APP_CLIENT_ID
Variable value: Iv1.xxxxxxxxxxxxxxxx
```

補足:

- 登録先は Environment variables ではなく Repository variables。
- `APP_CLIENT_ID` は機密情報ではないため、secret ではなく variable にする。
- `actions/create-github-app-token@v3` では `client-id` が推奨される。
- legacy input として `app-id` も使えるが、資料では `client-id` に統一する。

### 5. GitHub App を repository に install する

GitHub App の設定画面から Install App を選択し、対象アカウントまたは organization に install する。

個人検証では対象 repository のみを選択する。

```text
Repository access: Only select repositories
Selected repositories: 対象 repository
```

### 6. Actions で installation access token を発行する

workflow 内で `actions/create-github-app-token` を使い、短命の installation access token を発行する。

```yaml
- name: Generate GitHub App token
  id: app-token
  uses: actions/create-github-app-token@v3
  with:
    client-id: ${{ vars.APP_CLIENT_ID }}
    private-key: ${{ secrets.APP_PRIVATE_KEY }}

- name: Use GitHub App token
  env:
    GH_TOKEN: ${{ steps.app-token.outputs.token }}
  run: |
    gh api "/repos/${{ github.repository }}/dependabot/alerts?state=open"
```

複数 repository を対象にする場合は、`owner` や `repositories` の指定を検討する。

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
2. `APP_CLIENT_ID` と `APP_PRIVATE_KEY` で GitHub App の installation access token を発行する。
3. 発行した token を `GH_TOKEN` として GitHub API / GitHub CLI に渡す。
4. State 管理用 Issue を検索する。
5. State 管理用 Issue がなければ新規作成する。
6. State 管理用 Issue の本文 JSON を読み込む。
7. Dependabot alerts API で open alerts を取得する。
8. 対象 Severity の alert のみに絞り込む。
9. `owner/repo#alert_number` が State に存在する alert を除外する。
10. 未通知 alert が 0 件なら終了する。
11. 未通知 alert ごとに GitHub Issue を作成する。
12. Issue 作成に成功した alert を State に追記する。
13. State 管理用 Issue の本文を更新する。
14. Issue 作成と State 更新が完了した alert を Slack に通知する。
15. Slack 通知に失敗しても、Issue 作成と State 更新が完了していれば処理成功として扱う。

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
3. GitHub App を作成する。
4. GitHub App に必要な repository permissions を設定する。
5. GitHub App の private key を発行する。
6. GitHub repository secret に `APP_PRIVATE_KEY` を登録する。
7. GitHub repository variable に `APP_CLIENT_ID` を登録する。
8. GitHub App を対象 repository に install する。
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

## 将来拡張

- 複数 repository 対応
- repository 一覧を YAML / JSON で管理
- severity のしきい値を workflow input で変更
- Slack メンション先を severity ごとに変更
- 既存 Issue 検索による二重 Issue 作成防止
- GitHub App の organization 配下への移管
- GitHub App の対象 repository 追加・削除フロー整備
- 対応期限や担当者の自動設定
- 対応済み Issue と Dependabot alert close 状態の同期
- 月次レポート作成

## 参考ドキュメント

- GitHub Actions workflow triggers: https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows
- GitHub Actions secrets: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets
- Registering a GitHub App: https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app
- GitHub App permissions: https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/choosing-permissions-for-a-github-app
- Installing your own GitHub App: https://docs.github.com/en/apps/using-github-apps/installing-your-own-github-app
- GitHub App authentication in Actions: https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/making-authenticated-api-requests-with-a-github-app-in-a-github-actions-workflow
- actions/create-github-app-token: https://github.com/actions/create-github-app-token
- Dependabot alerts REST API: https://docs.github.com/en/rest/dependabot/alerts
- Slack Incoming Webhooks: https://api.slack.com/messaging/webhooks
