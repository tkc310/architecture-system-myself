---
description: 工程 3〜4。承認済みの仕様を実装し、検査を通して PR を作る。
argument-hint: "<docs/specs/NNNN-*.md>"
disable-model-invocation: true
---

承認済みの仕様 $ARGUMENTS を実装します。

1. 仕様の状態が「承認」かを確かめる。違えば止めて人に伝える。
2. `main` から `feat/<仕様の番号>-<slug>` のブランチを作る(作業の種類に応じて `fix/`、`refactor/`、`test/`)。
3. `implementer` サブエージェントに、仕様のパスだけを渡して実装させる。
4. `make check` が通ることを確かめる。
5. 次の工程として `/review $ARGUMENTS` を実行する。必須の指摘があれば implementer に直させ、再度 `/review` する。
6. 必須の指摘がなくなったら、`.github/pull_request_template.md` に沿って PR を作る。受け入れ条件とテストの対応表を説明に入れる。PR の作成は人の確認を経る。
