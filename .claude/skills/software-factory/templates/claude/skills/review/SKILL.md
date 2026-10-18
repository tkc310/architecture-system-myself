---
description: 工程 5。仕様と差分だけを reviewer に渡し、独立にレビューさせる。
argument-hint: "<docs/specs/NNNN-*.md> [比較元のブランチ。既定は main]"
disable-model-invocation: true
---

`reviewer` サブエージェントを起動し、次の 2 つだけを渡してください。実装の経緯、会話の要約、あなたの意見は渡しません。

- 仕様のパス: $0
- 比較元のブランチ: 「$1」(空なら `main`)。差分は `git diff <比較元>...HEAD` で取る

reviewer の出力をそのまま人に見せてください。要約したり、指摘を和らげたりしないでください。
