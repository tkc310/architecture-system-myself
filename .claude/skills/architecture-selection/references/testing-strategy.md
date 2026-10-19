# テスト戦略

この文書は、フロントエンド／アプリケーションのテスト方針を定義する。テストの粒度、ツール選定、実行方針について、AI 駆動開発を前提にした実践的なガイドラインを示す。

## テストの粒度とツール

### ユニットテスト

**ツール**: Vitest

**対象**:
- 依存関係のない純粋関数
- 複雑なロジック単体
- ビジネスロジックの単体検証

**方針**:
- 実装詳細に過度に依存しない
- 必要最小限に留める（Testing Trophy の考え方に基づく）

### 統合テスト（コンポーネント単位）

**基本構成**: Vitest + React Testing Library + happy-dom

**対象**:
- 複数のコンポーネントが協調して動作する部分
- ユーザーインタラクションを含むコンポーネントの振る舞い
- 状態管理とコンポーネントの統合

**方針**:
- Testing Trophy の中核として、最大のボリュームゾーンとする
- ユーザーが見る・操作する部分（テキスト、ロール、インタラクション）に基づいてテストを書く
- happy-dom を基本とする。小規模な統合テストでは jsdom より約 3 割速かった（下の「判断根拠」）

**例外**: 以下のケースでは Vitest Browser Mode を使用
- 実ブラウザの挙動が必要なテスト
- レイアウト、フォーカス、CSS の正確な検証が必要な場合
- happy-dom で実装されていない DOM API に依存する場合

### フロントエンド E2E

**ツール**: Playwright

**対象**:
- ユーザーフロー全体の検証
- フロントエンド・バックエンド・DB の統合動作
- ビジネスクリティカルなフロー（ユーザー登録〜ログイン〜主要機能の利用など）

**方針**:
- 少数精鋭：2〜5 個のクリティカルフローに絞る
- それ以外の UI 検証は統合テストか Storybook で対応
- **CI には含めず**、アドホックに手動実行できるようにする（実行コストが高いため）

### VRT（Visual Regression Testing）

**ツール**: Vitest + Storybook

**対象**:
- コンポーネントのストーリー単位
- ページ単位のビジュアル検証
- UI の見た目の回帰検出

**方針**:
- コンポーネントカタログとしての Storybook の活用
- **CI には含めず**、アドホックに手動実行できるようにする（実行コストが高いため）

### API のテスト

**ユニットテスト**: Vitest
- API ハンドラーのロジック単体
- バリデーション処理
- ビジネスロジック

**統合テスト**: Vitest + Testcontainers（推奨）
- データベース連携を含む API の動作
- 外部サービスとの統合（MSW でモック可能な場合は MSW を使用）

### アプリケーション全体の E2E

**ツール**: 
- Playwright Test Agents（基本）
- TesterArmy E2E（より壊れやすいシナリオ向け）

**対象**:
- アプリケーション全体を通したエンドツーエンドのフロー
- 本番に近い環境での動作検証

