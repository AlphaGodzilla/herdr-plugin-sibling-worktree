#!/usr/bin/env bash
# herdr 插件 action：为当前 workspace 打开 sibling-worktree 输入 popup。
#
# action 命令的 stdout/stderr 会被 herdr 接管，没有 TTY，因此这里只负责弹出 pane；
# 分支名输入与实际创建都由 panes/prompt.sh 在 popup 里完成。
set -euo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
plugin_id="${HERDR_PLUGIN_ID:?HERDR_PLUGIN_ID is not set}"

exec "$herdr" plugin pane open --plugin "$plugin_id" --entrypoint prompt
