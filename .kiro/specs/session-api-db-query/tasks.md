# Implementation Plan

- [x] 1. 保存済み read model API の共通結果とエラー契約を整える
  - 一覧の成功結果、一覧条件不正、詳細の発見結果、未登録結果を HTTP 境界が判別できる形に揃える
  - 未登録詳細は root failure ではなく保存済み read model の未登録状態として扱えるようにする
  - 一覧条件不正は `invalid_session_list_query`、未登録詳細は `session_not_found` として成功応答から区別できる envelope で返せる
  - 保存済み detail payload を見つかった詳細結果としてそのまま運べることを単体テストで確認できる
  - _Requirements: 3.5, 5.1, 5.2, 5.4, 5.5, 5.6, 6.1_

- [x] 2. (P) 一覧条件を query criteria として正規化する
  - `from` と `to` を date または datetime として解釈し、両端を含む比較可能な時刻に正規化する
  - `from` のみ、`to` のみ、両方指定、両方未指定の各条件で、設計どおりの範囲を生成する
  - 両方未指定では要求時点から直近 30 日を既定期間として生成し、片側指定時には未指定側へ既定期間を混ぜない
  - `limit` は正の整数だけを受け入れ、未指定時は件数制限なしとして扱う
  - 不正な日時、逆転範囲、不正な `limit` が成功 criteria ではなく client error として観測できる
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 3.3, 3.4, 3.5, 5.4, 5.5_
  - _Boundary: SessionListParams_
  - _Depends: 1_

- [x] 3. (P) 保存済み read model からセッション一覧を取得する
  - 保存済み summary payload を一覧 item として返し、payload field を再構成せず current と legacy を共通契約で扱う
  - 表示日時は履歴由来の更新日時を優先し、欠落時は作成日時へ fallback し、どちらも欠落した row は日付範囲から除外する
  - 表示日時の降順と session ID の昇順で安定した順序を作り、日付範囲と順序を適用した後に `limit` を適用する
  - read model が空、または範囲一致がない場合でも 200 相当の空データと件数 0 の meta を返せる
  - 返却 payload の degraded 状態から partial result meta を算出し、raw files reader を一覧 request path で呼ばないことを単体テストで確認できる
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.5, 2.6, 2.7, 3.1, 3.2, 3.3, 3.4, 5.3, 6.1, 6.2, 6.4, 6.5_
  - _Boundary: SessionIndexQuery_
  - _Depends: 1_

- [x] 4. (P) 保存済み detail payload からセッション詳細を取得する
  - 指定された session ID と保存済み read model を完全一致で照合する
  - 見つかった場合は保存済み detail payload を詳細 data としてそのまま返し、current と legacy を共通契約で扱う
  - 見つからない場合は `session_not_found` と対象 session ID を持つ未登録結果として返す
  - `include_raw` 相当の要求があっても raw files を再読取せず、保存済み detail payload の範囲だけを返す前提を保つ
  - DB 空状態では一覧と詳細がそれぞれ空成功と未登録詳細に分かれることを単体テストで確認できる
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 5.1, 5.2, 5.3, 5.6, 6.1, 6.2, 6.4, 6.5_
  - _Boundary: SessionDetailQuery_
  - _Depends: 1_

- [x] 5. HTTP session API を保存済み read model の取得経路へ統合する
  - 一覧 request では query 実行前に一覧条件を検証し、不正条件は 400 の error envelope として返す
  - 一覧成功時は保存済み summary payload 群と meta を既存 top-level structure で返す
  - 詳細 request では保存済み detail payload を既存 top-level structure で返し、未登録 session ID は 404 の `session_not_found` として返す
  - `include_raw=true` は互換 query param として受けても raw files 再読取や fallback を発生させない
  - session API は read-only GET の境界に留まり、同期実行、検索、repo / branch / model filter、削除同期を追加しないことが routing と request 挙動で確認できる
  - _Requirements: 1.1, 1.4, 1.5, 3.5, 4.1, 4.4, 4.5, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 6.1, 6.3, 6.4, 6.5_
  - _Depends: 2, 3, 4_

- [ ] 6. API 契約と回帰を検証する
- [ ] 6.1 一覧 API の request contract を保存済み read model 基準で固定する
  - current と legacy の保存済み payload が共通一覧 shape として返ることを確認する
  - read model 空状態、日付範囲、片側範囲、既定直近 30 日、表示日時順、同一日時の session ID 順、`limit` を request spec で確認する
  - 日付不明 row が範囲一致から除外され、不正な `from` / `to` / `limit` が 400 として観測できる
  - degraded と issue 情報が正常データ内に残り、meta の件数と partial result が返却 data と一致する
  - 一覧 API の request spec が raw root failure ではなく DB 空成功を期待する形に更新されている
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 3.1, 3.2, 3.3, 3.4, 3.5, 5.3, 5.4, 5.5, 6.1, 6.2, 6.3, 6.4, 6.5_

- [ ] 6.2 詳細 API の request contract を保存済み detail payload 基準で固定する
  - 保存済み detail payload の header、message snapshots、conversation、activity、timeline、degraded、issue 情報が既存詳細 shape で返ることを確認する
  - current と legacy の詳細が共通契約で返ることを確認する
  - 未登録 session ID が 404、`session_not_found`、対象 session ID の details を返すことを確認する
  - read model 空状態で詳細だけが未登録応答になり、root failure と混同されないことを確認する
  - `include_raw=true` の request でも raw files 再読取を行わず、保存済み detail payload の範囲だけが返ることを確認する
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 5.1, 5.2, 5.3, 5.6, 6.1, 6.2, 6.3, 6.4, 6.5_

- [ ] 6.3 backend の対象 spec と品質ゲートを通す
  - 一覧条件、一覧取得、詳細取得、error envelope、request contract の対象 spec を実行して失敗がない状態にする
  - DB schema 変更や新規 gem なしで実装が完結していることを確認する
  - backend 品質確認コマンドで session API 周辺の regression がないことを観測できる
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 3.1, 3.2, 3.3, 3.4, 3.5, 4.1, 4.2, 4.3, 4.4, 4.5, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 6.1, 6.2, 6.3, 6.4, 6.5_

## Implementation Notes

- Docker Compose の backend service は既定で `RAILS_ENV=development` のため、backend RSpec 検証では `docker compose run --rm -e RAILS_ENV=test backend bundle exec rspec` を使う。
