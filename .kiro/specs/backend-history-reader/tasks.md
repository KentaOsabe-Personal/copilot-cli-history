# 実装タスク

- [x] 1. Foundation: 共通契約と fixture ベースの検証基盤を整える
- [x] 1.1 root failure・source descriptor・公開 result の value object と error code を定義する
  - `ReadErrorCode` / `ReadFailure` / `ReadIssue` / `ReadResult` / `ResolvedHistoryRoot` / `SessionSource` が current・legacy 共通の読取境界を表現する。
  - root fatal は `ReadResult::Failure`、session issue は `ReadResult::Success` 内の `NormalizedSession#issues` で識別できる公開契約を固める。
  - 対応する unit spec で `Success` / `Failure` envelope と failure payload の形が固定される。
  - _Requirements: 1.3, 3.4, 5.2_
- [x] 1.2 normalized session / event / message snapshot / normalization result の共通 contract を定義する
  - current / legacy のどちらでも同じ `NormalizedSession` と `NormalizedEvent` shape を組み立てられる。
  - unknown / partial event でも `raw_payload` と `sequence` を保持できる値オブジェクトが揃う。
  - unit spec で canonical events と補助 transcript の役割分離が確認できる。
  - _Requirements: 2.5, 3.2, 3.4, 4.1, 4.2, 4.4_
- [x] 1.3 fixture ベースの spec/lib 構成と current・legacy 履歴サンプル、権限制御 helper を整備する
  - `spec/lib` と `spec/fixtures/copilot_history` に valid / invalid / unreadable 相当の current・legacy シナリオを追加する。
  - mixed root・Docker mount 相当 absolute path・壊れた artifact を再現でき、permission denied を安全に付与・復元する helper を各 spec から使い回せる。
  - fixture support を追加した状態で lib spec から履歴ファイルを raw source として読める。
  - _Requirements: 1.4, 2.3, 2.4, 3.3, 5.2, 5.3_

- [x] 2. Filesystem 境界で履歴ルートと source catalog を確立する
- [x] 2.1 HistoryRootResolver で履歴ルート解決と fatal failure 分類を実装する
  - `COPILOT_HOME` 優先、未設定時 `~/.copilot` fallback、local filesystem 限定の判定を実装する。
  - missing root / unreadable root / permission denied を別 code の `ReadFailure` として返し、Docker mount 済み absolute path も通常 path と同じ成功経路を通す。
  - unit spec で env precedence、default fallback、missing root、permission denied を観測できる。
  - _Requirements: 1.1, 1.2, 1.3, 5.1, 5.2, 5.3_
- [x] 2.2 SessionSourceCatalog で current / legacy の raw source descriptor を列挙する
  - `session-state/<session-id>/` と `history-session-state/*.json` を raw source of truth として検出する。
  - descriptor に format、session_id、artifact path 群を保持し、reader が file-level issue を報告できる入力情報を揃える。
  - unit spec で current only、legacy only、mixed root の列挙結果が安定する。
  - _Requirements: 1.4, 3.1, 5.1, 5.3_

- [ ] 3. Current / legacy session を共通 contract へ正規化する
- [x] 3.1 EventNormalizer で known / partial / unknown event の共通写像を実装する
  - known event から role・content・timestamp 等の共通項目を抽出し、partial mapping では共通項目と raw payload を併存させる。
  - unknown shape でも `kind: :unknown` の `NormalizedEvent` と issue が必ず返り、sequence は入力順のまま保持される。
  - unit spec で current / legacy の known・partial・unknown event が同じ `NormalizationResult` shape になる。
  - _Requirements: 4.1, 4.2, 4.3_
- [x] 3.2 (P) CurrentSessionReader で workspace.yaml と events.jsonl を単一 session に組み立てる
  - `workspace.yaml` から session metadata を抽出し、`events.jsonl` は行順をそのまま canonical `events` として読み込む。
  - invalid YAML、invalid JSONL line、workspace unreadable、events unreadable を `ReadIssue` に落とし込み、読めた event は lossless に残す。
  - current fixture を読んだ結果として metadata・ordered events・issues を持つ `NormalizedSession` が返る。
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 5.2_
  - _Boundary: CurrentSessionReader_
  - _Depends: 1.2, 1.3, 3.1_
- [x] 3.3 (P) LegacySessionReader で legacy JSON を current と同じ session contract へ揃える
  - `sessionId`, `startTime`, `selectedModel`, `timeline`, `chatMessages` を読み取り、`events` と `message_snapshots` に責務分離して格納する。
  - invalid JSON や source unreadable は session 局所の `ReadIssue` とし、unknown timeline entry でも raw payload を落とさない。
  - legacy fixture を読んだ結果として current と同型の `NormalizedSession` が返り、`chatMessages` は補助 transcript として保持される。
  - _Requirements: 3.2, 3.3, 3.4, 5.2_
  - _Boundary: LegacySessionReader_
  - _Depends: 1.2, 1.3, 3.1_

- [ ] 4. 公開 entrypoint と observability を統合する
- [ ] 4.1 SessionCatalogReader を公開 entrypoint として統合する
  - `HistoryRootResolver` → `SessionSourceCatalog` → current / legacy reader の順で orchestrate し、root failure 時は session 読取へ進まない。
  - root fatal は `ReadResult::Failure` に包み直し、成功時は current / legacy 混在の `NormalizedSession` 配列を `ReadResult::Success` として返す。
  - mixed root fixture から 1 回の呼び出しで両形式の session を返し、file-level issue が root failure に昇格しないことを確認できる。
  - _Requirements: 1.3, 3.4, 4.4, 5.1, 5.2_
- [ ] 4.2 SessionCatalogReader 周辺で root failure と session issue のログ境界を実装する
  - `session_id`, `source_format`, `source_path`, `issue_code`, `failure_code` を最低限含む structured log を出し分ける。
  - root failure は error 相当、session issue は warn 相当として扱い、partial success でも caller contract は変えない。
  - spec で fatal failure と partial issue の双方に必要 field と log level の差が現れることを確認できる。
  - _Requirements: 1.3, 2.3, 2.4, 3.3, 5.2_

- [ ] 5. 統合検証で順序保持と実行環境差分の退行を防ぐ
- [ ] 5.1 current / legacy 混在の integration spec を追加する
  - mixed root fixture で current と legacy の両 session が同じ public contract へ収束することを検証する。
  - current line order と legacy timeline index が `NormalizedEvent.sequence` に反映され、unknown / partial event でも raw payload が残ることを観測する。
  - Docker mount 相当の absolute `COPILOT_HOME` でも成功経路が変わらない。
  - _Requirements: 2.2, 3.4, 4.1, 4.2, 4.3, 5.3_
- [ ] 5.2 root failure と session issue の境界を回帰テストで固定する
  - root missing / permission denied は `ReadFailure`、artifact unreadable / parse failure は `ReadIssue` として分離される。
  - sibling session を含む mixed fixture で一部 session の issue が他 session の読取を止めない。
  - 公開境界では raw `ReadFailure` が露出せず `ReadResult` union だけが返る。
  - _Requirements: 1.3, 2.3, 2.4, 3.3, 4.4, 5.2_

## Implementation Notes

- permission denied 系の検証は copied fixture に対して mode を切り替え、チェックイン済み fixture 自体は変更しない。
- `EventNormalizer` は `source_path` を initializer で受け取り、`call(raw_event:, source_format:, sequence:)` の契約を維持したまま `ReadIssue` に artifact path を載せる。
- artifact unreadable の判定は `File.read` 例外待ちではなく mode bit を見る。Docker 内で root 実行だと `chmod 000` でも read が通るため。
