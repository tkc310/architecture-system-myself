#!/usr/bin/env bash
# 形式 B: push の前に、手元の Claude Code(サブスクリプション)で独立レビューを行う。lefthook の pre-push から呼ぶ。
# 必須の指摘があれば push を止める。早く指摘を得るためのもので、--no-verify で飛ばせる。
# マージの条件は GitHub 側のルーティンが付ける factory/review なので、飛ばしてもマージはできない。
set -uo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root" || exit 0

# エージェント自身が push したとき(Claude Code のセッションの中)は、入れ子のセッションを起こさない
if [ -n "${CLAUDECODE:-}" ]; then
  echo "[factory] Claude Code のセッションの中からの push なので、手元のレビューを省きます。/review で受けてください(PR ではルーティンがレビューします)。" >&2
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "[factory] claude が見つからないため、手元のレビューを省きます(PR ではルーティンがレビューします)。" >&2
  exit 0
fi

base_ref=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || echo "origin/main")
git fetch -q origin "${base_ref#origin/}" 2>/dev/null || true
if ! git rev-parse -q --verify "${base_ref}^{commit}" >/dev/null; then
  echo "[factory] 比較元 ${base_ref} が見つからないため、手元のレビューを省きます(PR ではルーティンがレビューします)。" >&2
  exit 0
fi

# 比較元との差分がなければ(main 上など)レビューしない
if [ -z "$(git rev-list "${base_ref}..HEAD" 2>/dev/null)" ]; then
  exit 0
fi

# ブランチ名 feat/0012-xxx から仕様 docs/specs/0012-*.md を探す
branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
num=$(printf '%s' "$branch" | sed -nE 's#^[a-z]+/([0-9]{4})-.*#\1#p')
spec=""
[ -n "$num" ] && spec=$(ls docs/specs/"${num}"-*.md 2>/dev/null | head -n 1)
spec_line="仕様は ${spec} です。"
[ -z "$spec" ] && spec_line="仕様のファイルはありません。コミットメッセージ(git log ${base_ref}..HEAD)を仕様の代わりにしてください。"

sha=$(git rev-parse HEAD)
out_dir="$(git rev-parse --git-dir)/factory/reviews"
mkdir -p "$out_dir"
out="${out_dir}/${sha}.md"

echo "[factory] push の前に独立レビューを行います(${sha:0:7})..." >&2
# FACTORY_LOCAL_REVIEW: Stop フック(require-check-on-stop.sh)にレビューを止めさせない。
# < /dev/null: lefthook が標準入力で渡す ref の一覧を、プロンプトとして読ませない。
FACTORY_LOCAL_REVIEW=1 claude -p "あなたは .claude/agents/reviewer.md の reviewer です。そのファイルを読み、指示に従ってください。
${spec_line}
差分は git diff ${base_ref}...HEAD で取ってください。ファイルは編集しません。
出力は reviewer.md の出力形式だけにしてください。" \
  --allowedTools "Read,Grep,Glob,Bash(git diff *),Bash(git log *),Bash(git show *)" \
  --output-format text < /dev/null > "$out" 2>&1
status=$?

cat "$out" >&2
if [ $status -ne 0 ]; then
  echo "[factory] レビューを実行できませんでした(終了コード ${status})。push は止めません。PR ではルーティンがレビューします。" >&2
  exit 0
fi

if grep -Eq '^##[[:space:]]*判定:[[:space:]]*要修正' "$out"; then
  echo "[factory] 必須の指摘があります。直してから push してください(結果: ${out})。" >&2
  exit 1
fi
exit 0
