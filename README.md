# architecture-system-myself

AI 駆動開発で使い回すための設計ボイラープレート。

- フルスタック TypeScript を既定とし、性能要件があるときだけ Effect → Worker → WebAssembly → Go の順に検討する
- 規模ではなく「業務ルールの複雑さ」と「業務領域の数」でアーキテクチャを選ぶ(シンプルな CRUD にはドメイン層もリポジトリ層も作らない)
- 境界は文章ではなく、型・lint・依存ルール・テスト・フックで機械的に守る
- 指摘を記録し、繰り返すものを機械的なルールに昇格させて自己改善する

## スキル

| スキル | 内容 |
|--------|------|
| [architecture-selection](.claude/skills/architecture-selection/SKILL.md) | 要件の聞き取りから、技術スタック・アーキテクチャ・ディレクトリ構成・ハーネス雛形・ADR を出力する |

### アーキタイプ

| | 形 | 向いている案件 |
|--|----|----------------|
| L1 crud-simple | 入口 → 検証 → DB。層を作らない | 管理画面、社内ツール、フォーム中心 |
| L2 modular-monolith | 業務領域ごとのモジュール。`index.ts` だけ公開 | 業務領域が 3 つ以上、複数人開発 |
| L3 domain-centric | 重いモジュールだけ domain / application / infrastructure / presentation | 不変条件が重要、長期保守 |

### 他のプロジェクトで使う

```sh
# このリポジトリのスキルを個人のスキルとして登録する
cp -r .claude/skills/architecture-selection ~/.claude/skills/
```

対象プロジェクトで「アーキテクチャを選定して」と頼むと、このスキルが使われる。

## 構成

```
.claude/skills/architecture-selection/
├── SKILL.md                    # 手順
├── FEEDBACK.md                 # スキル自体の改善記録
├── references/
│   ├── intake.md               # 聞き取り質問票
│   ├── archetypes.md           # L1〜L3 の判定フローと昇格条件
│   ├── performance-ladder.md   # 性能段 P0〜P4
│   ├── tech-stack.md           # 技術スタックの既定と代替
│   ├── directory-structures.md # アーキタイプ別のディレクトリ構成
│   └── review-checklist.md     # 出力の自己点検
└── templates/
    ├── adr.md
    ├── architecture-overview.md
    └── harness/                # AGENTS.md, tsconfig, biome, dependency-cruiser(L1/L2/L3), lefthook, CI, 編集後フック, LESSONS.md
```
