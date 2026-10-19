#!/usr/bin/env bash
# レビュー結果を PR に投稿し、PR の先頭コミットにステータス factory/review を付ける。
# ブランチ保護で factory/review を必須チェックにすると、レビューを通っていないコミットはマージできない。
# ステータスはコミットに付くので、新しいコミットを push するとレビューのやり直しが要る。
#
# 使い方: scripts/factory/post-review.sh <PR 番号> <レビューしたコミットの sha> <approve|changes> <<'EOF'
#         (reviewer.md の出力形式の本文)
#         EOF
#
# FACTORY_JOB=review の無人ジョブ(GitHub Actions かルーティン)からだけ呼ばれる(guard-bash.sh が強制する)。
# GitHub の REST API だけを使う(GraphQL が使えない環境でも動くように)。
set -euo pipefail

pr="${1:-}"
reviewed="${2:-}"
verdict="${3:-}"
case "$pr" in ''|*[!0-9]*) echo "PR 番号を数字で指定してください" >&2; exit 1 ;; esac
case "$reviewed" in
  *[!0-9a-f]*|'') echo "レビューしたコミットの sha(40 文字)を指定してください" >&2; exit 1 ;;
esac
[ ${#reviewed} -eq 40 ] || { echo "レビューしたコミットの sha(40 文字)を指定してください" >&2; exit 1; }
case "$verdict" in
  approve) state=success; label="承認" ;;
  changes) state=failure; label="要修正" ;;
  *) echo "判定は approve か changes で指定してください" >&2; exit 1 ;;
esac

body=$(cat)
[ -z "$body" ] && { echo "本文を標準入力で渡してください" >&2; exit 1; }

# レビューの間に push されたコミットを、レビューしていないのに承認しないよう、先頭が変わっていたら止める
sha=$(gh api "repos/{owner}/{repo}/pulls/${pr}" --jq '.head.sha')
if [ "$sha" != "$reviewed" ]; then
  echo "PR の先頭が ${reviewed:0:7} から ${sha:0:7} に変わりました。新しいコミットでレビューし直してください" >&2
  exit 1
fi
marker="<!-- factory-review sha=${sha} verdict=${verdict} -->"

url=$(printf '%s\n\n%s\n' "$marker" "$body" \
  | gh api -X POST "repos/{owner}/{repo}/issues/${pr}/comments" -F body=@- --jq '.html_url')

gh api -X POST "repos/{owner}/{repo}/statuses/${sha}" \
  -f state="$state" \
  -f context="factory/review" \
  -f description="エージェントのレビュー: ${label}" \
  -f target_url="$url" >/dev/null

echo "投稿しました: ${url}(factory/review = ${state}, ${sha:0:7})"
