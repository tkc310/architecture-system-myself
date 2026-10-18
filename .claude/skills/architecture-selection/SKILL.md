---
name: architecture-selection
description: 新規プロジェクトや大きな改修で、要件と規模からアーキテクチャと技術スタックを選定し、ディレクトリ構成・ハーネス雛形・ADRまで出力する。フルスタックTypeScriptを既定とし、性能要件があるときだけ Effect / Worker / WebAssembly / Go の順に段階的に検討する。Use when choosing architecture, tech stack, project structure, or scaffolding a new codebase for AI-driven development.
---

# アーキテクチャ選定スキル

要件を聞き取り、**要件を満たす中で最も単純なアーキテクチャ**を選び、次の5つを出力する。

| # | 出力 | 置き場所(対象プロジェクト内) | テンプレート |
|---|------|------------------------------|--------------|
| 1 | 技術スタック | `docs/architecture/overview.md` の「技術スタック」節 | `templates/architecture-overview.md` |
| 2 | アーキテクチャ | 同「アーキテクチャ」節 | 同上 |
| 3 | ディレクトリ構成 | 同「ディレクトリ構成」節+実ディレクトリ | `references/directory-structures.md` |
| 4 | ハーネスの雛形 | リポジトリ直下の設定ファイル群 | `templates/harness/` |
| 5 | ADR | `docs/adr/NNNN-*.md` | `templates/adr.md` |

## 基本原則

1. **単純さが既定**:層(ドメイン、リポジトリ、ポート等)は「必要になった証拠」があるときだけ足す。シンプルな CRUD にドメイン層やリポジトリ層を作らない。
2. **TypeScript ファースト**:性能対策はまず TS エコシステム内で行う(`references/performance-ladder.md`)。Go は最後の手段で、境界の明確な一部分にだけ使う。
3. **境界は機械で守る**:ルールは文章より、型・lint・依存ルール・テスト・フックで強制する。文章(CLAUDE.md)には機械化できないものだけを書く。
4. **昇格条件を先に書く**:選んだ構成をいつ一段上げるべきかを ADR に書いておき、後から判断できるようにする。
5. **記憶で版を決めない**:ライブラリの最新版・推奨設定は選定時に公式ドキュメントで確認する。

## 手順

### 1. 現状把握
- 対象リポジトリに `README`、`docs/architecture/`、`docs/adr/`、`package.json`、`go.mod` があれば先に読む。既存の決定(ADR)は覆さず、変更なら新しい ADR で上書きする。

### 2. 聞き取り
- `references/intake.md` の質問票を使う。**一度に聞くのは最大5問**。既に答えが分かる項目は聞かない。
- 回答がなく作業を止められないときは、質問票の「既定値」を採用し、ADR の「前提」に明記する。

### 3. アーキタイプの決定
- `references/archetypes.md` の判定フローで L1 / L2 / L3 のどれかを選ぶ。
- 迷ったら**下の段(より単純な方)**を選び、昇格条件を ADR に書く。

### 4. 修飾子(モディファイア)の付与
- 性能要件がある → `references/performance-ladder.md` で必要な段(P0〜P4)を決める。
- リアルタイム、バックグラウンドジョブ、マルチテナント等 → `references/archetypes.md` の「修飾子」節を適用する。

### 5. 技術スタックの決定
- `references/tech-stack.md` の既定から選び、外すときは理由を ADR に書く。
- 採用するライブラリは公式サイトで現行の版と導入手順を確認してから書く。

### 6. 出力の生成
1. `docs/architecture/overview.md` を `templates/architecture-overview.md` から作る。
2. ディレクトリを `references/directory-structures.md` に沿って作る(空ディレクトリには `.gitkeep`)。
3. `templates/harness/` から雛形をコピーする(`.claude/`、`.github/` などのドット付きディレクトリも含む)。
   - アーキタイプに合う依存ルール `dependency-cruiser/<archetype>.cjs` を `.dependency-cruiser.cjs` として置き、`dependency-cruiser/` ディレクトリ自体はコピーしない。
   - `package.scripts.json` の内容は `package.json` に統合し、ファイル自体は置かない。
   - `scripts/hooks/post-edit.sh` に実行権限を付ける(`chmod +x`)。フックは `jq` を使う。
4. ADR を書く:最低限 `0001-architecture-and-stack.md`。性能段 P2 以上、Go 採用、既定スタックからの逸脱は**それぞれ別の ADR** にする。

### 7. 検証
- 雛形を置いたら `pnpm install` 後に `pnpm check`(typecheck・lint・依存ルール・テスト)を実行し、空の状態で通ることを確認する。
- `references/review-checklist.md` で出力を自己点検する。

### 8. フィードバックの仕組みを有効化
- `templates/harness/docs/feedback/LESSONS.md` を配置し、運用ルール(同じ指摘が2回出たら機械的ルールへ昇格)を CLAUDE.md に書く。
- このスキル自体の改善点は、このスキルの `FEEDBACK.md` に追記する。

## 質問すべき場面

次の場合は推測せずユーザーに聞く:
- L1/L2 または L2/L3 の境界上にあり、どちらも同程度に妥当なとき
- 性能段 P3(WebAssembly)以上、または Go の採用が候補になったとき
- 既存 ADR と矛盾する選択になるとき
- デプロイ先・データストアが既存の契約や組織標準で決まっている可能性があるとき
