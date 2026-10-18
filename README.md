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

### 他のプロジェクトで使う

```sh
# 個人のスキルとして登録する(Claude Code)
cp -r .claude/skills/architecture-selection ~/.claude/skills/
# Cursor では ~/.cursor/skills/ にコピーする
```

対象のリポジトリで「アーキテクチャを選定して」「ARCHITECTURE.md を作って」「構造をレビューして」と頼むと使われる。

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
```

## 由来

ルールは [tkc310/agents-playground の docs/architecture](https://github.com/tkc310/agents-playground/tree/main/docs/architecture) を元に、構造を 3 段階にし、性能対策の段階とハーネスの雛形を加えたもの。以後はこのリポジトリを正本とする。
