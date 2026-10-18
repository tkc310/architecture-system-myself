#!/usr/bin/env bash
# PreToolUse(Bash)。権限の規則は文字列の前方一致なので、パイプやサブシェルで包んだコマンドを取りこぼす。
# ここではコマンド全体を検査し、破壊的な操作は拒否(終了コード 2)、承認が要る操作は確認(ask)にする。
# 規則を変えるときは references/guardrails.md と ARCHITECTURE.md の「編集制約」も更新する。
set -uo pipefail

cmd=$(jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

deny() {
  printf '拒否しました: %s\n代わりに: %s\n' "$1" "$2" >&2
  exit 2
}

ask() {
  jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
  exit 0
}

has() { printf '%s' "$cmd" | grep -Eq -- "$1"; }

# ---- 拒否: 取り消せない、または検査を回避する操作 ----
has '(^|[;&|[:space:]])rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r|-r[[:space:]]+-f|-f[[:space:]]+-r|--recursive)' \
  && deny "再帰的な削除(rm -rf)" "削除するファイルを列挙して人に確認する"
has 'git[[:space:]]+push.*([[:space:]]--force|[[:space:]]-f([[:space:]]|$)|--force-with-lease|[[:space:]]\+)' \
  && deny "強制プッシュ" "新しいコミットを積んで通常のプッシュをする"
has 'git[[:space:]]+push.*[[:space:]](origin[[:space:]]+)?(main|master)([[:space:]]|$|:)' \
  && deny "main への直接プッシュ" "ブランチを作って PR にする"
has 'git[[:space:]]+(reset[[:space:]]+--hard|clean[[:space:]]+-[a-zA-Z]*f|checkout[[:space:]]+--[[:space:]]+\.)' \
  && deny "作業内容を捨てる操作" "git stash か、変更を個別に戻す"
has '--no-verify|--no-gpg-sign|HUSKY=0|LEFTHOOK=0|LEFTHOOK_EXCLUDE=|SKIP_HOOKS' \
  && deny "Git のフックや署名の回避" "フックが指摘した問題を直す"
has 'core\.hooksPath|lefthook[[:space:]]+(uninstall|remove)|\.git/hooks|git[[:space:]]+commit[[:space:]](.*[[:space:]])?-[a-zA-Z]*n[a-zA-Z]*([[:space:]]|$)' \
  && deny "Git のフックの無効化や書き換え" "フックが指摘した問題を直す。フックの設定は人が変える"
has 'gh[[:space:]]+pr[[:space:]]+merge|gh[[:space:]]+api.*-X[[:space:]]*(PUT|DELETE).*merge' \
  && deny "PR のマージ" "マージは人が行う"
has 'gh[[:space:]]+api.*([[:space:]](-X|--method)[[:space:]]*(POST|PUT|PATCH|DELETE)|[[:space:]](-f|-F|--field|--raw-field|--input)[[:space:]])' \
  && deny "gh api での書き込み" "読み取りだけに使う。書き込みは gh の専用コマンド(gh pr comment など)で行う"
has '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z)?sh' \
  && deny "ダウンロードしたスクリプトの実行" "スクリプトを保存して内容を人に確認してもらう"
has 'curl.*([[:space:]]-X[[:space:]]*(POST|PUT|PATCH|DELETE)|[[:space:]](-d|--data[a-z-]*|-F|--form|-T|--upload-file)[[:space:]=])' \
  && deny "外部への送信" "送信は人の承認を得てから行う"
if printf '%s' "$cmd" | sed -E 's/\.env\.example//g' | grep -Eq '(^|[^[:alnum:]_])\.env([.[:space:]]|$)|id_rsa|\.pem([[:space:]]|$)|\.key([[:space:]]|$)'; then
  deny "秘密情報のファイルへのアクセス" "必要な値の名前だけを人に確認する"
fi
has '(kubectl|helm)[[:space:]]+(apply|delete|upgrade|install)|terraform[[:space:]]+(apply|destroy)|(vercel|netlify|flyctl|fly|wrangler)[[:space:]].*(deploy|--prod)' \
  && deny "本番や共有環境への操作" "デプロイは CI と人の承認を通す"

# 工場の書き込み用スクリプトは、決められた無人ジョブの中でだけ使える。
# FACTORY_JOB はジョブの実行環境(GitHub Actions のワークフロー、ルーティンのクラウド環境)が設定する値で、
# エージェントが Bash で設定しても、このフックのプロセスには届かない。
if has 'scripts/factory/post-review\.sh' && [ "${FACTORY_JOB:-}" != "review" ]; then
  deny "レビュー結果の投稿" "レビュー結果はレビュー用のジョブだけが投稿する"
fi
if has 'scripts/factory/(open-draft-pr|open-issue)\.sh' && [ "${FACTORY_JOB:-}" != "improve" ]; then
  deny "改善ジョブ用の PR 作成" "手元では /build の手順で PR を作る"
fi

# main ブランチ上でのコミット
if has 'git[[:space:]]+commit'; then
  branch=$(git -C "${CLAUDE_PROJECT_DIR:-.}" symbolic-ref --short HEAD 2>/dev/null || echo "")
  case "$branch" in
    main|master) deny "main ブランチ上でのコミット" "作業用のブランチを作る(/build の手順)" ;;
  esac
fi

# 無人のジョブ(GitHub Actions、ルーティン)では確認を出しても応える人がいない。
# 無人のジョブは、使えるツールと書き込み先をジョブの側で絞っているので、確認は省く。拒否は上で効いている。
if [ "${GITHUB_ACTIONS:-}" = "true" ] || [ -n "${FACTORY_JOB:-}" ]; then
  exit 0
fi

# ---- 確認: 承認が要る操作 ----
has '(pnpm|npm|yarn|bun)[[:space:]]+(add|install[[:space:]]+[^-]|i[[:space:]]+[^-]|remove|rm|uninstall)' \
  && ask "依存の追加や削除です。目的、代替、ライセンス、保守状況を確認してください。"
has 'drizzle-kit[[:space:]]+(push|migrate)|prisma[[:space:]]+(migrate[[:space:]]+deploy|db[[:space:]]+push)|DATABASE_URL=' \
  && ask "マイグレーションの適用か、データベースへの接続先の指定です。対象の環境を確認してください。"
has 'git[[:space:]]+push' \
  && ask "リモートへのプッシュです。"
has 'gh[[:space:]]+(pr[[:space:]]+(create|comment|review|close|edit)|issue[[:space:]]+(create|comment|close|edit)|release)' \
  && ask "GitHub への書き込みです。"

exit 0
