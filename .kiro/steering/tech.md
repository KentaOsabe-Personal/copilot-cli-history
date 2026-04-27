# 技術スタック

updated_at: 2026-04-27

## アーキテクチャ

このリポジトリは、**frontend / backend / MySQL を Docker Compose で束ねるモノレポ**です。  
フロントエンドは React ベースの SPA、バックエンドは Rails API、データ永続化は MySQL という責務分離を基本にします。

## コア技術

- **Frontend**: React 19 / TypeScript 6 / Vite / Vitest / Tailwind CSS 4
- **Backend**: Ruby 4 / Rails 8.1 API mode / RSpec
- **Database**: MySQL 9.7
- **Runtime / Dev Env**: Docker Compose をローカル開発の正本とする

## 主要ライブラリと役割

- **Vite**: フロントエンドの高速な開発サーバーとビルド
- **Vitest + Testing Library**: UI の振る舞いをテストで確認する
- **Tailwind CSS**: 画面試作と UI 実装を素早く進める
- **RSpec Rails**: バックエンドの API / lib / request spec を支える
- **Rack CORS**: SPA と Rails API の分離を保ったままローカル接続を許可する
- **RuboCop / bundler-audit / Brakeman**: Ruby 側のスタイル・依存関係・セキュリティを継続確認する

## 開発標準

### 型安全性

- フロントエンドは TypeScript を前提にし、`noUnusedLocals` や `noUnusedParameters` などの厳しめ設定を使う
- バックエンドは Rails の規約とテストで整合性を支えつつ、暗黙の契約を増やしすぎない

### コード品質

- フロントエンドは ESLint ベースで保守する
- バックエンドは `rubocop-rails-omakase` を基準にする
- Ruby 側は `bin/ci` に lint / dependency audit / static analysis を集約する

### テスト

- フロントエンドは `pnpm test` で Vitest を実行する
- バックエンドは `bundle exec rspec` を使い、`spec/requests` や `spec/lib` を軸に確認する
- ローカル実行は Docker Compose 経由を標準にし、環境差分を減らす

## 開発環境

### 必須ツール

- Docker / Docker Compose
- Node.js 系ツールはコンテナ内の pnpm を前提に扱う
- Ruby / Bundler もコンテナ内実行を基本にする

### 共通コマンド

```bash
# 開発環境起動
docker compose up --build

# フロントエンド lint / build / test
docker compose run --rm frontend pnpm lint
docker compose run --rm frontend pnpm build

# フロントエンドテスト
docker compose run --rm frontend pnpm test

# バックエンド品質確認
docker compose run --rm backend bin/ci

# バックエンドテスト
docker compose run --rm backend bundle exec rspec
```

## 重要な技術判断

### 1. Docker Compose を開発の正本にする

ルートの `docker-compose.yml` と各 Dockerfile を基準に、サービス間接続・ポート・依存関係を揃えます。  
ローカルに個別セットアップ手順を増やすより、まず Compose で再現できる状態を優先します。

### 2. Rails は API 専用で使う

`config.api_only = true` を有効にし、バックエンドは UI を持たない JSON API として整理します。  
表示責務は React 側に寄せ、バックエンドは読取・正規化・提供に集中させます。

### 3. フロントエンドは軽量な SPA 基盤を保つ

Vite + React + TypeScript を中心に、初期段階では過度な抽象化や巨大な状態管理を持ち込みません。  
履歴一覧や詳細表示に必要な UI を、小さな部品から積み上げます。

### 4. 品質確認は既存ツールに寄せる

新しい独自フローを増やすより、frontend は ESLint / Vitest、backend は RSpec / RuboCop / Brakeman / bundler-audit を活用します。  
既存コマンドに乗ることを優先し、判断基準を散らさないようにします。

### 5. current / legacy を共通 contract に正規化する

履歴 reader は保存形式ごとの差を読み取り層で吸収し、API から見える shape は共通化します。  
UI や controller で format 分岐を増やすより、`copilot_history` 配下の query / presenter / type に寄せます。

### 6. root failure と partial degradation を分けて返す

履歴ルートが読めないときは共通 error envelope で失敗を返し、個別セッションの破損は degraded と issue 一覧に閉じ込めます。  
「全部失敗」か「一部だけ壊れているか」を API 契約で区別するのが前提です。

---
_依存関係の一覧ではなく、開発判断に効く技術上の前提と標準を残す_
