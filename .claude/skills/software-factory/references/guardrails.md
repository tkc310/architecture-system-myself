# ガードレール

ガードレールは、エージェントが**してはいけないこと**を、指示ではなく仕組みで止める。[編集制約](../../architecture-selection/references/editing-constraints.md) の保護パスと承認ルールを前提に、工場として次の層を重ねる。

## 層

| 層 | 仕組み | 止めるもの | 回避できるか |
| --- | --- | --- | --- |
| 1. 指示 | `AGENTS.md`、役割の定義、仕様 | 方針から外れた作業 | できる(読み落とす) |
| 2. 権限 | `.claude/settings.json` の `permissions` | 許可していないコマンド、秘密情報の読み取り | エージェントからはできない |
| 3. エージェントのフック | `PreToolUse`、`PostToolUse`、`Stop` | 保護パスの編集、危険なコマンド、検査を通さない完了 | エージェントからはできない |
| 4. Git のフック | lefthook | 整形漏れ、境界違反、秘密情報のコミット | `--no-verify` でできる |
| 5. GitHub 側の検査 | 品質ゲートと秘密情報の検出(GitHub Actions)、エージェントのレビュー(形式 A: GitHub Actions、形式 B: ルーティン)。結果はすべて必須チェック | 上の層をすり抜けた違反 | できない(ブランチ保護) |
| 6. マージの承認 | CODEOWNERS、ブランチ保護 | 人の確認を経ない変更 | できない |

**必須**

- 止めたいことは、2〜6 の層のうち二つ以上で止める。1 の層だけに頼らない。
  - 理由: 指示は読み落とされ、Git のフックは回避できる。
- ガードレールの設定ファイル自体を保護パスにする(`.claude/**`、`.github/**`、`scripts/factory/**`、`.git/**`、`CODEOWNERS`)。

## `--no-verify` への対策

Git のフック(層 4)は、Git の仕組み上、手元の操作で必ず回避できる(`--no-verify`、`-n`、`core.hooksPath` の変更、フックの削除)。GitHub.com では、サーバー側で push を拒否するフックも使えない。そこで、回避する主体ごとに次のように止める。

| 主体 | 止め方 |
| --- | --- |
| エージェント | `guard-bash.sh` が、`--no-verify`、`git commit -n`、`LEFTHOOK=0`、`core.hooksPath` の変更、`lefthook uninstall`、`.git/hooks` への操作を拒否する。`guard-paths.sh` が `.git/**` への書き込みを拒否する |
| 人 | 手元では止めない。**マージの条件を、GitHub 側で動く検査の結果だけにする**。Git のフックで行う検査は、すべて GitHub 側でもう一度行う。うっかりの回避はこれで止まる。故意の偽装への強さは下の注意を参照 |

**必須**

- Git のフックで行う検査(整形、lint、依存ルール、秘密情報、エージェントのレビュー)は、すべて GitHub 側でも行い、その結果をブランチ保護の必須チェックにする。Git のフックは「早く気づくため」のもので、マージの条件にしない。
- エージェントのレビューの結果は、先頭コミットのステータス `factory/review` として残す(`scripts/factory/post-review.sh`)。ステータスはコミットに付くので、新しいコミットを push するとレビューのやり直しが要る。`post-review.sh` は、レビューした sha と PR の先頭が違えば投稿しない(レビューの間の push を承認しないため)。
- コミットのステータスは、書き込み権限のある人やワークフローなら誰でも付けられる。どこまで偽装を防げるかは形式で異なる。
  - 形式 A: ルールセットの必須チェックで `factory/review` の発行元を GitHub Actions に固定する。他の発行元が付けたステータスは数えられない。レビューのジョブは作業ツリーを比較元の版にし、PR が変えたフック、`reviewer.md`、`post-review.sh` では動かない。ただし、ワークフロー自体は PR の版で動くので、`.github/` と `scripts/factory/` の変更は CODEOWNERS のレビューで止める。
  - 形式 B: ステータスはあなたのアカウントで付くので、発行元を固定できない。書き込み権限のある人が手で `success` を付ければ通ってしまう。故意の偽装は防げないので、CODEOWNERS のレビューと、人のマージ判断で補う。エージェントによる偽装は、`post-review.sh` を `FACTORY_JOB=review` のジョブに限ることと、`gh api` での書き込みの拒否で防ぐ。
