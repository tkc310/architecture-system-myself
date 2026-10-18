# AI 駆動開発のための構造

この文書は、コードベースの構造をどう決めるかを並べる。エージェントはコンテキストウィンドウに入る範囲しか一度に読めず、人間のレビュー担当者も一度に追える範囲が限られる。変更に関係するファイルの数と大きさを小さく保ち、その場所を名前から推測できるようにすれば、どちらも一度に扱える範囲に収まる。各ルールに、その理由を一行で添える。

段階（S / M / L）は [構造の段階の選び方](./scale-selection.md) で決める。採った段階の節と、共通の節を読む。

## S: slice（Vertical Slice + CQS）

Vertical Slice + CQS を採用する。domain 層と infrastructure 層は作らず、Command と Query から ORM を直接使う。ボイラープレートを最小限に抑え、エージェントが一度に読める範囲で必要な変更を完結させる。

### ディレクトリ構成

**必須**

- 機能ごとのモジュール（垂直スライス）で分ける。技術の層（`components/`、`services/`、`repositories/`）をリポジトリの最上位に置かない。
  - 理由: 一つの機能の変更が一つのディレクトリに収まり、エージェントが読む範囲とレビューの範囲が一致する。
- 次の構成を既定とする。

```
src/
  app/                    # ルーティング、画面、API の入口
  features/
    <feature>/
      index.ts            # 公開 API。service と query だけを外に出す
      README.md
      commands/           # place-order.command.ts
      queries/            # get-order.query.ts
      services/           # 名詞単位の共通処理（stock.service.ts、pricing.service.ts）
      ui/                 # この feature だけが使うコンポーネント
  shared/                 # DB 接続、認証、エラー処理など技術的な共通処理
    db/
      client.ts
      schema/             # テーブル定義
  generated/              # 生成コード。手で編集しない
db/migrations/
```

- テストは対象と同じディレクトリに `*.test.ts` として置く。
  - 理由: 実装とテストを一度に開ける。

### 呼び出しの向き

**必須**

- 呼び出しは `app/` → `features/` の command / query → `services/` の順にする。
- 1 操作を 1 ユースケースとして、リクエスト単位で command か query を作る。複数の feature を束ねる層（Application Service や UseCase 層）は作らない。
- Command と Query から直接 ORM を使ってよい。インフラ層やドメイン層は作らない。
  - 理由: この段階では層を重ねるコストが変更の局所性を上回る。
- `app/` のルートは薄く保つ。パラメータの取り出し、認証、入力の受け取り、レスポンスの整形だけを行う。

### Service の切り出し

**必須**

- Service は名詞（集合やルール）単位で切り出す。例: `stock.service.ts`、`pricing.service.ts`。
- ルールや計算は、2 回目に現れたときに service に抽出する。
  - 理由: 早すぎる抽象を避け、実際に共通化が必要になってから切り出す。

### Feature 間の呼び出し

**必須**

- 他の feature から呼べるのは、`service` と `query` だけとする。`command` は `app/` からだけ呼ぶ。
  - 理由: command の副作用が連鎖して追いにくくなるのを防ぐ。
- Feature 間の参照は一方向にする。循環参照を作らない。

### Query の JOIN と集計

**必須**

- Query 内での JOIN や集計（例: `listPosts` に `commentCount` を含める）は許可する。
- N+1 問題を避ける。必要なデータは一度の query でまとめて取得する。

## M: modular（モジュール + 公開 API、層なし）

S と同じく層を作らず ORM を直接使う。そのうえで、複数人が並行して変更しても影響がモジュールに収まるよう、**テーブルの所有** と **モジュールごとの AGENTS.md** を加える。

### ディレクトリ構成

**必須**

```
src/
  app/                    # ルーティング、画面、API の入口
  modules/
    <module>/
      index.ts            # 公開 API。service と query、入出力の型だけを外に出す
      README.md
      AGENTS.md           # エージェント向けの指示（用語集、禁止事項、参照実装）
      commands/
      queries/
      services/
      ui/
      tables.ts           # このモジュールが所有するテーブル定義
  shared/                 # DB 接続、認証、エラー処理。modules を import しない
  generated/
db/migrations/
```

- 呼び出しの向き、Service の切り出し、モジュール間の呼び出しは、S の `features/` を `modules/` と読み替えて同じルールに従う。

