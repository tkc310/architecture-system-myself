#!/usr/bin/env bash
# Stop。コードに変更があるのに make check が通らない状態での完了を止め、失敗の内容をエージェントに返す。
# 同じセッションで 2 回止めても直らないときは、止めずに人へ引き継ぐ(無限に続けない)。
set -uo pipefail

input=$(cat)
# push の前の独立レビュー(local-review.sh)の中では止めない。レビューは編集できないので、止めても直せない
[ -n "${FACTORY_LOCAL_REVIEW:-}" ] && exit 0
root="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$root" || exit 0

# コードの変更がなければ何もしない
changed=$(git status --porcelain --untracked-files=all 2>/dev/null | grep -E '\.(ts|tsx|js|jsx|mts|cts|mjs|cjs|json|jsonc|css)$' || true)
[ -z "$changed" ] && exit 0

session=$(printf '%s' "$input" | jq -r '.session_id // "unknown"' 2>/dev/null)
counter="${TMPDIR:-/tmp}/factory-stop-${session}"
count=$(cat "$counter" 2>/dev/null || echo 0)

if out=$(make check 2>&1); then
  rm -f "$counter"
  exit 0
fi

if [ "$count" -ge 2 ]; then
  rm -f "$counter"
  # 止めずに終える。人が状況を見て判断する。
  exit 0
fi

echo $((count + 1)) > "$counter"
{
  echo "make check が通っていません。完了と報告する前に直してください(規則を無効化しないこと)。"
  echo "直せない理由があるなら、その理由と現状を人に説明してください。"
  echo "---- 失敗の末尾 ----"
  printf '%s\n' "$out" | tail -n 40
} >&2
exit 2
