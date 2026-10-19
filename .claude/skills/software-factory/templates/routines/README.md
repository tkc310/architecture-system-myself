# 形式 B: ルーティンの設定

形式 B では、Claude の無人ジョブを GitHub Actions ではなく Claude Code のルーティンで動かす。利用枠はサブスクリプションから使われ、API キーは要らない。ルーティンは [claude.ai/code/routines](https://claude.ai/code/routines) か、Claude Code の `/schedule` で作る。

| ルーティン | トリガー | クラウド環境 | プロンプト |
| --- | --- | --- | --- |
| factory-review | GitHub イベント: Pull request(opened、synchronize、reopened、ready_for_review) | `factory-review` | `pr-review.prompt.md` |
| factory-improve | スケジュール: 毎週(月曜 9:07 など、ちょうどの時刻を避ける) | `factory-improve` | `weekly-improve.prompt.md` |

## 安全のための設定(必須)

ルーティンは許可の確認なしで動き、コミットやコメントはあなたの GitHub アカウントとして残る。次をすべて設定する。

1. **コネクタを外す。** 作成画面の Connectors から、すべてのコネクタを外す。どちらのルーティンも GitHub 以外に触れない。
2. **クラウド環境をジョブごとに分ける。** `factory-review` と `factory-improve` の 2 つの環境を作り、環境変数を設定する。
   - `factory-review`: `FACTORY_JOB=review`
   - `factory-improve`: `FACTORY_JOB=improve`、セットアップスクリプトに `make install`
   - 両方の環境に `GH_REPO=<owner>/<repo>` も設定する(リモートの URL からリポジトリを推測できない環境でも、`gh` が対象を誤らないように)。
   - ネットワークは既定の Trusted を基本にする。`factory-improve` は依存を Takumi Guard から入れるので、許可するドメインに `npm.flatt.tech` を足す。秘密情報は環境変数に入れない。
   - `FACTORY_JOB` の働きは、software-factory スキルの `references/guardrails.md` の「実行の形式」にある。
   - 改善ジョブは `claude/factory-improve-*` のブランチに push する。クラウドのセッションが push できるのは、既定で `claude/` で始まるブランチだけなので、この制限は外さない。
3. **レビューを動かす PR を絞る。** GitHub トリガーのフィルタで、次を両方指定する。
   - Author が「次のどれか」: 信頼できる開発者の GitHub ユーザー名
   - Is draft が `false`
   - 理由: PR の本文は第三者も書ける。知らない人の PR の文章を、許可の確認なしで動くエージェントに読ませない。
4. **ブランチ保護で、管理者も迂回できないようにする。** ルーティンはあなたのアカウントとして push するので、あなたが迂回できる規則はルーティンも迂回できる。設定の内容は software-factory スキルの `templates/README.md` の「置いた後に人が行うこと」の 4 に従い、迂回を許すリスト(Bypass list)を空にする。
   - 注意: 形式 B の `factory/review` はあなたのアカウントで付くので、発行元を固定できない。書き込み権限のある人が手で付けた `success` も通る。コードオーナーのレビューを必須にして補う

## 作り方(Web)

1. **New routine** を押し、名前を `factory-review` にする。
2. Instructions に `pr-review.prompt.md` の本文を貼る。モデルを選ぶ。
3. リポジトリにこのリポジトリを選ぶ。
4. 環境に `factory-review` を選ぶ。
5. トリガーに GitHub イベントを選び、上のイベントとフィルタを設定する。Claude の GitHub アプリが入っていなければ、案内に従って入れる。
6. Connectors をすべて外して作成する。
7. `factory-improve` も同じ手順で、スケジュールのトリガーで作る。

Claude Code から作る場合は、`/schedule` で週次のルーティンを作る。GitHub トリガーは Web の編集画面で追加する。

## 動作の確認

1. 小さな PR を作り、`factory-review` のルーティンが起動して、PR にコメントと `factory/review` のステータスが付くことを確かめる。
2. ルーティンの実行記録で、フックが効いていることを確かめる(例: プロンプトに `git push --force` を試させると拒否される)。
3. `factory-improve` を **Run now** で一度動かし、週次の報告の Issue ができる(候補があれば下書き PR もできる)ことを確かめる。

## 起動しなかったとき

GitHub イベントには、ルーティンごととアカウントごとに 1 時間あたりの上限がある。上限を超えたイベントは捨てられる。その場合 `factory/review` が付かず、マージが止まる(安全側に倒れる)。ルーティンの詳細画面で **Run now** を押し、本文に PR 番号を書いて実行し直す。

ルーティンはリサーチプレビューで、動作や上限が変わることがある。変わったら `FEEDBACK.md` に記録する。
