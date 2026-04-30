# Implementation Plan

- [x] 1. 永続化スキーマの基盤を整える
- [x] 1.1 セッション単位の read model を保存できるスキーマを追加する
  - セッション ID を自然キーとして扱い、同一セッションを重複保存できない永続化単位を用意する。
  - 表示 payload、source metadata、履歴由来日時、作業コンテキスト、件数、劣化状態を保存できる列を用意する。
  - 履歴由来日時は保存レコード自身の作成日時・更新日時と分離し、欠落時も NULL のまま保持できる。
  - 日付順表示や metadata 絞り込みの後続 query が使える index を用意する。
  - 完了時には、migration 適用後の schema snapshot で read model table、unique key、日時列、JSON payload、主要 index を確認できる。
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.5, 3.1, 5.1, 5.2, 5.3, 5.4, 6.2_
  - _Boundary: CopilotSession_

- [x] 1.2 同期実行結果を read model と独立して保存できるスキーマを追加する
  - 実行開始・完了時刻、状態、処理件数、保存件数、skip 件数、失敗件数、劣化件数を保存できる永続化単位を用意する。
  - 失敗概要と劣化概要を session row とは独立して残せるようにする。
  - session 保存前の失敗でも run record が作れるよう、session への外部キーを置かない。
  - 完了時には、migration 適用後の schema snapshot で sync run table、status / started_at index、各 count の default を確認できる。
  - _Requirements: 4.1, 4.2, 4.3, 4.4_
  - _Boundary: HistorySyncRun_

- [x] 2. 保存モデルの契約を実装する
- [x] 2.1 セッション read model の保存 validation を実装する
  - セッション ID、source format、source state、payload、source metadata、indexed timestamp の必須性を検証する。
  - source format と source state は設計で定義された値だけを許可する。
  - 件数は 0 以上の整数として検証し、履歴由来日時は両方欠落しても valid な状態として扱う。
  - 完了時には、保存可能な read model と invalid な read model が model validation で明確に区別される。
  - _Depends: 1.1_
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.4, 2.5, 5.1, 5.2, 5.3, 5.4, 6.2_
  - _Boundary: CopilotSession_

- [x] 2.2 (P) 同期実行結果の保存 validation を実装する
  - running、succeeded、failed、completed_with_issues の状態だけを許可する。
  - running では完了時刻を任意にし、終了状態では完了時刻を必須にする。
  - 各 count は 0 以上の整数として検証し、failure / degradation summary は必要な状態で保持できる。
  - 完了時には、session row が存在しない失敗 run と、部分劣化を含む完了 run を保存できる。
  - _Depends: 1.2_
  - _Requirements: 4.1, 4.2, 4.3, 4.4_
  - _Boundary: HistorySyncRun_

- [x] 2.3 (P) source artifact の fingerprint 生成契約を実装する
  - role ごとの source path から path、更新時刻、size、status を含む比較材料を生成する。
  - すべての artifact metadata を取得できた場合だけ complete を true にする。
  - missing / unreadable な artifact は例外で処理を止めず、不完全 fingerprint として識別できる状態にする。
  - 完了時には、同じ path / 更新時刻 / size からは安定した fingerprint が返り、いずれかが変わると区別できる。
  - _Requirements: 3.2, 3.3, 3.4, 3.5, 3.6_
  - _Boundary: SourceFingerprintBuilder_

- [x] 3. 正規化済みセッションから保存 attributes を作る
- [x] 3.1 既存 presenter の表示 payload を保存 snapshot として再利用する
  - 一覧表示用 payload と詳細表示用 payload を既存の表示 contract から生成する。
  - 詳細 payload は通常表示用の粒度を保存し、raw payload の opt-in 表示とは切り離す。
  - current 形式と legacy 形式のどちらでも共通の payload 保存 contract として扱う。
  - 完了時には、保存 attributes から一覧表示と詳細表示に必要な payload を raw files 再読取なしで参照できる。
  - _Requirements: 2.1, 2.2, 2.3, 2.5, 6.1_
  - _Boundary: SessionRecordBuilder_

- [x] 3.2 セッション属性、source metadata、履歴日時を保存 attributes に写像する
  - source format、source state、作業コンテキスト、選択モデル、件数、劣化状態、issue 数を scalar attributes に写像する。
  - source paths は role keyed の保存可能な値に変換し、fingerprint は source metadata 生成契約に委譲する。
  - 履歴由来の作成日時・更新日時は入力値をそのまま反映し、欠落時に保存レコード日時で補完しない。
  - 完了時には、生成された attributes が read model の validation を通り、builder 自身は保存・upsert・skip 判断を行わない。
  - _Depends: 2.1, 2.3, 3.1_
  - _Requirements: 1.3, 1.4, 1.5, 2.4, 3.1, 5.1, 5.2, 6.1, 6.3_
  - _Boundary: SessionRecordBuilder, SourceFingerprintBuilder_

