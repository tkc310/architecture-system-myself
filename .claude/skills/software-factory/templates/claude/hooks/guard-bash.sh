#!/usr/bin/env bash
# PreToolUse(Bash)。権限の規則はコマンドの形の一致なので、bash -c、xargs、変数などで包んだコマンドを取りこぼす。
# ここではコマンド全体を検査し、破壊的な操作は拒否(終了コード 2)、承認が要る操作は確認(ask)にする。
# 無人のジョブ(FACTORY_JOB がある)では、さらにジョブごとの許可リストに合うコマンドだけを通す。
# 規則を変えるときは、software-factory スキルの references/guardrails.md と ARCHITECTURE.md の「編集制約」も更新する。
set -uo pipefail

deny() {
  printf '拒否しました: %s\n代わりに: %s\n' "$1" "$2" >&2
  exit 2
}

# jq がなければ判定できないので、通さずに止める(fail closed)
command -v jq >/dev/null 2>&1 || deny "jq が見つからないため、コマンドを検査できません" "jq を入れる"

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) \
  || deny "フックの入力を読めませんでした" "人に確認する"
[ -z "$cmd" ] && exit 0

ask() {
  jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
  exit 0
}

# ---- ヒアドキュメントの本文を検査から外す ----
# 本文がデータとして渡るだけのコマンド(工場のスクリプト、git commit -F -)に限り、1 行目だけを検査する。
# 終端記号が引用符で囲まれている(<<'EOF' か <<"EOF")ときだけ外す。囲まれていないと本文の $( ) が展開されるため。
# 本文が終端の行で閉じ、その後ろに何もないことも条件にする。それ以外は全体を検査する。
scan="$cmd"
heredoc=0
first_line=${cmd%%$'\n'*}
delim=""
if [[ "$cmd" == *$'\n'* ]]; then
  if [[ "$first_line" =~ \<\<-?[[:space:]]*\'([A-Za-z_]+)\'[[:space:]]*$ ]]; then delim="${BASH_REMATCH[1]}"
  elif [[ "$first_line" =~ \<\<-?[[:space:]]*\"([A-Za-z_]+)\"[[:space:]]*$ ]]; then delim="${BASH_REMATCH[1]}"
  fi
fi
if [ -n "$delim" ]; then
  rest=${cmd#*$'\n'}
  if printf '%s\n' "$rest" | awk -v d="$delim" 'found { if ($0 !~ /^[[:space:]]*$/) bad=1; next } $0 == d { found=1 } END { exit !(found && !bad) }'; then
    if [[ "$first_line" =~ ^[[:space:]]*(\./)?scripts/factory/(post-review|open-draft-pr|open-issue)\.sh[[:space:]] ]] \
      || [[ "$first_line" =~ ^[[:space:]]*git[[:space:]]+commit[[:space:]] ]]; then
      scan="$first_line"
      heredoc=1
    fi
  fi
fi

# 拒否の規則は、引用符を取り除いた文字列にも当てる('-XPUT' や '.env' のように引用符で包んでも、bash は引用符を外して実行するため)
scan_dq=$(printf '%s' "$scan" | tr -d "'\"\\\\")
has() { printf '%s\n%s' "$scan" "$scan_dq" | grep -Eq -- "$1"; }
has_i() { printf '%s\n%s' "$scan" "$scan_dq" | grep -Eiq -- "$1"; }

# ---- 拒否: 取り消せない、または検査を回避する操作 ----
has '(^|[;&|[:space:](])rm[[:space:]](.*[[:space:]])?(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)([[:space:]]|$)' \
  && deny "再帰的な削除" "削除するファイルを列挙して人に確認する"
has 'git[[:space:]]+push.*([[:space:]](--force|--force-with-lease|--force-if-includes|--mirror|--all|--delete)([=[:space:]]|$)|[[:space:]]-[a-zA-Z]*[fd][a-zA-Z]*([[:space:]]|$)|[[:space:]:]\+)' \
  && deny "強制プッシュ、ブランチの削除、まとめてのプッシュ" "新しいコミットを積んで、対象のブランチだけを通常どおりプッシュする"
has 'git[[:space:]]+push.*[[:space:]:/](main|master)([[:space:]]|$)' \
  && deny "main への直接プッシュ" "ブランチを作って PR にする"
has 'git[[:space:]]+(reset[[:space:]]+--hard|clean[[:space:]]+-[a-zA-Z]*f|checkout[[:space:]]+--[[:space:]]+\.|restore[[:space:]]+(.*[[:space:]])?\.([[:space:]]|$))' \
  && deny "作業内容を捨てる操作" "git stash か、変更を個別に戻す"
has '--no-verify|--no-gpg-sign|HUSKY=0|LEFTHOOK=0|LEFTHOOK_EXCLUDE=|SKIP_HOOKS' \
  && deny "Git のフックや署名の回避" "フックが指摘した問題を直す"
has 'core\.hooksPath|lefthook[[:space:]]+(uninstall|remove)|\.git/hooks|git[[:space:]]+commit[[:space:]](.*[[:space:]])?-[a-zA-Z]*n[a-zA-Z]*([[:space:]]|$)' \
  && deny "Git のフックの無効化や書き換え" "フックが指摘した問題を直す。フックの設定は人が変える"
has 'gh[[:space:]](.*[[:space:]])?pr[[:space:]]+merge' \
  && deny "PR のマージ" "マージは人が行う"
has_i "gh[[:space:]](.*[[:space:]])?api([[:space:]].*)?[[:space:]](-X|--method)[=[:space:]]*['\"]?(POST|PUT|PATCH|DELETE)" \
  && deny "gh api での書き込み" "読み取りだけに使う。書き込みは決められたコマンドやスクリプトで行う"
has 'gh[[:space:]]+api([[:space:]].*)?[[:space:]](-[fF]|--field|--raw-field|--input)([=[:space:]]|[^[:space:]])' \
  && deny "gh api での書き込み" "読み取りだけに使う。書き込みは決められたコマンドやスクリプトで行う"
has '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z)?sh' \
  && deny "ダウンロードしたスクリプトの実行" "スクリプトを保存して内容を人に確認してもらう"
has_i 'curl.*([[:space:]](-X|--request)[=[:space:]]*(POST|PUT|PATCH|DELETE)|[[:space:]](-d|--data[a-z-]*|-F|--form|-T|--upload-file|--json)([=[:space:]]|[^[:space:]]))' \
  && deny "外部への送信" "送信は人の承認を得てから行う"
if printf '%s\n%s' "$scan" "$scan_dq" | sed -E 's/\.env\.example//g' | grep -Eq '(^|[^[:alnum:]_])\.env([.[:space:]]|$)|(~|HOME\}?)/\.npmrc|id_rsa|\.pem([[:space:]]|$)|\.key([[:space:]]|$)'; then
  deny "秘密情報のファイルへのアクセス" "必要な値の名前だけを人に確認する"
fi
# 依存の取得元と供給網の検査(.npmrc の registry、pnpm-workspace.yaml の trustPolicy など)を、コマンドの引数や環境変数で上書きさせない
has_i '(^|[[:space:];&|(])(npm|pnpm|yarn)[[:space:]]+config[[:space:]]+(set|delete|rm)|--registry([=[:space:]]|$)|(^|[^[:alnum:]_])(npm|pnpm)_config_|--config\.|--(trust-policy|minimum-release-age|block-exotic-subdeps|dangerously-allow-all-builds)|(>|tee[[:space:]]|sed[[:space:]]+-i).*(\.npmrc|pnpm-workspace\.yaml)' \
  && deny "依存の取得元や供給網の検査を変える操作" "取得元と検査の設定は人が変える(.npmrc と pnpm-workspace.yaml は保護パス)。公開は人が --registry を付けて行う"
# コマンドは Makefile のターゲットで叩く(architecture-selection の references/coding-conventions.md)。
# 引用符の中(コミットメッセージなど)は対象にしないため、引用符で囲んだ部分を消してから、コマンドの位置にあるかを見る。
scan_nq=$(printf '%s' "$scan" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")
cmdpos='(^|[;&|(]|&&|\|\||\$\(|`|xargs[[:space:]]+|exec[[:space:]]+|env[[:space:]]+|time[[:space:]]+|sudo[[:space:]]+)[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'
if printf '%s\n' "$scan_nq" | grep -Eq -- "${cmdpos}((pnpm|pnpx|npx|npm|yarn|bun|bunx|corepack|vitest|oxlint|oxfmt|tsc|depcruise|playwright|lefthook|tsx|drizzle-kit|shadcn)([[:space:]]|$)|(\./)?node_modules/\.bin/|node[[:space:]]+scripts/)"; then
  deny "make を通さないコマンド" "Makefile のターゲットを使う(make help で一覧)。足りなければ、Makefile にターゲットを足すことを人に提案する"
fi
# make の呼び方を絞る。オプション(-f、-C、-e、--eval など)と、pkg=、name=、args= 以外の変数の指定(SHELL= などでレシピを書き換えられる)を拒否する
if printf '%s\n' "$scan_nq" | grep -Eq -- "${cmdpos}(g?make)([[:space:]]|$)"; then
  printf '%s\n' "$scan_dq" | grep -Eq -- '(^|[[:space:]])(MAKE[A-Z_]*|GNUMAKEFLAGS)=' \
    && deny "make の動きを変える環境変数" "make <ターゲット> だけで叩く"
  printf '%s\n' "$scan_nq" | grep -Eq -- '(^|[[:space:];&|(])g?make([[:space:]]+[^;&|)]*)?[[:space:]]-' \
    && deny "make のオプション" "make <ターゲット> だけで叩く"
  printf '%s\n' "$scan" | grep -Eq -- '(^|[[:space:];&|(])g?make[[:space:]]([^;&|)]*[[:space:]])?([A-Za-z_.][A-Za-z0-9_.]*)=' \
    && ! printf '%s\n' "$scan" | grep -Eq -- '(^|[[:space:];&|(])g?make[[:space:]]([^;&|)=]*[[:space:]])?((pkg|name|args)=('"'"'[^'"'"']*'"'"'|"[^"]*"|[^[:space:]]*)[[:space:]]*)+([^;&|)=]*)$' \
    && deny "make の変数の指定(pkg=、name=、args= 以外)" "値は pkg=、name=、args= で渡す"
fi

has '(kubectl|helm)[[:space:]]+(apply|delete|upgrade|install)|terraform[[:space:]]+(apply|destroy)|(vercel|netlify|flyctl|fly|wrangler)[[:space:]].*(deploy|--prod)' \
  && deny "本番や共有環境への操作" "デプロイは CI と人の承認を通す"

# 工場の書き込み用スクリプトは、決められた無人ジョブの中でだけ使える。呼び方(相対パス、cd の後など)を問わず、名前で判定する。
# FACTORY_JOB はジョブの実行環境(GitHub Actions のワークフロー、ルーティンのクラウド環境)が設定する値で、
# エージェントが Bash で設定しても、このフックのプロセスには届かない。
if has '(^|[/[:space:];&|(])post-review\.sh' && [ "${FACTORY_JOB:-}" != "review" ]; then
  deny "レビュー結果の投稿" "レビュー結果はレビュー用のジョブだけが投稿する"
fi
if has '(^|[/[:space:];&|(])(open-draft-pr|open-issue)\.sh' && [ "${FACTORY_JOB:-}" != "improve" ]; then
  deny "改善ジョブ用の PR や Issue の作成" "手元では /build の手順で PR を作る"
fi

# main ブランチ上でのコミット
if has 'git[[:space:]]+commit'; then
  branch=$(git -C "${CLAUDE_PROJECT_DIR:-.}" symbolic-ref --short HEAD 2>/dev/null || echo "")
  case "$branch" in
    main|master) deny "main ブランチ上でのコミット" "作業用のブランチを作る(/build の手順)" ;;
  esac
fi

# ---- 無人のジョブ: 許可リスト ----
# 無人のジョブには確認に応える人がいない。ルーティンはツールを絞る設定もないので、ここで厳しく絞る。
# - 1 回の呼び出しで 1 つのコマンドだけ。シェルの記号(; & | < > ( ) { } $ ` \ * ? [ ] ~ と改行)は引用符の外では使えない
# - 二重引用符の中でも $ ` \ は使えない(展開されるため)
# - コマンドはジョブごとの決まった形だけ。コードを実行したりファイルを書いたりできるオプションは拒否する
if [ -n "${FACTORY_JOB:-}" ]; then
  unq=""; state=n; dq_bad=0
  for ((i = 0; i < ${#scan}; i++)); do
    c="${scan:i:1}"
    case "$state" in
      n) case "$c" in
           "'"|'"')
             # 単語の先頭で引用符が開き、中身が - で始まるもの('-XPUT' など)は、オプションを隠せるので拒否する
             if { [ -z "$unq" ] || [ "${unq: -1}" = " " ]; } && [ "${scan:i+1:1}" = "-" ]; then
               deny "引用符で包んだオプション" "オプションは引用符で包まずに書く"
             fi
             [ "$c" = "'" ] && state=s || state=d ;;
           *) unq+="$c" ;;
         esac ;;
      s) [ "$c" = "'" ] && { state=n; unq+="Q"; } ;;
      d) case "$c" in
           '"') state=n; unq+="Q" ;;
           '$'|'`'|'\') dq_bad=1 ;;
         esac ;;
    esac
  done
  [ "$state" = n ] || deny "引用符が閉じていません" "引用符を閉じる"
  [ "$dq_bad" = 0 ] || deny "二重引用符の中の \$ \` \\" "値は単一引用符で渡す"
  [ "$heredoc" = 1 ] && unq=$(printf '%s' "$unq" | sed -E 's/[[:space:]]*<<-?[[:space:]]*Q[[:space:]]*$//')
  if [[ "$unq" == *$'\n'* ]] || printf '%s' "$unq" | grep -q '[][;&|<>(){}$`\\*?~]'; then
    deny "無人のジョブでの複数のコマンド、リダイレクト、展開、ワイルドカード、引用符で囲まれていない記号" "コマンドは 1 回に 1 つずつ実行する。引数の中の { } ? & などの記号は単一引用符で囲む。ファイルの編集は Edit / Write ツールで行う"
  fi
  unq=$(printf '%s' "$unq" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/[[:space:]]+/ /g')
  # - で始まる単語の途中に引用符があるもの(-'-output=x' や --o'utput' など)も、オプションを隠せるので拒否する
  if printf '%s' "$unq" | grep -Eq -- '(^| )-[^ ]*Q'; then
    deny "引用符を含むオプション" "オプションは引用符を使わずに書く"
  fi

  # コードの実行やファイルの書き込みにつながるオプションは、どのコマンドでも拒否する。
  # 省略した長いオプション(--outp=x など)はこの正規表現をすり抜けるが、git と gh は省略形を受け付けないので効かない。
  # 省略形を受け付けるツールを許可リストに足すときは、この前提が崩れないか確かめること。
  # ただし、許可リストにある決まった形(git switch -c、git commit -F -)の中の同じ文字は除いてから調べる
  opts=$(printf '%s' "$unq" | sed -E 's/^git switch -c /git switch /; s/^git commit -F -$/git commit/')
  if printf '%s' "$opts" | grep -Eq -- '(^| )(--output|--upload-pack|--receive-pack|--exec|--ext-diff|--textconv|--no-index|--config|--git-dir|--work-tree|-c|-C|-o|--pre|--rawfile|--slurpfile|--input|--method|--field|--raw-field)([= ]|$)|(^| )-[XfF]'; then
    deny "無人のジョブで使えないオプション" "docs/factory/ の手順にある形でコマンドを使う"
  fi

  # ファイルを読むコマンドは、リポジトリの中だけ(.git/ とリポジトリの外は読ませない。トークンや秘密情報が置かれうるため)
  if printf '%s' "$unq" | grep -Eq '^(cat|ls|head|tail|wc|jq|grep)( |$)'; then
    deq_args=$(printf '%s' "$scan" | tr -d "'\"")
    if printf '%s' "$deq_args" | grep -Eq '(^|[[:space:]=])(/|\.\.)|(^|[[:space:]=/])\.git(/|[[:space:]]|$)|\.\./'; then
      deny "リポジトリの外や .git/ の読み取り" "リポジトリの中のファイルだけを読む"
    fi
  fi

  ref='[A-Za-z0-9._/-]+'
  common="git (diff|log|show|status|rev-parse)( .*)?|git fetch origin ${ref}|gh api (-H Q )?Q( .*)?|gh api (-H Q )?repos/[^ ]+( .*)?|gh run (list|view)( .*)?|(cat|ls|head|tail|wc|jq|grep|date|echo|pwd)( .*)?"
  case "$FACTORY_JOB" in
    review)  allowed="${common}|(\./)?scripts/factory/post-review\.sh [0-9]+ [0-9a-f]{40} (approve|changes)" ;;
    improve) allowed="${common}|git switch -c claude/factory-improve-[A-Za-z0-9._-]+ origin/main|git switch (main|claude/factory-improve-[A-Za-z0-9._-]+)|git add( -A)?( [^ -][^ ]*)*|git commit (-m Q|-F -)|git push -u origin claude/factory-improve-[A-Za-z0-9._-]+|make (check|check-versions|lint|lint-deps|test|format)|(\./)?scripts/factory/(open-draft-pr\.sh claude/factory-improve-[A-Za-z0-9._-]+ Q|open-issue\.sh Q)" ;;
    *) deny "不明な FACTORY_JOB(${FACTORY_JOB})" "review か improve を設定する" ;;
  esac
  printf '%s' "$unq" | grep -Eq -- "^(${allowed})$" \
    || deny "このジョブで許可していないコマンド: ${unq}" "docs/factory/ の手順にあるコマンドだけを、決まった形で使う"
  exit 0
fi

# GitHub Actions でも確認に応える人はいない。--allowedTools で絞っているので、確認は省く
if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
  exit 0
fi

# ---- 確認: 承認が要る操作 ----
has '(^|[[:space:];&|(])g?make[[:space:]]([^;&|]*[[:space:]])?(add|add-dev|remove|install|setup|generate|ui-add|ui-update)([[:space:]]|$)' \
  && ask "依存の追加や削除、取り込みです。目的、代替、ライセンス、保守状況を確認してください。"
has 'drizzle-kit[[:space:]]+(push|migrate)|prisma[[:space:]]+(migrate[[:space:]]+deploy|db[[:space:]]+push)|DATABASE_URL=' \
  && ask "マイグレーションの適用か、データベースへの接続先の指定です。対象の環境を確認してください。"
has 'git[[:space:]]+push' \
  && ask "リモートへのプッシュです。"
has 'gh[[:space:]]+(pr[[:space:]]+(create|comment|review|close|edit)|issue[[:space:]]+(create|comment|close|edit)|release)' \
  && ask "GitHub への書き込みです。"

exit 0
