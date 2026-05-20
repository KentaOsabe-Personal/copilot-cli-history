# Brief: session-execution-directory-search

## Problem
GitHub Copilot CLI のローカル会話履歴を読み返す利用者は、セッション一覧でどのプロジェクトに対して実行したセッションなのかを素早く判断しにくい。
現状は一覧カードに作業コンテキストが表示される場合でも `repository @ branch` が優先され、実行ディレクトリそのものを確認できないケースがある。

また、検索欄は保存済み `search_text` を使って会話本文、会話 preview、issue 由来の語句を検索できるが、実行ディレクトリが検索対象に含まれていない。
そのため、プロジェクトパスやディレクトリ名を覚えていても一覧を絞り込めない。

## Current State
- current 形式の reader は `workspace.yaml` から `cwd` / `git_root` / `repository` / `branch` を読み取る実装を持つ。
- `copilot_sessions` には `cwd` / `git_root` カラムが存在し、`SessionRecordBuilder` は `NormalizedSession` の値を保存属性に含める契約を持つ。
- 実運用 DB では `cwd` / `git_root` が全て `null` になっているため、実データでメタデータが保存されていない原因を確認する必要がある。
- 一覧 API payload は `work_context.cwd` を返せる shape を持つ。
- 一覧 UI は実行ディレクトリを明示表示していない。
- 検索 projection は現在 `cwd` を含めていない。

## Desired Outcome
- current 形式の同期済みセッションで、実行ディレクトリが保存済み read model の `cwd` として保持される。
- 一覧カードで、実行ディレクトリが project/session 判別用の主要メタデータとして表示される。
- 一覧検索で、実行ディレクトリの一部文字列を使ってセッションを絞り込める。
- 既存の会話本文、preview、issue 検索、日付範囲、同期後再取得の挙動は維持される。

## Approach
正式な Kiro spec として扱い、要件・設計・タスクの承認を経て実装する。

実装方針としては、実行ディレクトリを `search_text` だけに埋め込むのではなく、まず `cwd` / 必要に応じて `git_root` を保存済み read model の正規化メタデータとして保持する。
そのうえで、一覧検索用 projection に `cwd` を含める。これにより、表示と検索の両方が同じ正規化メタデータを根拠にできる。

## Scope
- **In**: current 形式セッションの実行ディレクトリ保存確認・補正、一覧カードでの実行ディレクトリ表示、一覧検索対象への実行ディレクトリ追加、検索フォーム説明の更新、backend / frontend tests
- **Out**: legacy 形式に存在しない実行ディレクトリの推測生成、repository / branch / model 専用フィルタ、検索結果スコアリング、検索語ハイライト、semantic search、外部検索サービス、履歴編集・削除・共有、自動同期

## Boundary Candidates
- read model の作業メタデータ保存契約
- 一覧 summary 表示のメタデータ優先順位
- 一覧検索 projection の対象範囲
- 同期後の古い検索 projection 再生成

## Out of Boundary
- raw files に存在しない legacy セッションの実行ディレクトリを補完または推測すること
- `git_root`、repository、branch、model を今回の一般検索対象へ広げること
- 新しい検索 API、検索 index サービス、DB schema の大幅変更

## Upstream / Downstream
- **Upstream**: current 形式 `workspace.yaml` の `cwd` / `git_root`、`history-db-read-model`、`history-sync-api`、`session-api-db-query`、`session-full-text-search`
- **Downstream**: 将来の repository / branch 専用フィルタ、project grouping、セッション一覧の比較・集約 UI

## Existing Spec Touchpoints
- **Extends**: `session-full-text-search` の検索対象を、実行ディレクトリ `cwd` に限って拡張する
- **Adjacent**: `session-ui-noise-reduction` の「値があるメタデータだけを表示する」方針を維持する

## Constraints
- raw files は一次ソース、保存済み read model は再生成可能な補助層として扱う。
- 通常表示と検索表示は read-only API のまま維持する。
- `cwd` が存在しないセッションでは、不明 placeholder や推測値を表示しない。
- 既存 DB に保存済みの row は、明示同期で再生成される前提を維持する。
