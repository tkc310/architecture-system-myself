---
description: 工程 6。PR のレビュー指摘と CI の失敗から、防げたはずの誤りを LESSONS.md に記録する。マージの前に実行する。
argument-hint: "<PR 番号>"
disable-model-invocation: true
---

`retro` サブエージェントに、PR #$ARGUMENTS の振り返りをさせてください。

- 記録は PR のブランチで `docs/feedback/LESSONS.md` に書き、同じ PR にコミットする(`docs(feedback): PR #$ARGUMENTS の振り返りを記録`)。
- 回数が 2 以上になった行があれば、その一覧を人に見せる。規則の昇格は週次の改善ジョブか、別の PR で行う。
