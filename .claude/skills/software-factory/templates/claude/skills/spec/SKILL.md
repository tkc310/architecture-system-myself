---
description: 工程 1〜2。Issue や依頼から仕様と計画を書き、人の承認を待つ。
argument-hint: "<Issue 番号 または 依頼の要約>"
disable-model-invocation: true
---

`planner` サブエージェントに、次の依頼で仕様と計画を書かせてください。

依頼: $ARGUMENTS

- 依頼が Issue 番号なら、先に `gh issue view <番号> --comments` で本文を取り、planner に渡す。
- planner が返した未解決の質問は、まとめて人に見せる。答えを得たら planner に仕様を更新させる。
- 最後に、仕様のパスと「準備完了の定義」の各項目を満たしているかを示し、人に承認を求める。承認されたら、人が仕様の状態を「承認」に変える(エージェントは変えない)。
