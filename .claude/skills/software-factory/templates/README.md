# 雛形の置き方

architecture-selection のハーネスを置いた後に、次の順で置く。

| 雛形 | 置き場所 | 手順 |
| --- | --- | --- |
| `docs/factory/README.md`、`docs/factory/improve.md` | 同じパス | 角括弧を埋める |
| `docs/specs/TEMPLATE.md` | 同じパス | そのまま |
| `claude/agents/*.md` | `.claude/agents/` | 「読むもの」を構造の段階に合わせる(S では `modules/` を `features/` に) |
| `claude/skills/*/SKILL.md` | `.claude/skills/<name>/SKILL.md` | そのまま |
| `claude/hooks/*.sh` | `.claude/hooks/` | `chmod +x`。`jq` を使う |
| `claude/settings.json` | `.claude/settings.json` | ハーネスの `.claude/settings.json` を**置き換える**(ハーネスのフックも含んでいる)。許可リストをプロジェクトのコマンドに合わせる |
| `github/workflows/*.yml` | `.github/workflows/` | `agent-review` と `factory-improve` には `ANTHROPIC_API_KEY` が要る。`secrets-scan` は組織のリポジトリでは `GITLEAKS_LICENSE` も要る |
| `github/pull_request_template.md` | `.github/pull_request_template.md` | そのまま |
| `AGENTS.factory.md` | `AGENTS.md` の末尾に追記 | ファイル自体は置かない |
| `lefthook.factory.yml` | `lefthook.yml` の `pre-commit` に統合 | ファイル自体は置かない |

## 置いた後に人が行うこと

権限の変更なので、エージェントは行わない。

1. GitHub のシークレットに `ANTHROPIC_API_KEY`(と、必要なら `GITLEAKS_LICENSE`)を登録する。
2. ブランチ保護で、品質ゲートの 6 ステージと `secrets-scan` を必須チェックにし、コードオーナーのレビューを必須にする。
3. Claude Code の GitHub アプリをリポジトリに入れる(公式ドキュメントの GitHub Actions の手順に従う)。

## 動作の確認

```sh
# 危険なコマンドが拒否される(終了コード 2)
echo '{"tool_input":{"command":"git push --force"}}' | .claude/hooks/guard-bash.sh; echo $?
# 保護パスが拒否される(終了コード 2)
echo '{"tool_input":{"file_path":".claude/agents/reviewer.md"}}' | scripts/guard-paths.sh; echo $?
```

Claude Code で `/spec` と打ち、コマンドが候補に出ることと、`/agents` で 4 つの役割が見えることを確かめる。
