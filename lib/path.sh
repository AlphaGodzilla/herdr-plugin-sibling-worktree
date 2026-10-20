# 共享纯函数：插件上下文解析与 checkout 路径计算。
# 由 panes/prompt.sh 以 `source "$(dirname "$0")/../lib/path.sh"` 载入。

# json_field <json> <key>：从 herdr 注入的紧凑 JSON 中取出顶层字符串字段。
# 键缺失或值不是字符串时返回 1。JSON 由 serde_json 序列化，字段名唯一且互不为前缀。
json_field() {
  local rest="${1#*\"$2\":\"}"
  [ "$rest" != "$1" ] || return 1
  printf '%s' "${rest%%\"*}"
}

# slugify <branch>：把分支名转成目录名片段，规则与 herdr 的 branch_to_path_slug 一致：
# 小写 ASCII，其余字符折叠为单个 '-'，并去掉首尾 '-'。
slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9][^a-z0-9]*/-/g' -e 's/^-//' -e 's/-$//'
}

# sibling_checkout_path <repo_parent> <repo_name> <branch>
# 生成同级 checkout 目录：<repo_parent>/<repo_name>-<branch_slug>。
# 分支名不含可用的 slug 字符时退回 "worktree"。
sibling_checkout_path() {
  local slug
  slug="$(slugify "$3")"
  [ -n "$slug" ] || slug="worktree"
  printf '%s/%s-%s' "$1" "$2" "$slug"
}
