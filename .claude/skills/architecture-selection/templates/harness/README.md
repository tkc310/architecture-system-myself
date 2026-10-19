# ハーネスの雛形

対象リポジトリに置く、境界と秩序を機械で守るための設定。どの仕組みが何を守るかは `references/quality-gates.md` と `references/editing-constraints.md` にある。

## 置き方

| 雛形 | 置き場所 | 手順 |
| --- | --- | --- |
| `AGENTS.md`、`CLAUDE.md` | リポジトリ直下 | 角括弧を埋める。`CLAUDE.md` は `@AGENTS.md` を読み込むだけ |
| `tsconfig.json` | リポジトリ直下 | フレームワークの既定の設定があれば、`strict` 系のオプションをそちらに統合する |
| `.oxlintrc.json`、`.oxfmtrc.json` | リポジトリ直下 | 置いたら `pnpm lint` を実行し、未対応のルール名がないか確かめる |
| `dependency-cruiser/<段階>.cjs` | `.dependency-cruiser.cjs` | 採った段階(`slice` / `modular` / `layered`)の 1 つだけを置く。ディレクトリ自体はコピーしない |
| `vitest.config.ts` | リポジトリ直下 | `coverage.include` を採った段階のものにし、閾値を ARCHITECTURE.md に合わせる |
| `package.scripts.json` | `package.json` | `scripts` を統合し、`devDependencies` を `pnpm add -D` で入れる。ファイル自体は置かない |
| `lefthook.yml` | リポジトリ直下 | `pnpm exec lefthook install` |
| `.github/workflows/ci.yml` | 同じパス | 6 つのステージをブランチ保護の必須チェックに指定する |
| `.github/CODEOWNERS` | 同じパス | 担当者を埋め、ブランチ保護で「コードオーナーのレビューを必須にする」を有効にする |
| `pnpm-workspace.yaml`、`.npmrc` | リポジトリ直下 | 依存の供給網の対策(`trustPolicy: no-downgrade` と Takumi Guard)。そのまま置く。モノレポなら `pnpm-workspace.yaml` に `packages` を足す。どちらにもトークンを書かない([セキュリティ](../../references/security.md#依存の供給網)) |
| `scripts/guard-paths.sh`、`scripts/check-edited-file.sh` | 同じパス | `chmod +x`。どちらも `jq` を使う |
| `scripts/check-versions.mjs` | 同じパス | 依存、Node.js、GitHub Actions、デザインシステムのレジストリが最新の安定版かを調べる。`pnpm check:versions` で実行する(下の「版の確認」) |
| `.claude/settings.json` | 同じパス | Claude Code を使う場合。保護パスの拒否と、編集後の検査 |
| `.cursor/hooks.json` | 同じパス | Cursor を使う場合。保護パスの拒否 |
| `docs/feedback/LESSONS.md` | 同じパス | そのまま置く |

保護パスは、指示だけでなく二つ以上の仕組みで守る。既定では、エージェントのフック(Claude Code と Cursor の両方、または使う方)と CODEOWNERS + ブランチ保護の二つで守る。

## 版の確認

雛形の版は、書いた時点のもの。置いたら、依存を入れた後に必ず次を実行し、古いものとプレリリースを直す。

```sh
pnpm check:versions   # node scripts/check-versions.mjs
```

| 調べるもの | 比べる相手 |
| --- | --- |
| `package.json`(と `packages/*`、`apps/*`、pnpm の catalog)の依存と `packageManager` | npm の `latest`(安定版)。指定がプレリリース(`-rc` など)なら知らせる |
| Node.js(`.tool-versions`、`.nvmrc`、`engines`) | 最新の LTS |
| `.github/workflows/*.yml` の `uses: owner/repo@vN` | 各 Action の最新のリリースの major |
| `components.json` の GitHub Pages のレジストリ(8341-ui など) | そのリポジトリの最新のリリース。URL に版(`/r/v<版>/`)がなければ知らせる |

- 終了コード 0 はすべて最新、1 は古いもの、プレリリース、版の指定がないものがある、2 は取得できなかったものだけがある。取得できなかったものは、公式の情報で手で確かめる。
- 最新の安定版にしない場合(互換性の問題、組織の標準)は、理由を ADR に書く。
- GitHub Actions の major を上げるときは、その Action のリリースノートで入力の変更を確かめる。デザインシステムの版を上げるときは [デザインシステム](../../references/design-system.md) の更新の手順に従う。
- 調べないものは `--no-node`、`--no-actions`、`--no-registries` で外せる。
- ネットワークに出られない環境では、`NPM_REGISTRY`、`NODE_DIST_URL`、`GITHUB_API` で問い合わせ先を変えられる。

## 置いた後の確認

1. `pnpm check` が空の雛形で通る。`pnpm check:versions` で古いものとプレリリースがない。
2. 次の境界違反を一時的に置き、`pnpm lint:deps` が失敗することを確かめてから消す。
   - S: `src/app/` から `src/features/<f>/queries/` を直接 import する
   - M: あるモジュールの query から、別のモジュールの `tables.ts` を import する
   - L: `domain/` から `drizzle-orm` か `node:fs` を import する
3. `echo '{"tool_input":{"file_path":"db/migrations/0001.sql"}}' | scripts/guard-paths.sh` が終了コード 2 で終わる。`.npmrc` と `pnpm-workspace.yaml` でも同じく 2 で終わる。
4. `pnpm config get registry` が `https://npm.flatt.tech/` を返す。依存に加えない作業用のディレクトリで `@panda-guard/test-malicious` の取得が 403 になる。

## 段階を変えたとき

`.dependency-cruiser.cjs` を新しい段階の雛形に差し替え、`vitest.config.ts` の `coverage.include` と ARCHITECTURE.md の構造の節を更新する。M から L へモジュール単位で昇格するときは `layered.cjs` に差し替える。M の形のまま残したモジュールにも同じルールが効く。
