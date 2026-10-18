# ディレクトリ構成

各構成の境界ルールは `templates/harness/dependency-cruiser/<archetype>.cjs` で機械的に強制する。構成を変えたら依存ルールも同時に変える。

## 共通(全アーキタイプ)

```
.
├── AGENTS.md                 # エージェント向けルール(CLAUDE.md は @AGENTS.md で読み込む)
├── CLAUDE.md
├── .claude/settings.json     # 編集後フック
├── .dependency-cruiser.cjs   # 境界ルール
├── biome.json
├── tsconfig.json
├── lefthook.yml
├── .github/workflows/ci.yml
├── docs/
│   ├── architecture/overview.md
│   ├── adr/                  # NNNN-title.md
│   └── feedback/LESSONS.md   # 指摘の記録 → ルールへの昇格
└── scripts/hooks/            # フックから呼ぶスクリプト
```

## L1: crud-simple(Next.js の例)

```
src/
├── app/                      # ルーティングと画面。features を呼ぶだけ
│   └── (routes)/todos/page.tsx
├── features/
│   └── todos/
│       ├── schema.ts         # Zod スキーマ(入力の唯一の定義)
│       ├── actions.ts        # 書き込み:検証 → DB → 結果
│       ├── queries.ts        # 読み取り
│       ├── components/       # この機能の UI
│       └── todos.test.ts     # 統合テスト(本物の DB)
├── db/
│   ├── schema.ts             # Drizzle テーブル定義
│   ├── client.ts
│   └── migrations/
└── lib/                      # 業務を含まない共通処理
```

API のみ(Hono)の場合は `app/` を `routes/` に置き換え、各 feature に `route.ts` を置く。

## L2: modular-monolith

```
src/
├── app/                      # 画面・ルーティング(または routes/)。modules の index.ts だけを呼ぶ
├── modules/
│   ├── members/
│   │   ├── index.ts          # 公開 API(他から import できる唯一の入口)
│   │   ├── schema.ts
│   │   ├── commands.ts       # 書き込みユースケース(関数)
│   │   ├── queries.ts
│   │   ├── events.ts         # このモジュールが発行するイベントの型
│   │   ├── db/tables.ts      # このモジュールが所有するテーブル
│   │   ├── domain/           # ルールが育ったときだけ作る
│   │   └── __tests__/
│   └── billing/
│       └── ...
├── shared/                   # 型・ユーティリティ。業務ロジックは置かない
│   ├── event-bus.ts
│   └── result.ts
└── db/
    ├── client.ts
    ├── schema.ts             # 各モジュールの tables.ts を再エクスポートするだけ
    └── migrations/
```

配布物が複数(Web とワーカー等)になったら pnpm workspaces に分ける:`apps/web`、`apps/worker`、`packages/modules`(中身は上と同じ)。

## L3: domain-centric(重いモジュールにだけ適用)

```
src/modules/billing/
├── index.ts                  # 公開 API(application のユースケースと公開型のみ)
├── domain/                   # 純粋。フレームワーク・DB・HTTP を import しない
│   ├── invoice.ts            # エンティティ
│   ├── money.ts              # 値オブジェクト(ブランド型)
│   ├── errors.ts             # ドメインエラー
│   └── invoice.test.ts       # DB 不要の単体テスト
├── application/
│   ├── ports.ts              # 外部依存のインターフェース(Effect の Context タグ)
│   ├── issue-invoice.ts      # ユースケース
│   └── issue-invoice.test.ts # ポートをテスト用実装に差し替えて検証
├── infrastructure/
│   ├── invoice-repository.ts # ports の実装(Drizzle)
│   ├── payment-gateway.ts
│   └── layers.ts             # 本番用 Layer の組み立て
└── presentation/
    └── routes.ts             # HTTP / Server Action → application
src/shared-kernel/            # 全モジュール共通の値オブジェクト等(最小限)
```

## 性能段による追加

```
src/workers/                  # P2: Worker 入口とメッセージスキーマ
packages/wasm-<name>/         # P3: Rust クレート + 生成バインディング + TS ラッパー + 差分テスト
contracts/                    # P4: OpenAPI / .proto(契約の正)
packages/contracts/           # P4: 生成した TS クライアント(手で編集しない)
services/<name>/              # P4: Go サービス
├── cmd/<name>/main.go
├── internal/
├── go.mod
└── .golangci.yml
```
