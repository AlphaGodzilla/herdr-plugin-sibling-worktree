#!/usr/bin/env bash
# herdr 插件 pane：输入分支名并在仓库同级目录创建 Git worktree。
#
# checkout 布局为 <repo 父目录>/<repo 名>-<branch slug>，让 worktree 与触发它的
# workspace 同级，而不是落在 worktrees.directory 下。分支由 `herdr worktree create`
# 创建；分支名留空时使用自动生成的 worktree/<hex>。
#
# 依赖：bash、git、stty（POSIX）。只使用 bash 3.2 兼容语法（macOS 自带 bash）。
set -euo pipefail

source "$(dirname "$0")/../lib/path.sh"

herdr="${HERDR_BIN_PATH:-herdr}"
context="${HERDR_PLUGIN_CONTEXT_JSON:-}"
saved_stty=""

die() {
  printf 'sibling-worktree: %s\n' "$1" >&2
  exit 1
}

# 整屏重绘一帧。顺序有硬约束：输入行必须最后输出、且不带换行——终端光标落在最后
# 输出的字符之后，这样光标自然停在 branch 输入处；把底部提示行放到输入行之后输出，
# 光标会掉到 pane 最底部。
render() {
  local buffer="$1" message="$2"
  printf '\033[2J\033[H'
  printf 'Sibling worktree\n\n'
  printf '  enter = create   esc = cancel\n\n'
  printf '  repo:     %s\n' "$repo_root"
  printf '  checkout: %s\n' "$(sibling_checkout_path "$repo_parent" "$repo_name" "${buffer:-$default_branch}")"
  printf '\n'
  if [ -n "$message" ]; then
    printf '  %s\n\n' "$message"
  fi
  printf '  branch [%s]\n' "$default_branch"
  printf '  > %s' "$buffer"
}

# 从 stdin（popup pane 的 pty）逐字节读入分支名，回车确认、Esc 取消。成功时把结果写入 REPLY。
#
# 回车要覆盖三种形态：raw 模式关掉 icrnl 后到达的是 CR；一旦有环节仍做 CR→LF 转换，
# read -n1 会把行分隔符当作分隔符吃掉并返回空串（而不是 "\n"），所以空串同样按回车处理。
prompt_branch() {
  local message="$1" buffer="" key
  saved_stty="$(stty -g)"
  trap 'stty "$saved_stty"' EXIT
  stty -echo -icanon -icrnl min 1 time 0
  while :; do
    render "$buffer" "$message"
    if ! IFS= read -rsn1 key; then
      stty "$saved_stty"
      trap - EXIT
      return 1
    fi
    case "$key" in
      $'\r' | $'\n') break ;;
      "") break ;;   # 回车：read -n1 把行分隔符当分隔符吃掉，返回空串
      $'\177' | $'\b') buffer="${buffer%?}" ;;
      $'\033') stty "$saved_stty"; trap - EXIT; return 1 ;;
      *) buffer="${buffer}${key}" ;;
    esac
  done
  stty "$saved_stty"
  trap - EXIT
  REPLY="$buffer"
  return 0
}

[ -n "$context" ] || die "HERDR_PLUGIN_CONTEXT_JSON is not set; run this pane from Herdr"

workspace_cwd="$(json_field "$context" workspace_cwd)" || workspace_cwd=""
repo_root="$(json_field "$context" repo_root)" || repo_root=""
repo_name="$(json_field "$context" repo_name)" || repo_name=""

# worktree 上下文缺失时（非 worktree workspace）回退到 workspace cwd 的 Git 根。
if [ -z "$repo_root" ]; then
  [ -n "$workspace_cwd" ] || die "no workspace cwd in the plugin context"
  if ! repo_root="$(git -C "$workspace_cwd" rev-parse --show-toplevel 2>/dev/null)"; then
    die "not inside a Git work tree: $workspace_cwd"
  fi
fi
[ -n "$repo_name" ] || repo_name="${repo_root##*/}"

repo_parent="${repo_root%/*}"
default_branch="worktree/$(printf '%04x' "$RANDOM")"

message=""
while :; do
  if ! prompt_branch "$message"; then
    printf '\033[2J\033[H\n  cancelled\n'
    exit 0
  fi
  branch="${REPLY:-$default_branch}"
  if git -C "$repo_root" check-ref-format --branch "$branch" >/dev/null 2>&1; then
    break
  fi
  message="invalid branch name: $branch"
done

checkout="$(sibling_checkout_path "$repo_parent" "$repo_name" "$branch")"

printf '\033[2J\033[H\n'
printf '  repo:     %s\n' "$repo_root"
printf '  branch:   %s\n' "$branch"
printf '  checkout: %s\n\n' "$checkout"
printf '  creating...\n\n'

# --cwd 指向主仓库根：herdr 拒绝从 linked worktree 触发创建，且据此把新 workspace
# 归组到同一 repo 的父 workspace 下。--path 必须是绝对路径。
if output="$("$herdr" worktree create \
  --cwd "$repo_root" \
  --branch "$branch" \
  --path "$checkout" \
  --no-focus 2>&1)"; then
  printf '  created\n'
  exit 0
fi

printf '  herdr worktree create failed:\n\n'
printf '%s\n' "$output"
printf '\n  press enter to close\n'
IFS= read -r _ || true
exit 1
