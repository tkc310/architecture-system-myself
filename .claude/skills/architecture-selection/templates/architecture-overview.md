# アーキテクチャ概要: {{プロジェクト名}}

> このファイルは現在の構成の要約。決定の理由は `docs/adr/` を正とする。

## 要件の要約
- 目的: {{}}
- 主な操作: {{}}
- 性能要件: {{}}
- 制約: {{デプロイ先、既存資産}}

## アーキテクチャ
- アーキタイプ: {{L1 crud-simple | L2 modular-monolith | L3 domain-centric}}(ADR-0001)
- 修飾子: {{performance P? / realtime / background-jobs / multi-tenant / public-api / なし}}
- 依存の向き:
  ```
  {{例(L2): app → modules/*/index.ts → (モジュール内部) → db / shared}}
  ```
- 次に構成を見直す条件: {{ADR-0001 の昇格条件を要約}}

## 技術スタック
| 領域 | 採用 | ADR |
|------|------|-----|
| 言語 / 実行環境 | | |
| フレームワーク | | |
| DB / ORM | | |
| 検証 | | |
| テスト | | |
| lint / format / 境界 | | |
| CI / デプロイ | | |

## ディレクトリ構成
```
{{実際の構成}}
```

## ハーネス(機械で守るもの)
| 守ること | 仕組み | コマンド |
|----------|--------|----------|
| 型の正しさ | TypeScript strict | `pnpm typecheck` |
| 書式・静的解析 | Biome | `pnpm lint` |
| 層・モジュール境界 | dependency-cruiser | `pnpm lint:deps` |
| 未使用コード | knip | `pnpm lint:unused` |
| 振る舞い | Vitest / Playwright | `pnpm test` / `pnpm test:e2e` |
| 全部まとめて | — | `pnpm check` |
