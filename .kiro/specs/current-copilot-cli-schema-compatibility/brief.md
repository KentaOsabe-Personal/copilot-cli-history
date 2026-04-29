# Brief: current-copilot-cli-schema-compatibility

## Problem
Copilot CLI の現行 `events.jsonl` schema が、このリポジトリで前提にしている flat な fixture / 正規化 / 表示ルールとずれている。  
そのため、実機に近い current schema の履歴を読むと、会話本文、tool request、system / hook / turn 系イベントの扱いが不正確になり、履歴を安全に読み返すというプロダクト価値が損なわれる。

## Current State
既存の `backend-history-reader`、`backend-session-api`、`frontend-session-ui` はそれぞれ承認済みで、reader / API / UI の責務分離も明確である。  
一方で、現行 schema への追従は各層をまたいで同時に必要になっており、単一の責務として管理しないと fixture 更新、canonical field の整合、新旧形式共存の回帰条件が散らばりやすい。

## Desired Outcome
現行 Copilot CLI schema の `user.message` / `assistant.message` / `system.message`、`data.content`、`data.toolRequests`、`assistant.turn_*` / `tool.execution_*` / `hook.*` / `skill.invoked` などを前提に、backend と frontend が同じ互換方針で動作する。  
同時に、legacy `history-session-state` 互換は維持され、UI の主タイムラインには会話理解に必要な情報を優先表示しつつ、非会話イベントは raw detail や debug 扱いへ安全に退避できる。

## Approach
既存の layer spec を作り直さず、Phase 6 専用の薄い統合 spec を追加する。  
この spec 自体は reader / API / UI の基礎責務を再定義せず、現行 schema 互換に必要な cross-cutting な判断だけを持つ。具体的には、canonical field の整合、fixture 更新方針、新旧共存の回帰条件、非会話イベントの表示方針を束ね、実装先は既存モジュールに委譲する。

## Scope
- **In**: current schema の event type 認識、`data.content` / `data.toolRequests` の扱い、会話イベントと非会話イベントの分類方針、presenter / frontend 間の canonical field 整合、current schema fixture 更新、legacy 互換の回帰条件
- **Out**: `backend-history-reader` / `backend-session-api` / `frontend-session-ui` の基礎責務の再定義、Phase 7 の永続化設計、検索・監視、自動更新、詳細な debug UI 拡張、外部共有機能

## Boundary Candidates
- 現行 schema の event shape を canonical field に落とす統合互換ルール
- current / legacy を共存させる fixture と回帰条件の統一
- UI 主表示と raw / debug detail の責務分離

## Out of Boundary
- 履歴 reader の履歴ルート解決や legacy 基盤読取そのもの
- read-only API の一覧 / 詳細という基礎契約そのもの
- セッション一覧 / 詳細 UI のナビゲーションやレイアウトそのもの
- MySQL 正規化ストアや増分取り込み戦略

## Upstream / Downstream
- **Upstream**: `backend-history-reader` の正規化済みイベント、`backend-session-api` の詳細レスポンス契約、現行 Copilot CLI の `events.jsonl` 保存形式
- **Downstream**: Phase 7 の永続化設計、将来の検索・絞り込み、debug / raw detail の拡張表示

## Existing Spec Touchpoints
- **Extends**: `backend-history-reader` の current event 正規化詳細、`backend-session-api` の session detail presenter 契約、`frontend-session-ui` の timeline 表示ルール
- **Adjacent**: `backend-history-reader` が持つ format 差分吸収責務、`backend-session-api` が持つ共通契約責務、`frontend-session-ui` が持つ read-only 閲覧責務

## Constraints
この spec は統合判断のみを扱い、既存 spec の承認済み責務境界を壊さない。  
raw files を正本とする前提を保ち、unknown event や partially normalized event を捨てず raw payload を保持する。  
Markdown の主表示は会話理解を優先し、`transformedContent` や非会話イベントは必要時の詳細情報として扱う。  
Docker Compose 前提の既存 test / lint / build 導線を維持し、current schema と legacy schema の両方を回帰で守る。
