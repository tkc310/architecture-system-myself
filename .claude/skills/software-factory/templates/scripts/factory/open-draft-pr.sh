#!/usr/bin/env bash
# 週次の改善ジョブが、規則を強める下書き PR を作る。マージはしない。
#
# 使い方: scripts/factory/open-draft-pr.sh <ブランチ名> "<タイトル>" <<'EOF'
#         (PR の説明。週次の報告を含める)
#         EOF
#
# ブランチ名は claude/factory-improve- で始まるものだけを受け付ける。
# FACTORY_JOB=improve の無人ジョブからだけ呼ばれる(guard-bash.sh が強制する)。GitHub の REST API だけを使う。
set -euo pipefail

head="${1:-}"
title="${2:-}"
case "$head" in
  claude/factory-improve-*) ;;
  *) echo "ブランチ名は claude/factory-improve- で始めてください" >&2; exit 1 ;;
esac
[ -z "$title" ] && { echo "タイトルを指定してください" >&2; exit 1; }

body=$(cat)
[ -z "$body" ] && { echo "説明を標準入力で渡してください" >&2; exit 1; }

base=$(gh api "repos/{owner}/{repo}" --jq '.default_branch')

printf '%s\n' "$body" | gh api -X POST "repos/{owner}/{repo}/pulls" \
  -f title="$title" \
  -f head="$head" \
  -f base="$base" \
  -F draft=true \
  -F body=@- \
  --jq '.html_url'
