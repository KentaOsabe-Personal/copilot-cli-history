# プロジェクト構造

updated_at: 2026-04-27

## 組織方針

このリポジトリは、**サービス単位で責務を分けたモノレポ**として扱います。  
ルートでは開発環境・共有ドキュメント・Kiro の project memory を管理し、実装コードは `frontend/` と `backend/` の内側で完結させるのが基本です。

## ディレクトリパターン

### Frontend アプリ
**Location**: `/frontend/`  
**Purpose**: React SPA の画面・UI テスト・ビルド設定を置く  
**Example**: `src/main.tsx` がエントリーポイント、`src/App.tsx` がルート UI、`src/test/setup.ts` が Vitest 共通設定

### Backend API
**Location**: `/backend/`  
**Purpose**: Rails API、読取ロジック、永続化、API 提供を担う  
**Example**: `app/controllers/api` は薄い HTTP 入口に保ち、`config/` に環境設定、`spec/` に request/lib/support 系のテストを配置する

### Backend domain namespace
**Location**: `/backend/lib/copilot_history/`  
**Purpose**: Copilot 履歴の読取・正規化・API 向け整形を Rails 本体から分離して置く  
**Example**: `api/session_index_query.rb`, `api/presenters/session_detail_presenter.rb`, `types/normalized_session.rb`

### Database bootstrap
**Location**: `/mysql/`  
**Purpose**: MySQL コンテナの初期化に必要なファイルだけを置く  
**Example**: `mysql/init/` を compose から read-only mount して初期投入に使う

### Project memory
**Location**: `/.kiro/steering/`, `/.kiro/specs/`  
**Purpose**: プロジェクト全体の判断基準と、機能ごとの仕様を分けて保持する  
**Example**: steering は横断ルール、specs は個別機能の要件・設計・タスク

## 命名規約

- **Frontend files**: React コンポーネントは `App.tsx` のような PascalCase、テストは `*.test.tsx`
- **Backend files**: Rails 規約に従い、controller は `*_controller.rb`、spec は `*_spec.rb`
- **Ruby constants**: クラス・モジュールは PascalCase
- **Backend service objects**: query / presenter / reader は役割が分かる接尾辞で切る
- **Docs / configs**: 既存ファイル名に合わせ、ルートの運用ドキュメントは用途が分かる名前を優先する

## import / load の整理

```ts
import './index.css'
import App from './App.tsx'
```

```rb
module CopilotHistory
  module Api
    class SessionIndexQuery
    end
  end
end
```

**Frontend**:
- 現状は `src/` 内の相対 import を基本にする
- パスエイリアスはまだ導入していないため、必要になるまでは増やさない

**Backend**:
- Rails の autoload と規約配置を基本にする
- `lib/` 配下は `config.autoload_lib` で読み込む前提に寄せ、手動 require を増やしすぎない
- API 向けの orchestration は `CopilotHistory::Api` 名前空間に集め、controller に整形ロジックを溜めない

## コード構成の原則

### 1. ルートは統合、各サービス配下は独立

Compose、Dockerfile、README、Kiro 関連はルートで管理します。  
一方で、アプリ実装は frontend / backend の責務境界をまたいで混在させません。

### 2. バックエンドは Rails 規約を優先

新しい reader や domain logic を追加するときも、まず Rails 標準の置き場所を検討します。  
共通処理は `lib/` や `concerns/` を使い、無秩序なトップレベル追加を避けます。

### 3. HTTP と履歴ドメインを分離する

request routing と response status は controller が担い、履歴の読取・検索・整形は `lib/copilot_history` に寄せます。  
`query -> presenter -> types` の流れを保ち、UI 向け schema の都合を reader 層へ逆流させません。

### 4. フロントエンドは UI の近くにテストを置く

小さな画面やコンポーネントは、実装ファイルの近くに `*.test.tsx` を置く構成を基本にします。  
グローバルなテスト初期化だけを `src/test/` に切り出します。

### 5. 新しい知識は steering か specs に寄せる

リポジトリ全体に効くルールは `steering` に、機能固有の詳細は `specs` に置きます。  
新しいコードが既存パターンに従うなら、steering を毎回増やす必要はありません。

---
_ファイル一覧ではなく、どこに何を置くべきかという判断パターンを残す_