**方針**:
- **CI には含めず**、アドホックに手動実行できるようにする
- `make test-e2e` で個別に実行できるようにする(中身は package.json の scripts。[規約](./coding-conventions.md#コマンドは-make-で叩く))

## 実行方針

### CI で実行するテスト

**必須**:
- ユニットテスト
- 統合テスト（コンポーネント単位）
- API のユニットテストと統合テスト

これらのテストは、高速で決定的（deterministic）であり、マージゲートとして機能する。

### 手動実行するテスト

**アドホック実行**:
- フロントエンド E2E（Playwright）
- VRT（Vitest + Storybook）
- アプリケーション全体の E2E（Playwright Test Agents / TesterArmy）

**理由**:
- 実行コストが高い
- 環境依存の要素が多い
- フィードバックサイクルが長い

**実装**:
```json
{
  "scripts": {
    "test": "vitest",
    "test:unit": "vitest run",
    "test:integration": "vitest run",
    "test:e2e": "playwright test",
    "test:e2e:headed": "playwright test --headed",
    "test:vrt": "npm run storybook:build && npm run test-storybook",
    "test:ci": "vitest run"
  }
}
```

## AI 駆動開発における注意点

### テストファーストでエージェントをガイド

- エージェントにコードを書かせる前に、期待する振る舞いを記述したテスト（またはテスト要件）を先に与える
- エージェントの出力をコンパクトかつ検証可能に保つ

### Flaky Test（不安定なテスト）の防止

エージェントが生成したテストは、以下の問題を起こしやすい：

- **固定 sleep**: `await page.waitForTimeout(1000)` のようなハードコードされた待機
- **非決定的セレクター**: 不安定な CSS セレクター、動的 ID 依存
- **共有状態**: テスト間で DB やセッションを共有し、並列実行で衝突
- **暗黙の待機**: 非同期アクションの完了を確認せず、即座にアサート

**対策**:
- 条件ベースの待機（`waitForSelector`, `waitForLoadState('networkidle')`, `waitFor(() => expect(...))` など）を使う
- テストデータを各テストで独立してシード・クリーンアップ
- 並列実行前に、新しいテストを同じ環境で 10 回繰り返し実行して不安定性を検出
- E2E テストは決定的で再現可能なものだけをマージゲートに置く

### 過度なモックの回避

- エージェントは過度にモックを使う傾向がある
- モックは実装とモックが同期しなくなると、テストは偽陽性を生む
- 統合テストでは可能な限り実 DB や Docker 化された実サービスを使う
- 外部 API のみ MSW でモック

## 決定性の確保

### 環境分離

- 各テストは独立したデータセット（ユーザー、商品、注文など）を持つ
- テスト間で共有状態を持たない

### シード・クリーンアップ

- テストの最初に DB をシードし、最後にクリーンアップする
- または、各テストごとに新しいコンテナ環境を起動する

### 安定なセレクター

- `data-testid` 属性、ARIA role、安定したテキストラベルを使う
- CSS クラスや動的 ID に依存しない

## カバレッジ

**必須**:
- 業務ロジックを含む層に対してカバレッジの閾値を設定（L の場合: `domain/` と `application/`、S と M の場合: command / query / service）
- 目安は行カバレッジ 80%（サービスごとの値を ARCHITECTURE.md に記載）
- 全体の数値ではなく、業務ロジックを含む層に絞って測定

**理由**:
- カバレッジ 100% は不要
- クリティカルパス・複雑なロジック・頻繁に変更される部分を優先的にカバー
- UI や生成コードのテストで数値を満たすことを避ける

## 参考資料

### 判断根拠: 統合テストの実行環境(2026-10-08 の測定)

統合テスト 11 ケース(フォームとリストのコンポーネント)を、3 つの構成で 5 回ずつ実行し、ウォームアップを除いた中央値を比べた(Node.js 22.14、Vitest 5.0.3、Linux)。

| 構成 | Vitest の所要時間 | 実時間 | 結果 |
| --- | --- | --- | --- |
| RTL + jsdom | 1.20 s | 1.62 s | 通過 |
| Vitest Browser Mode(headless Chromium) | 1.52 s | 2.02 s | 通過 |
| Browser Mode + `isolate: false` などの高速化 | — | — | テスト間で DOM の状態が残って失敗 |
| RTL + happy-dom | 0.816 s | 1.23 s | 通過(採用) |

- happy-dom は jsdom より約 3 割速く、3 構成で最も速かった。テスト間の干渉もなかった。
- Browser Mode は、ブラウザの起動などの固定費で jsdom より遅い。速さではなく、実ブラウザでの正確さ(レイアウト、フォーカス、CSS、ブラウザの API)が要るテストにだけ使う。
- happy-dom は DOM API の実装が jsdom より不完全な部分がある。実装されていない API に依存するテストは、Browser Mode か jsdom で実行する。
- `isolate: false` などの高速化は、テスト間の独立性を損なうので使わない。

### 外部リソース

- [Kent C. Dodds - The Testing Trophy and Testing Classifications](https://kentcdodds.com/blog/the-testing-trophy-and-testing-classifications)
- [Next.js - How to set up Vitest with Next.js](https://nextjs.org/docs/app/guides/testing/vitest)
- [Building a Testing Infrastructure for AI-Assisted Development](https://micahking.dev/posts/testing-infrastructure-for-ai-assisted-development/)
- [Vitest Browser Mode](https://vitest.dev/guide/browser/)
- [happy-dom](https://github.com/capricorn86/happy-dom)

## ルールへのフィードバック

テスト戦略の改善点（新しいベストプラクティス、ツールの変更、実践での学び）が見つかった場合、このファイルへの編集案を示してください。編集は、ユーザーの承認を得てから PR で行います。
