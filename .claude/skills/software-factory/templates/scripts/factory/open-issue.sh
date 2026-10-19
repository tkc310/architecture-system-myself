#!/usr/bin/env bash
# 週次の改善ジョブが、週次の報告(毎週 1 件)と、PR にできない提案(規則を緩める変更、.claude/ や .github/ の変更、
# 既存コードの違反、版の更新)を Issue にする。ラベル factory-improve を付ける。
#
# 使い方: scripts/factory/open-issue.sh "<タイトル>" <<'EOF'
#         (本文)
#         EOF
#
# FACTORY_JOB=improve の無人ジョブからだけ呼ばれる(guard-bash.sh が強制する)。GitHub の REST API だけを使う。
set -euo pipefail

title="${1:-}"
[ -z "$title" ] && { echo "タイトルを指定してください" >&2; exit 1; }
body=$(cat)
[ -z "$body" ] && { echo "本文を標準入力で渡してください" >&2; exit 1; }

printf '%s\n' "$body" | gh api -X POST "repos/{owner}/{repo}/issues" \
  -f title="[factory] ${title}" \
  -f "labels[]=factory-improve" \
  -F body=@- \
  --jq '.html_url'
