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
   - ネットワークは既定の Trusted のままにする。秘密情報は環境変数に入れない。
   - `FACTORY_JOB` があると、フックがジョブごとの許可リストに切り替わり、専用スクリプト(`scripts/factory/post-review.sh`、`open-draft-pr.sh`、`open-issue.sh`)の実行と、改善ジョブによる規則ファイルの編集を許す。許可リストにないコマンド、リダイレクトによる書き込み、コマンド置換は拒否される。エージェントが会話の中で設定しても、フックには届かない。
3. **レビューを動かす PR を絞る。** GitHub トリガーのフィルタで、次を両方指定する。
   - Author が「次のどれか」: 信頼できる開発者の GitHub ユーザー名
   - Is draft が `false`
   - 理由: PR の本文は第三者も書ける。知らない人の PR の文章を、許可の確認なしで動くエージェントに読ませない。
4. **ブランチ保護で、管理者も迂回できないようにする。** ルーティンはあなたのアカウントとして push するので、あなたが迂回できる規則はルーティンも迂回できる。ルールセットで次を設定し、迂回を許すリスト(Bypass list)を空にする。
   - `main` への直接の push と強制 push の禁止
   - 必須チェック: 品質ゲートの 6 ステージ、`secrets-scan`、`factory/review`
   - 注意: 形式 B の `factory/review` はあなたのアカウントで付くので、発行元を固定できない。書き込み権限のある人が手で付けた `success` も通る。コードオーナーのレビューを必須にして補う

## 作り方(Web)

1. **New routine** を押し、名前を `factory-review` にする。
2. Instructions に `pr-review.prompt.md` の本文を貼る。モデルを選ぶ。
3. リポジトリにこのリポジトリを選ぶ。
4. 環境に `factory-review` を選ぶ。
5. トリガーに GitHub イベントを選び、上のイベントとフィルタを設定する。Claude の GitHub アプリが入っていなければ、案内に従って入れる。
6. Connectors をすべて外して作成する。
7. `factory-improve` も同じ手順で、スケジュールのトリガーで作る。

Claude Code から作る場合は `/schedule` で週次のルーティンを作り、GitHub トリガーは `/schedule` で既存のルーティンに追加するか、Web で追加する。

## 動作の確認

1. 小さな PR を作り、`factory-review` のルーティンが起動して、PR にコメントと `factory/review` のステータスが付くことを確かめる。
2. ルーティンの実行記録で、フックが効いていることを確かめる(例: プロンプトに `git push --force` を試させると拒否される)。
3. `factory-improve` を **Run now** で一度動かし、下書き PR か Issue ができることを確かめる。

## 起動しなかったとき

GitHub イベントには、ルーティンごととアカウントごとに 1 時間あたりの上限がある。上限を超えたイベントは捨てられる。その場合 `factory/review` が付かず、マージが止まる(安全側に倒れる)。ルーティンの詳細画面で **Run now** を押し、本文に PR 番号を書いて実行し直す。

ルーティンはリサーチプレビューで、動作や上限が変わることがある。変わったら `FEEDBACK.md` に記録する。
