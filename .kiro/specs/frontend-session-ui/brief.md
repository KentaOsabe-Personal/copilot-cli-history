# Brief: frontend-session-ui

## Problem
GitHub Copilot CLI のローカル会話履歴を参照したい利用者は、現状 backend API があっても画面から履歴をたどれない。  
そのため、セッション一覧から対象の会話を選び、詳細タイムラインを時系列で読める frontend UI が必要である。

## Current State
backend にはセッション一覧 API と単一セッション詳細タイムライン API があり、current / legacy の差分や degraded 情報を含めて read-only で返せる。  
一方 frontend は土台だけがあり、一覧画面、詳細画面、ナビゲーション、タイムライン表示ルールは未実装である。

## Desired Outcome
利用者がブラウザ上でセッション一覧を閲覧し、任意のセッションを選んで詳細タイムラインへ遷移できる。  
詳細画面では会話の流れ、ツール呼び出し、コードブロック、劣化データの有無を識別しながら履歴を読み返せる。

## Approach
URL ベースの一覧/詳細 UI を採用し、frontend を session list page と session detail timeline page に分ける。  
backend-session-api の read-only 契約を使う薄い fetch 層を置き、画面単位の React コンポーネントでレイアウト、ナビゲーション、表示ルールを組み立てる。  
検索、フィルタ、再読み込みは将来拡張に回し、この spec では一覧表示と詳細表示の成立に集中する。

## Scope
- **In**: 一覧画面、詳細タイムライン画面、画面間ナビゲーション、API 呼び出し、長文・ツール呼び出し・コードブロック・degraded 表示の基本ルール
- **Out**: repo / branch / date / model の検索・フィルタ、再読み込み UI、自動更新監視、永続化、認証・認可、backend API 契約の拡張

## Boundary Candidates
- 画面遷移と URL 状態を扱う navigation / routing
- backend-session-api を呼ぶ frontend data access
- セッション一覧の要約情報を表示する list presentation
- セッション詳細タイムラインの表示ルールを担う detail presentation

## Out of Boundary
- raw Copilot 履歴 files の読取や正規化
- HTTP API の契約定義とエラーレスポンス設計
- 検索・絞り込み・更新監視などの探索機能
- MySQL を使う保存・索引・同期戦略

## Upstream / Downstream
- **Upstream**: backend-session-api、backend-history-reader
- **Downstream**: 検索 UI、フィルタ UI、再読み込み UI、将来の永続化や比較表示

## Existing Spec Touchpoints
- **Extends**: なし
- **Adjacent**: backend-session-api の一覧/詳細 API 契約、backend-history-reader の degraded / issue モデル

## Constraints
frontend の技術前提は React 19 / TypeScript / Vite / Vitest / Tailwind CSS 4 を維持する。  
Docker Compose ベースの開発フローに乗せ、backend の read-only API を前提に UI を構築する。  
MVP 境界を守るため、この spec では一覧と詳細タイムラインに必要な UI 以外へ責務を広げない。
