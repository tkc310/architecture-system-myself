# デザインシステムの選択

画面を持つサービスでは、デザインシステムの扱いを次の 3 つから選ぶ。画面を持たないサービス(API だけ、バッチだけ)では選ばない。

| 選択 | 内容 | 向いている案件 |
| --- | --- | --- |
| A. 8341-ui を使わない | デザインシステムを導入しない。組織の既存のデザインシステムがあればそれを使う | 組織の標準がある、画面がごく少ない、React 以外の画面 |
| B. 8341-ui を使う | [8341-ui](https://github.com/tkc310/8341ui) のトークンとコンポーネントを shadcn のレジストリで取り込む | 新規のサービスで、アクセシビリティを担保した部品を早くそろえたい |
| C. デザインシステムを作る | 8341-ui をひな形に、サービス(または組織)専用のデザインシステムのリポジトリを作り、B と同じ方法で取り込む | ブランドのキーカラーや見た目の性格が決まっている。複数のプロダクトで共有する基盤を作りたい |

8341-ui は、[デジタル庁デザインシステム(DADS)](https://design.digital.go.jp/dads/) のアクセシビリティ基準(WCAG 2.2 AA)を土台にしたデザインシステムで、トークン(W3C DTCG)、Base UI + Tailwind CSS v4 のコンポーネント、Storybook、画面設計のルール(design-principles)を持つ。

## 選び方

**必須**

- ヒアリングの「画面とデザインシステム」([hearing.md](./hearing.md))の回答で選ぶ。選んだものと理由を ARCHITECTURE.md と ADR に書く。
- B と C は、画面が React(19 以上)で、Tailwind CSS v4(4.1 以上)を使える場合に限る。どちらかを満たさないときは A にする。
  - 理由: 8341-ui の部品は React と Base UI で書かれ、スタイルは Tailwind v4 のテーマに依存する。
- C は、デザインシステムのリポジトリを新しく作るので、作る前にユーザーの承認を得る([承認](./human-approval.md))。
- 回答が得られないときは A にし、B か C に移る条件(画面が増えた、ブランドが決まった)を ADR の見直し条件に書く。
  - 理由: 外部のデザインシステムへの依存は、後から足せる。

**推奨**

- 組織のデザインシステムがなく、React で画面を作るなら、B を勧める。部品ごとのアクセシビリティの検証と、画面設計のルールが最初からそろう。

## A. 8341-ui を使わない

- 組織のデザインシステムがあれば、その導入手順に従い、名前と版を ARCHITECTURE.md に書く。
- なければ、画面のフレームワークの標準的な部品(shadcn/ui など)を使う。アクセシビリティの基準(WCAG 2.2 AA)は [品質ゲート](./quality-gates.md) とテストで守る。

## B. 8341-ui を使う

### 取り込み方

部品のコードをプロジェクトに取り込む shadcn 方式を使う。8341-ui は npm にも公開できる(任意)が、部品のコードを取り込む shadcn 方式を正とする。

1. 8341-ui の [GitHub Releases](https://github.com/tkc310/8341ui/releases) で最新の版(タグ `8341-ui@<版>`)を確かめ、その版を固定したレジストリを `components.json` に登録する。版は記憶で書かない。

   ```json
   {
     "registries": { "@8341": "https://tkc310.github.io/8341ui/r/v<版>/{name}.json" }
   }
   ```

   - 理由: 版のない URL(`/r/{name}.json`)は常に 8341-ui の main の最新を返すので、取り込み直すたびに部品が変わりうる。版を固定すると、更新を自分で選べる。
   - `pnpm check:versions` は、固定した版がリリースの最新より古いか、版を固定していないときに知らせる([ハーネス](../templates/harness/README.md) の「版の確認」)。

2. 土台と、使う部品を取り込む。

   ```bash
   npx shadcn@latest add @8341/8341-base @8341/button @8341/form-field @8341/text-field
   ```

3. 全体の CSS でテーマを読み込む。

   ```css
   @import 'tailwindcss';
   @import './styles/8341-ui.css';
   ```

4. テーマの切り替えは `<html class="dark">` か `<html data-theme="dark">` で行う。どちらもなければ OS の設定に従う。

レジストリの URL と部品の一覧は、導入時に 8341-ui の README と `packages/ui/registry.json` で確かめる。記憶で書かない。

### 置き場所と構造

- 取り込んだ部品は、プロジェクトの共有の UI として置く。構造の段階ごとの置き場所は次のとおり。

| 段階 | 置き場所 |
| --- | --- |
| S | `src/shared/ui/`(feature の `ui/` から import する) |
| M、L | `src/shared/ui/`(モジュールの `ui/` から import する) |

- `components.json` の `aliases.ui` を上の置き場所に、`aliases.lib` を `src/shared/lib/` に合わせる(8341-ui の `tv` などの共通処理が入る)。
- 取り込んだ部品のファイルは手で書き換えない。直したいときは、8341-ui に Issue を出すか、プロジェクト側で包む部品を作る。
- 部品を更新するときは、8341-ui の CHANGELOG(Releases の本文)で利用側の修正が要る変更(0.x では minor)を確かめ、`components.json` の URL の版を上げて、取り込んだ部品をすべて `npx shadcn@latest add @8341/<name> --overwrite` で取り込み直す。版を ARCHITECTURE.md にも書く。
  - 理由: 手で書き換えると、取り込み直したときに変更が消え、8341-ui の検証(アクセシビリティ、コントラスト)からも外れる。
- `src/shared/ui/` の 8341-ui の部品は、[編集制約](./editing-constraints.md) の保護パスに加える。

### DESIGN.md

- リポジトリ直下に DESIGN.md を置く。8341-ui の `templates/PRODUCT-DESIGN.md` を写して埋める(プロダクトの概要、画面領域ごとの UI の方向性とサービス種別、採用したルール、外した必須とその理由、8341-ui からの拡張)。
- 8341-ui 側の仕様(トークン、部品、Do / Don't)は写さず、8341-ui の DESIGN.md を参照する。
- 画面を作るエージェントは、作業の前にプロジェクトの DESIGN.md と 8341-ui の DESIGN.md を読む。この指示を AGENTS.md に書く。

### 守ること

**必須**

- アクセシビリティの目標は WCAG 2.2 AA から緩めない。
- 色、余白、文字の大きさは、8341-ui のトークン(CSS 変数と Tailwind のテーマ)だけで指定する。任意の値(`#123456`、`p-[13px]` など)を書かない。
- プロダクト固有のトークンや部品を足したら、DESIGN.md の「8341-ui からの拡張」に書く。他のプロダクトでも使えそうなら 8341-ui に Issue で提案する。

## C. デザインシステムを作る

8341-ui は、新しいデザインシステムのリポジトリを作るファクトリー(`ds-factory` スキル)を持つ。デザインシステムを作る作業は 8341-ui のリポジトリで行い、このスキルでは結果を取り込むところまでを扱う。

1. ユーザーの承認を得る(新しいリポジトリを作るため)。
2. 8341-ui を手元に複製し、そのリポジトリで Claude Code を開いて `/ds-factory` を実行する。手順は 8341-ui の `docs/factory.md` と `.claude/skills/ds-factory/SKILL.md` に従う。ヒアリングで、名前、接頭辞、キーカラー、位置づけ(共有の基盤か専用か)などを決める。
3. 生成したデザインシステムのリポジトリで `mise install`(`.tool-versions` の道具を入れる)、`pnpm check && pnpm test` を通し、GitHub に公開して、レジストリ(GitHub Pages)を配信する。
4. 最初の版をリリースする(`pnpm release:version` の PR をマージしてから `pnpm release:publish`。手順はそのリポジトリの `docs/releasing.md`)。これで版を固定したレジストリ `r/v<版>/` と GitHub Releases ができる。リリースは、権限のある人が手元で行う。
5. このサービスでは、B と同じ方法で、版を固定して取り込む。レジストリの名前空間と URL は、生成したものに置き換える(例: `@acme`、`https://<owner>.github.io/<リポジトリ名>/r/v<版>/{name}.json`)。
6. 作ったデザインシステムのリポジトリ名、レジストリの URL、接頭辞を ARCHITECTURE.md と ADR に書く。

## ARCHITECTURE.md と ADR に書くこと

- 選択(A / B / C)と理由
- B と C: レジストリの URL(固定した版を含む)、名前空間、取り込んだ部品、DESIGN.md の場所
- C: 作ったデザインシステムのリポジトリ
- 見直し条件(A から B / C に移る条件など)
