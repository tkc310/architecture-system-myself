#!/usr/bin/env bash
# エージェントがファイルを編集した直後に、書式修正と境界ルールの検査を行う。
# 違反があれば終了コード 2 で stderr に理由を出し、エージェントに修正させる。
set -uo pipefail

file=$(jq -r '.tool_input.file_path // empty')
[ -z "$file" ] && exit 0
[ -f "$file" ] || exit 0

case "$file" in
  *.ts|*.tsx|*.js|*.jsx|*.json|*.jsonc) ;;
  *) exit 0 ;;
esac

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
rel="${file#"$PWD"/}"

if ! out=$(pnpm exec biome check --write --no-errors-on-unmatched "$rel" 2>&1); then
  printf 'Biome の検査に失敗しました(%s):\n%s\n' "$rel" "$out" >&2
  exit 2
fi

case "$rel" in
  src/*.ts|src/*.tsx)  # case の * は / にも一致するので src 配下すべてが対象
    if ! out=$(pnpm exec depcruise --config .dependency-cruiser.cjs "$rel" 2>&1); then
      printf '境界ルール違反です(%s)。ルールを外さず、構成に沿って修正してください:\n%s\n' "$rel" "$out" >&2
      exit 2
    fi
    ;;
esac

exit 0