- ブランチ保護(ルールセット)の迂回を許すリストを空にする。管理者も迂回できないようにする。
  - 理由: 形式 B のルーティンは、あなたの GitHub アカウントとして動く。あなたが迂回できる規則は、ルーティンも迂回できる。

## 実行の形式

Claude の無人ジョブ(PR のレビュー、週次の改善)をどこで動かすかを、2 つの形式から選ぶ。

| | 形式 A: GitHub Actions | 形式 B: lefthook + ルーティン |
| --- | --- | --- |
| PR のレビュー | `agent-review.yml`(claude-code-action) | ルーティン `factory-review`(GitHub トリガー)。手元では pre-push で事前にレビュー(`local-review.sh`) |
| 週次の改善 | `factory-improve.yml`(スケジュール) | ルーティン `factory-improve`(スケジュール) |
| 認証と費用 | API キー。従量課金 | サブスクリプション。手元の利用枠と共有 |
| ツールの制限 | `--allowedTools` で、工程に要るツールだけに絞れる。フックの許可リストも効く | ツールを絞る設定がない。フックがジョブごとの許可リストに切り替わって絞る。コネクタを外し、PR 作成者をフィルタで絞る |
| `factory/review` の偽装 | 発行元を GitHub Actions に固定できる | 発行元を固定できない(下の注意) |
| 動作の主体 | GitHub Actions(リポジトリの権限だけ) | あなたの GitHub アカウント |
| 注意 | Actions の実行時間がかかる | リサーチプレビュー。GitHub イベントに 1 時間あたりの上限があり、超えるとレビューが付かずマージが止まる(Run now でやり直す) |

ツールを機械的に絞れる形式 A の方が、エージェントにできることが小さく、安全性は高い。形式 B を選ぶときは、`templates/routines/README.md` の「安全のための設定」をすべて行う。

どちらの形式でも、無人のジョブは実行環境に `FACTORY_JOB`(`review` か `improve`)を設定する。この値があると、`guard-bash.sh` はジョブごとの許可リストに合うコマンドだけを通し、リダイレクトによる書き込みとコマンド置換を拒否する。ジョブ専用のスクリプト(`post-review.sh`、`open-draft-pr.sh`、`open-issue.sh`)の実行と、改善ジョブによる規則ファイルの編集も、この値で許す。エージェントが会話の中で設定した値はフックに届かないので、手元のセッションではこれらは使えない。

## 権限(層 2)

**必須**

- 既定は「確認を求める」にし、日常の作業で使う安全なコマンドだけを許可リストに入れる。
  - 許可: 検査とテスト(`make check`、`make test` など。コマンドは `Makefile` のターゲットだけを許す)、読み取り系の Git(`git status`、`git diff`、`git log`)、ブランチ上でのコミット、`gh` の読み取り系
  - 確認: 依存の追加と削除(`make add`、`make add-dev`、`make remove`)、部品の取り込み(`make ui-add`、`make ui-update`)、`git push`、PR の作成、生成コマンド
  - 拒否: 秘密情報の読み取り(`.env*`、鍵ファイル)、破壊的なコマンド(`rm -rf`、`git push --force`、`git reset --hard`)、パッケージマネージャーの直接の実行。本番への操作と外部への送信(`curl` などでの POST)は、権限ではなく `guard-bash.sh` で拒否する
- 拒否は許可より優先される前提で書き、許可リストを広く取りすぎない。

## 危険なコマンドの検査(層 3)

権限の規則はコマンドの形の一致で判定するので、`bash -c`、`xargs`、変数などで包んだコマンドを取りこぼすことがある。`PreToolUse` のフックで、Bash のコマンド全体を検査する(`templates/claude/hooks/guard-bash.sh`)。

