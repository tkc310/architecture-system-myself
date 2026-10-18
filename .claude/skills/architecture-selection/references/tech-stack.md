# 技術スタックの既定と代替

版番号はここに書かない。選定時に公式ドキュメントで現行版と導入手順を確認すること。既定から外す場合は理由を ADR に書く。

## 共通(全アーキタイプ)

| 領域 | 既定 | 代替(採用条件) |
|------|------|------------------|
| 言語 | TypeScript(strict) | — |
| 実行環境 | Node.js LTS | Bun(起動速度・ツール一体化を計測で評価した場合) |
| パッケージ管理 | pnpm | — |
| モノレポ | 単一パッケージ(L1)/ pnpm workspaces(L2 以上で配布物が複数のとき)+ Turborepo | — |
| lint / format | Biome | ESLint + Prettier(Biome にない必須ルールがある場合) |
| 依存ルール(境界) | dependency-cruiser | — |
| 未使用コード検出 | knip | — |
| 単体・統合テスト | Vitest | — |
| E2E | Playwright | — |
| DB 統合テスト | Testcontainers(本物の Postgres) | PGlite(高速化が必要な場合) |
| Git フック | lefthook | — |
| CI | GitHub Actions | 組織標準 |
| 観測 | OpenTelemetry | — |

## 画面・API

| 要件 | 既定 | 代替 |
|------|------|------|
| 画面あり、SSR / SEO が必要 | Next.js(App Router) | TanStack Start |
| 画面あり、SSR 不要(管理画面・社内ツール) | Vite + React + TanStack Router | Next.js |
| API のみ | Hono | — |
| 画面と API が同一 TS コードベース | Server Actions / Hono RPC で型を共有 | tRPC |
| 外部クライアントがある | Hono + OpenAPI(スキーマから型生成) | — |
| UI コンポーネント | shadcn/ui + Tailwind CSS | 組織のデザインシステム |
| サーバー状態 | TanStack Query | — |

## データ

| 領域 | 既定 | 代替 |
|------|------|------|
| DB | PostgreSQL | SQLite / Turso(個人・小規模、エッジ配置) |
| ORM / クエリ | Drizzle ORM | Kysely(SQL に近い書き方を好む場合) |
| マイグレーション | drizzle-kit | — |
| 入力検証 | Zod(L1, L2) | Effect Schema(L3 で Effect を採用する場合) |
| 認証 | Better Auth | 組織の IdP / マネージド認証 |

## アーキタイプ別の追加

| アーキタイプ | 追加するもの |
|--------------|--------------|
| L1 crud-simple | なし。追加しないことが要点 |
| L2 modular-monolith | モジュール間イベント用の軽量な型付きイベントバス(自作で十分) |
| L3 domain-centric | Effect(DI、型付きエラー、Schema)。値オブジェクトはブランド型 |

## 性能段別の追加

| 段 | 追加するもの |
|----|--------------|
| P1 | Effect(Fiber、Stream、Schedule) |
| P2 | worker_threads(Effect の Worker 機能 / Piscina) |
| P3 | Rust + wasm-bindgen(wasm-pack)、または AssemblyScript |
| P4 | Go(net/http + chi または connect-go)、sqlc、gofumpt、golangci-lint、契約は OpenAPI / Protocol Buffers(buf) |
