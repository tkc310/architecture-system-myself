#!/usr/bin/env bash
# 保護パスへの書き込みと削除を拒否する。Cursor の preToolUse と Claude Code の PreToolUse の両方から呼ぶ。
# 標準入力の JSON から対象のパスを取り出し、保護パスに当たれば終了コード 2 で止める。
# 保護パスを変えるときは references/editing-constraints.md と ARCHITECTURE.md も更新する。
set -uo pipefail

input=$(cat)
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // .file_path // .path // empty' 2>/dev/null)
[ -z "$path" ] && exit 0

root="${CLAUDE_PROJECT_DIR:-${CURSOR_PROJECT_DIR:-$PWD}}"
rel="${path#"$root"/}"

# 週次の改善ジョブ(CI 上、software-factory の factory-improve.yml)だけは、規則を強める変更のために
# lint と依存ルールの設定、AGENTS.md を編集できる。変更は下書き PR になり、CODEOWNERS の承認を経てマージされる。
# エージェントは自分の環境変数を変えられないので、手元のセッションではこの例外は効かない。
if [ "${GITHUB_ACTIONS:-}" = "true" ] && [ "${FACTORY_JOB:-}" = "improve" ]; then
  case "$rel" in
    .dependency-cruiser.cjs|.oxlintrc.json|AGENTS.md) exit 0 ;;
  esac
fi

case "$rel" in
  db/migrations/*|src/shared/auth/*|src/generated/*|\
  infra/*|.github/*|Dockerfile|.env|.env.*|\
  package.json|pnpm-lock.yaml|package-lock.json|yarn.lock|\
  .cursor/*|.claude/*|scripts/guard-paths.sh|scripts/check-edited-file.sh|lefthook.yml|\
  .dependency-cruiser.cjs|.oxlintrc.json|CODEOWNERS|AGENTS.md|CLAUDE.md|docs/factory/*)
    printf '%s は保護パスです。編集する前にユーザーの明示的な許可を得てください(references/editing-constraints.md)。生成コードは生成元を直してください。\n' "$rel" >&2
    exit 2
    ;;
esac

exit 0