- [x] 3.3 再生成可能な補助層としての境界を固定する
  - 同じセッション ID の再生成結果で保存済み payload を置き換えられる attributes を提供する。
  - current / legacy の違いを read model contract の中で吸収し、raw files を一次ソースから外す契約を追加しない。
  - fingerprint は比較材料の生成に留め、保存省略・再生成・upsert 判断を行わない。
  - raw files 削除時の自動削除、既存 API の参照元切替、画面導線、検索 UI に関する処理を追加しない。
  - 完了時には、この feature の成果物が後続 sync / query spec から利用できる保存 contract に閉じている。
  - _Depends: 3.2_
  - _Requirements: 1.1, 1.2, 2.3, 3.6, 6.1, 6.2, 6.3, 6.4, 6.5_
  - _Boundary: SessionRecordBuilder, CopilotSession_

- [ ] 4. 保存 contract のテストを追加する
- [ ] 4.1 セッション read model の validation と日付欠落を検証する
  - 必須 payload、source format / state、非負の件数、session ID uniqueness を検証する。
  - 履歴由来日時が両方欠落しても保存可能で、保存レコード日時で暗黙補完されないことを検証する。
  - issue を含む read model の劣化状態と issue 数を検証する。
  - 完了時には、read model validation の成功・失敗条件が model spec で再現できる。
  - _Depends: 2.1_
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.4, 5.1, 5.2, 5.3, 5.4, 6.2_
  - _Boundary: CopilotSession_

- [ ] 4.2 (P) 同期実行結果の validation を検証する
  - 状態ごとの完了時刻ルールと count の非負制約を検証する。
  - session row がない状態でも failed run を保存できることを検証する。
  - 完全成功と部分劣化を別 status として保存できることを検証する。
  - 完了時には、sync run の成功・失敗・部分劣化が model spec で区別される。
  - _Depends: 2.2_
  - _Requirements: 4.1, 4.2, 4.3, 4.4_
  - _Boundary: HistorySyncRun_

- [ ] 4.3 (P) source fingerprint の安定性と不完全状態を検証する
  - 同じ path / 更新時刻 / size で同じ fingerprint が返ることを検証する。
  - 更新時刻または size が変わると fingerprint が区別できることを検証する。
  - missing / unreadable artifact が complete false と artifact status で表現されることを検証する。
  - 完了時には、fingerprint の比較材料と不完全状態が spec で固定される。
  - _Depends: 2.3_
  - _Requirements: 3.2, 3.3, 3.4, 3.5, 3.6_
  - _Boundary: SourceFingerprintBuilder_

- [ ] 4.4 (P) セッション保存 attributes の生成を current / legacy / degraded ケースで検証する
  - current 形式と legacy 形式の正規化済みセッションから共通の保存 attributes が生成されることを検証する。
  - 一覧 payload、詳細 payload、source paths、fingerprint、件数、issue 情報が保存 attributes に含まれることを検証する。
  - 履歴由来日時の欠落が補完されず、日付不明として query 側が識別できる材料を残すことを検証する。
  - 完了時には、builder が保存可能な attributes を返し、raw files 再読取・DB 保存・upsert 判断を行わないことが spec で確認できる。
  - _Depends: 3.2, 3.3_
  - _Requirements: 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.4, 2.5, 3.1, 5.1, 5.2, 6.1, 6.3_
  - _Boundary: SessionRecordBuilder_

- [ ] 4.5 read model の永続化 integration を検証する
  - migration 適用後に unique session ID と日付 / metadata index が利用できることを検証する。
  - current / legacy の保存 attributes を同じ read model table に保存し、payload と source metadata を再読取なしで取得できることを検証する。
  - 同じ session ID の再生成 attributes で既存 row を更新でき、重複 row が作られないことを検証する。
  - 完了時には、後続 query が payload、履歴由来日時、日付不明状態を DB から参照できることが integration spec で確認できる。
  - _Depends: 1.1, 2.1, 3.3, 4.4_
  - _Requirements: 1.1, 1.2, 1.3, 1.5, 2.3, 2.5, 5.1, 5.2, 5.3, 5.4, 6.1, 6.2_
  - _Boundary: CopilotSession, SessionRecordBuilder_

- [ ] 4.6 sync run の永続化 integration を検証する
  - session row が存在しない root failure を failed run として保存できることを検証する。
  - 劣化を含む完了 run と完全成功 run を別状態で取得できることを検証する。
  - run record が session row の有無と独立して運用確認に使えることを検証する。
  - 完了時には、同期実行結果の永続化 contract が integration spec で確認できる。
  - _Depends: 1.2, 2.2, 4.2_
  - _Requirements: 4.1, 4.2, 4.3, 4.4_
  - _Boundary: HistorySyncRun_

- [ ] 5. バックエンド検証を通して実装完了状態を確認する
- [ ] 5.1 DB schema と backend spec suite を標準実行環境で確認する
  - Docker Compose 経由で migration と backend spec を実行し、永続化 schema と保存 contract が同じ環境で通ることを確認する。
  - 必要に応じて backend 品質確認コマンドを実行し、lint / security check / spec の既存標準から外れていないことを確認する。
  - 完了時には、実行した検証コマンドと結果が implementation handoff で報告できる状態になる。
  - _Depends: 4.5, 4.6_
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.4, 2.5, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 4.1, 4.2, 4.3, 4.4, 5.1, 5.2, 5.3, 5.4, 6.1, 6.2, 6.3, 6.4, 6.5_
  - _Boundary: Backend verification_