### テーブルの所有

**必須**

- 各モジュールは、自分の `tables.ts` のテーブルだけを読み書きする。他モジュールのテーブルへの JOIN と外部キーを作らない。テーブル名にはモジュールの接頭辞を付けるか、モジュールごとにスキーマを分ける。
- 他モジュールのデータは、そのモジュールの `index.ts` が公開する query で読む。
  - 理由: `tables.ts` を他モジュールから import できないので、JOIN の禁止を依存ルールで強制できる。モジュールを後で切り出すときの障害（共有テーブル、共有トランザクション）も生まれない。
- マイグレーションツールには、各モジュールの `tables.ts` をまとめて渡す（例: drizzle-kit の `schema` に `./src/modules/*/tables.ts` を指定）。集約用のファイルは作らない。

## L: layered（軽量 DDD）

AI 駆動開発が効果的に行える程度のレイヤーを用意する。domain 層と infrastructure 層を置き、軽量 DDD の考え方を部分的に取り入れる。ただし、中身のない UseCase 層、意味のない mapper、層ごとの DTO 詰め替え、早すぎる抽象化などのボイラープレートは避ける。用語集、境界づけられた機能、不変条件の一箇所への集約を行う。

### ディレクトリ構成

**必須**

- 次の構成を既定とする。外すときは ARCHITECTURE.md に構成と理由を書く。

```
src/
  app/                    # ルーティング、画面、API の入口。モジュールの公開 API を呼ぶだけにする
    composition-root.ts   # 依存の組み立て。ここだけが infrastructure/ を import できる
  modules/
    <module>/
      index.ts            # 公開 API。他から import してよい唯一のファイル
      README.md
      AGENTS.md
      domain/             # 型と純粋関数。I/O を行うライブラリを import しない
      application/
        commands/         # place-order.command.ts
        queries/          # get-order.query.ts
        ports.ts          # 外部 I/O のインターフェース
      infrastructure/     # ports の実装（DB、外部 API）
        tables.ts         # このモジュールが所有するテーブル定義
      ui/
  shared/                 # 横断的な基盤（ロガー、DB 接続、認証）。modules を import しない
  generated/
db/migrations/
```

**推奨**

- ルールの重いモジュールだけを L の形にし、`domain/` を持たない薄いモジュール（CRUD だけのもの）は M の形のままでよい。

### 軽量 DDD の適用

**必須**

