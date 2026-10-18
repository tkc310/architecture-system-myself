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
| `scripts/guard-paths.sh`、`scripts/check-edited-file.sh` | 同じパス | `chmod +x`。どちらも `jq` を使う |
| `.claude/settings.json` | 同じパス | Claude Code を使う場合。保護パスの拒否と、編集後の検査 |
| `.cursor/hooks.json` | 同じパス | Cursor を使う場合。保護パスの拒否 |
| `docs/feedback/LESSONS.md` | 同じパス | そのまま置く |

保護パスは、指示だけでなく二つ以上の仕組みで守る。既定では、エージェントのフック(Claude Code と Cursor の両方、または使う方)と CODEOWNERS + ブランチ保護の二つで守る。

## 置いた後の確認

1. `pnpm check` が空の雛形で通る。
2. 次の境界違反を一時的に置き、`pnpm lint:deps` が失敗することを確かめてから消す。
   - S: `src/app/` から `src/features/<f>/queries/` を直接 import する
   - M: あるモジュールの query から、別のモジュールの `tables.ts` を import する
   - L: `domain/` から `drizzle-orm` か `node:fs` を import する
3. `echo '{"tool_input":{"file_path":"db/migrations/0001.sql"}}' | scripts/guard-paths.sh` が終了コード 2 で終わる。

## 段階を変えたとき

`.dependency-cruiser.cjs` を新しい段階の雛形に差し替え、`vitest.config.ts` の `coverage.include` と ARCHITECTURE.md の構造の節を更新する。M から L へモジュール単位で昇格するときは `layered.cjs` に差し替える。M の形のまま残したモジュールにも同じルールが効く。