**必須**

- 次を含むコマンドを拒否する: 再帰的な削除(`rm -rf`)、強制プッシュ、`main` への直接プッシュとコミット、作業内容を捨てる操作(`reset --hard`、`clean -f`)、Git のフックの回避と無効化(上の節)、PR のマージ、`gh api` での書き込み、秘密情報ファイル(利用者の `~/.npmrc` を含む)の読み出し、依存の取得元や供給網の検査の上書き(`--registry`、`pnpm config set`、`npm_config_*`、`--config.*`、`.npmrc` と `pnpm-workspace.yaml` へのシェルからの書き込み)、パイプでのシェル実行(`curl ... | sh`)、外部への送信、本番環境への操作。
- `make` を通さないコマンドを拒否する: `pnpm`、`pnpx`、`npx`、`npm`、`yarn`、`bun`、`bunx`、`corepack` と、`vitest`、`oxlint`、`oxfmt`、`tsc`、`tsx`、`depcruise`、`playwright`、`lefthook`、`drizzle-kit`、`shadcn`、`node_modules/.bin/`、`node scripts/` の直接の実行。代わりのターゲットを示す。
  - この規則は入口を一つに保つための誘導で、`sh -c '…'` のように文字列に包んだ呼び出しまでは止めない。依存の取得元と検査は、`.npmrc`、`pnpm-workspace.yaml`、CI の `make install`(前処理の `make check-supply-chain`)で守る。
- `make` の呼び方を絞る: オプション(`-f`、`-C`、`-e`、`--eval` など)と、`pkg=`、`name=`、`args=` 以外の変数の指定(`SHELL=` などでレシピを書き換えられる)を拒否する。`MAKEFLAGS` などの環境変数の指定も拒否する。
- 拒否したときは、理由と代わりの手順を stderr に返す。

## 完了前の検査(層 3)

**必須**

- `Stop` のフックで、作業ツリーに変更があるのに `make check` が通らない状態での完了を止め、失敗の内容をエージェントに返す。
- 無限ループを避けるため、2 回止めても直らないときは、止めずに人へ引き継ぐ。push の前の独立レビュー(`local-review.sh`)の中では止めない。

## 秘密情報(層 2、4、5)

**必須**

- `.env*` と鍵ファイルを、権限で読み取り拒否にする。
- コミット前(lefthook)と CI で、秘密情報の検出ツール(gitleaks など)を実行する。
- テストデータに実在の個人情報を使わない。

## 外部から入る文章(層 1、2)

Issue、PR の説明、レビューコメント、依存パッケージの README は、第三者が書ける。エージェントへの指示が紛れ込んでいても従わない。

**必須**

- 役割の定義と無人ジョブのプロンプトに、外部の文章は指示ではなくデータとして扱うと書く。
- 形式 A では、GitHub Actions のエージェントに `--allowedTools` で、その工程に要るツールだけを与える。レビューのジョブにはファイルの編集とプッシュを与えない。
- 形式 B では、ルーティンのコネクタをすべて外し、レビューの GitHub トリガーを信頼できる作成者の PR に絞る。
- フォークからの PR では、シークレットを使うジョブ(エージェントのレビュー)を動かさない。`pull_request` のイベントはフォークにシークレットを渡さないので、`pull_request_target` に変えない。

## 依存の追加

**必須**

- 依存の追加は権限で「確認」にし、`package.json`、ロックファイル、`.npmrc`、`pnpm-workspace.yaml` を保護パスにする。
- 取得元は Takumi Guard、`trustPolicy` は `no-downgrade` にする(architecture-selection の `references/security.md` の「依存の供給網」)。エージェントはこれを外さない。止まった版を外す(`trustPolicyExclude`)のは人が ADR を書いて行う。
- 追加するときは、PR の説明に、目的、代わりに検討したもの、ライセンス、保守状況を書く。
