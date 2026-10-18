# architecture-system-myself

AI 駆動開発で使い回すための設計のボイラープレート。アーキテクチャと技術選定のルールの正本を置く。

- フルスタック TypeScript を既定とし、性能が足りないと測定で分かったときだけ Effect → Worker → WebAssembly → Go の順に進む
- 構造は、開発人数・業務領域の数・業務ルールの複雑さで S / M / L の 3 段階から選ぶ。シンプルな CRUD にドメイン層もリポジトリ層も作らない
- 境界は文章ではなく、型・oxlint・dependency-cruiser・テスト・フックで機械的に守る
- 指摘を記録し、繰り返すものを機械的なルールに昇格させて自己改善する

## スキル

[architecture-selection](.claude/skills/architecture-selection/SKILL.md) は、ヒアリングから ARCHITECTURE.md、ディレクトリ構成、ハーネスの雛形、ADR までを出力する。既存の ARCHITECTURE.md の調整と、コードベースの構造レビューにも使う。

| 段階 | 形 | 向いている案件 |
| --- | --- | --- |
| S: slice | `features/` の Vertical Slice + CQS。層なし | 1〜2 人、CRUD 中心、仕様変更が少ない |
| M: modular | `modules/` + 公開 API + テーブルの所有。層なし | 3 人以上、または業務領域が 3 つ以上。ルールは単純 |
| L: layered | `modules/` + domain / application / infrastructure | 4 人以上 かつ 複雑なドメインロジック かつ 仕様変更が頻繁 |

[software-factory](.claude/skills/software-factory/SKILL.md) は、architecture-selection の出力の上に、Claude Code 向けのソフトウェアファクトリーを載せる。

| 層 | 生成するもの |
| --- | --- |
| 工程 | 仕様化 → 計画 → 実装 → 検証 → 独立レビュー → 振り返り → マージ。準備完了と完了の定義、仕様の雛形 |
| 役割 | サブエージェント `planner` / `implementer` / `reviewer` / `retro` と、コマンド `/spec` `/build` `/review` `/retro` |
| ガードレール | 権限の allow / ask / deny、危険なコマンドの拒否、保護パス、検査を通さない完了の阻止、秘密情報の検出、CODEOWNERS |
| 無人ジョブ | PR ごとのエージェントのレビューと週次の改善。形式 A: GitHub Actions + API キー、形式 B: lefthook + ルーティン(サブスクリプション)から選ぶ。レビュー結果は必須チェック `factory/review` になり、`--no-verify` で回避してもマージできない |
| 改善ループ | PR ごとの振り返り(LESSONS.md)と、週次で規則を強める下書き PR。規則を緩める変更は自動では提案しない |

### 他のプロジェクトで使う

```sh
# 個人のスキルとして登録する(Claude Code)
cp -r .claude/skills/architecture-selection .claude/skills/software-factory ~/.claude/skills/
# Cursor では ~/.cursor/skills/ にコピーする
```

対象のリポジトリで「アーキテクチャを選定して」「構造をレビューして」と頼むと architecture-selection が、「AI 駆動開発の工場を作って」「ガードレールを点検して」と頼むと software-factory が使われる。2 つは相互に参照するので、同じディレクトリに並べて置く。

## 構成

```
.claude/skills/architecture-selection/
├── SKILL.md                    # 作業モードと手順
├── FEEDBACK.md                 # スキル自体の改善記録
├── references/                 # ルールの本文(README.md から読む)
│   ├── hearing.md              # 前提条件のヒアリング
│   ├── scale-selection.md      # S / M / L の判定と昇格・降格
│   ├── tech-selection.md       # 技術選定と Go・Flutter の条件
│   ├── performance-ladder.md   # 性能対策の段階
│   ├── principles.md           # 段階別の構造と依存ルール
│   ├── cqs.md                  # コマンドとクエリ
│   ├── quality-gates.md        # 機械に保証させる項目と CI
│   ├── testing-strategy.md
│   ├── coding-conventions.md
│   ├── editing-constraints.md  # 保護パスと承認
│   └── review-checklist.md
└── templates/
    ├── ARCHITECTURE.md
    ├── adr.md
    ├── module-AGENTS.md
    └── harness/                # oxlint / oxfmt / dependency-cruiser(S・M・L)/ Vitest / lefthook / CI / CODEOWNERS / Claude Code と Cursor のフック

.claude/skills/software-factory/
├── SKILL.md
├── references/                 # stations / roles / guardrails / improvement-loop / audit-checklist
└── templates/
    ├── claude/                 # agents / skills(/spec /build /review /retro)/ hooks / settings.json
    ├── github/                 # 形式 A の agent-review / factory-improve、secrets-scan、PR テンプレート
    ├── routines/               # 形式 B のルーティンのプロンプトと設定手順
    ├── scripts/factory/        # 無人ジョブ用: レビュー結果の投稿、下書き PR と Issue の作成、push 前の手元のレビュー
    └── docs/                   # factory/README.md, factory/improve.md, specs/TEMPLATE.md
```

## 由来

ルールは [tkc310/agents-playground の docs/architecture](https://github.com/tkc310/agents-playground/tree/main/docs/architecture) を元に、構造を 3 段階にし、性能対策の段階とハーネスの雛形を加えたもの。以後はこのリポジトリを正本とする。