- 境界づけられたコンテキストとして module を区切り、用語集は `AGENTS.md` に置く。
- 不変条件は `domain/` に一箇所にまとめる。
- 依存の向きと公開 API は、dependency-cruiser の依存ルールで強制する（[品質ゲート](./quality-gates.md#依存関係の管理)）。
- テーブルの所有は M と同じ。

**推奨**

- 集約、値オブジェクト、Repository は、複雑な部分だけに適用する。すべてのエンティティを集約にしない。
- 複数モジュールにまたがる処理が増えたときだけ、既定の層に加えて読み取りの束ね（Read Model / views）と書き込みの束ね（Application Service / workflows）を置いてよい。足してよい層はこの二つに限り、汎用のサービス層やマネージャー層は足さない。
- `handlers` という名前は HTTP ハンドラと紛らわしいので避ける。

## モジュールごとの AGENTS.md（M と L）

**必須**

- 各モジュールに短い `AGENTS.md` を置く（雛形は `templates/module-AGENTS.md`）。どこに何を書くか、禁止事項、用語集、参照実装を簡潔に示す。README と重複する内容は書かず、エージェント固有の指示に絞る。
  - 理由: 多人数で開発するとき、モジュールごとの文脈とルールをエージェントに伝える手段が必要になる。

## 依存の向きと公開 API（共通）

### 依存の向き

**必須**

- 次の向きの import だけを許す。違反は [品質ゲート](./quality-gates.md) の依存ルールで CI に検出させる。設定は `templates/harness/dependency-cruiser/` にある。

**S（features/）と M（modules/）の依存ルール**（M は `features/` を `modules/` と読み替える）

| import する側 | import してよい先 |
| --- | --- |
| `app/` | 各 feature の `index.ts`、`commands/`、`ui/`、`shared/` |
| `features/A/` の外から（`app/` を除く） | `features/A/index.ts` だけ |
| `commands/`、`queries/` | 同じ feature の `services/`（M では `tables.ts` も）、他 feature の `index.ts`（service と query だけ）、`shared/` |
| `services/` | 同じ feature の `services/`（M では `tables.ts` も）、他 feature の `index.ts`（service と query だけ）、`shared/` |
| `shared/` | `shared/` |

**L（modules/）の依存ルール**

| import する側 | import してよい先 |
| --- | --- |
| `app/` | 各モジュールの `index.ts` と `ui/`、`shared/` |
| `app/composition-root.ts` | 上に加えて、各モジュールの `infrastructure/` |
| `modules/A/` の外から（上の 2 つを除く） | `modules/A/index.ts` だけ |
| `domain/` | 同じモジュールの `domain/` |
| `application/` | 同じモジュールの `domain/` と `application/`（`ports.ts` を含む）、他モジュールの `index.ts`、`shared/` |
| `infrastructure/` | 同じモジュールの `application/ports.ts`、`domain/`、`infrastructure/`、`shared/` |
| `shared/` | `shared/` |

- 循環依存を作らない。
  - 理由: 依存が一方向なら、変更の影響範囲を import の向きから判断できる。

### 公開 API

**必須**

- モジュール（S では feature）が外に出すものは `index.ts` に列挙する。
  - S と M: `service` と `query` だけを公開する。`command` は公開せず、`app/` が `commands/` のファイルを直接 import する。
    - 理由: `index.ts` に command を載せると他のモジュールからも呼べてしまい、「command は `app/` からだけ呼ぶ」を依存ルールで強制できない。
  - L: コマンド、クエリ、入出力の型だけを出し、`infrastructure/` の実装や ORM のエンティティは出さない。
  - 理由: エージェントは `index.ts` だけを読めば、そのモジュールの使い方が分かる。
- `index.ts` 以外に再エクスポート用のファイル（barrel）を作らない。
  - 理由: 入口が一つなら、利用箇所を検索で漏れなく見つけられる。
- 公開 API の入出力は、Zod のスキーマを持つプレーンなデータにする。クラスのインスタンス、関数、ORM のエンティティを渡さない。

## ファイルと関数の大きさ（共通）

**必須**

- ファイルの行数と関数の行数に上限を設け、リンターの `max-lines` と `max-lines-per-function` で検査する。上限は目安としてファイル 300 行、関数 50 行とし、`generated/` とテストのフィクスチャは対象から外す。
  - 理由: 上限があると、エージェントはファイル全体を一度に読んで編集でき、レビューの差分も追える大きさに収まる。
- 上限を超えたら、行を詰めるのではなく、責務ごとにファイルや関数を分ける。

## 命名（共通）

**必須**

- ファイル名とディレクトリ名は kebab-case にする。役割は接尾辞で示す（`*.command.ts`、`*.query.ts`、`*.service.ts`、`*.test.ts`）。
- モジュール名（S では feature）は、利用者の業務の言葉にする（`billing`、`order`）。`utils`、`common`、`helpers` のような中身を示さない名前を `shared/` の外で使わない。
  - 理由: 名前から場所を推測できれば、エージェントがコードベース全体を検索しなくて済む。

## 間接化（共通）

**必須**

- S と M では、インフラ層を作らず command / query から直接 ORM を使うため、ports は不要である。一つのリクエストが通る層は `app/` → command / query → service に固定する。
- L では、インターフェースは I/O の境界（`ports.ts`）にだけ置く。実装が一つしかない内部の処理にインターフェースや抽象クラスを作らない。既定のリクエスト経路は `app/` → command / query → `domain/` と `infrastructure/` とする。
  - 理由: 呼び出しを追うたびに実装を探す手間が増え、エージェントが読むファイルも増える。

**推奨**

- L では、共通化は同じ処理が三か所に現れてから行う。S と M の service 切り出しは、2 回目に現れたときに行う。

## モジュールごとの README（共通）

**必須**

- 各モジュール（S では feature）に `README.md` を置く。責務（一文）、公開する API、依存するモジュール、所有するテーブルを書く。
  - 理由: エージェントと人間の両方が、コードを読む前にモジュールの範囲を確認できる。
