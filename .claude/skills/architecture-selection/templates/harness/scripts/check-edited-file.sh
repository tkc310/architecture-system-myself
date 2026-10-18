#!/usr/bin/env bash
# エージェントがファイルを編集した直後に、整形・lint・依存ルールを検査する。Claude Code の PostToolUse から呼ぶ。
# 違反があれば終了コード 2 で理由を stderr に返し、エージェントに直させる。
set -uo pipefail

path=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
[ -z "$path" ] || [ ! -f "$path" ] && exit 0

root="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$root" || exit 0
rel="${path#"$root"/}"

case "$rel" in
  src/generated/*) exit 0 ;;
  *.ts|*.tsx|*.js|*.jsx|*.mts|*.cts) ;;
  *) exit 0 ;;
esac

fail() {
  printf '%s\n%s\n' "$1" "$2" >&2
  exit 2
}

pnpm exec oxfmt "$rel" >/dev/null 2>&1

if ! out=$(pnpm exec oxlint "$rel" 2>&1); then
  fail "oxlint の検査に失敗しました($rel)。ルールを無効化せずに直してください:" "$out"
fi

case "$rel" in
  src/*)
    if ! out=$(pnpm exec depcruise --config .dependency-cruiser.cjs "$rel" 2>&1); then
      fail "依存ルールの違反です($rel)。ルールを外さず、ARCHITECTURE.md の構造に沿って直してください:" "$out"
    fi
    ;;
esac

exit 0
