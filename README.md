# Sibling Worktree

[English](README.en.md) | **中文**

Herdr 插件，让 worktree 的 checkout 目录落在仓库同级，而不是 `worktrees.directory` 之下。
按快捷键后弹出输入框，输入分支名即可创建 `<repo 父目录>/<repo 名>-<branch slug>`，例如：

```
workspace:  ~/proj/myrepo
branch:     feature/x
checkout:   ~/proj/myrepo-feature-x
```

## 安装

两种方式任选其一，插件 ID 都是 `sibling-worktree`，注册结果全局生效。

### 从 GitHub 安装

```bash
herdr plugin install AlphaGodzilla/herdr-plugin-sibling-worktree
herdr plugin install AlphaGodzilla/herdr-plugin-sibling-worktree -y          # 已信任该源，跳过预览确认
herdr plugin install AlphaGodzilla/herdr-plugin-sibling-worktree --ref v0.1.0   # 固定到某个 tag 或 commit
herdr plugin update sibling-worktree          # 之后跟随上游升级
herdr plugin action list --plugin sibling-worktree
```

`install` 用 `git` 克隆仓库到 Herdr 托管的安装目录；在交互式终端里会先预览清单与将要执行的命令，确认后才注册。

### 本地安装（自用或开发）

```bash
herdr plugin link ~/.pi/herdr-plugins/sibling-worktree   # 换成你本机的插件工作目录
herdr plugin action list --plugin sibling-worktree
```

`link` 直接使用工作区目录，不执行 manifest 里的 build 命令（本插件没有 build），改代码后无需重新注册。

同一个插件 ID 不能既是本地 `link` 又是 GitHub 安装：已 `link` 过时再 `install` 会被拒绝，需要先 `herdr plugin unlink sibling-worktree`。

### 键位（两种安装方式相同）

把内置的 New worktree 解绑，并用同一键位触发插件（`~/.config/herdr/config.toml`）：

```toml
[keys]
new_worktree = ""          # 解绑内置；内置会写到 <worktrees.directory>/<repo>/<slug>

[[keys.command]]
key = "prefix+shift+g"
type = "plugin_action"
command = "sibling-worktree.create"
description = "create sibling worktree"
```

保存后在 Herdr 内执行 `reload config`（默认 `prefix+shift+r`），或运行 `herdr server reload-config`。

## 覆盖范围

| 创建入口 | 是否被本插件覆盖 |
| --- | --- |
| 快捷键（`keys.new_worktree` 的键位） | 覆盖，需按上面的配置解绑内置 |
| 鼠标右键 workspace 行 → `New worktree` | 不覆盖；客户端菜单项硬编码为内置动作 |
| `herdr worktree create`（不带 `--path`） | 不覆盖；由 server 按 `worktrees.directory` 计算 |
| 其他插件调用 `worktree.create`（不带 `path`） | 不覆盖，同上 |

`Open worktree...` 与 `Delete worktree checkout...` 无需覆盖：本插件创建的也是 herdr 管理的普通 Git worktree，内置的打开与删除动作对它们同样有效。

要让内置入口也改用同级路径，只能修改 herdr 本体：server 端 `src/worktree.rs::default_checkout_path`（决定不带 `--path` 时的路径）与 client 端 `src/client/shell/worktrees.rs::checkout_path_preview`（对话框预览）。herdr 的插件清单没有覆盖内置动作的能力。

## 行为

- 触发 `sibling-worktree.create` 时，action 弹出 `prompt` popup（`placement = "popup"`）。
- popup 显示 `repo` 与实时的 `checkout` 预览，并提示输入分支名。
- 回车创建，Esc 取消；分支名留空时使用自动生成的 `worktree/<hex>`。
- 分支名按 `git check-ref-format --branch` 校验，非法时在 popup 内提示并重新输入。
- 创建过程调用 `herdr worktree create --cwd <repo 根> --branch <分支> --path <checkout> --no-focus`：
  - `--cwd` 使用主仓库根，从 linked worktree 触发也能正确归组到该 repo 的父 workspace。
  - 新 workspace 不抢焦点。
- 创建失败时 popup 保留 herdr 的原始错误输出，按回车关闭。

## 依赖与限制

| 项 | 说明 |
| --- | --- |
| 平台 | 仅 `linux` / `macos`（用到 `stty` 的 raw 模式读键） |
| 运行时 | `bash`（兼容 macOS 自带 3.2）、`git`、`stty`；无 jq/node/python 依赖 |
| 分支名 | 逐字节读取，非 ASCII 字符无法输入；目录 slug 只保留小写 ASCII 字母数字 |

## 目录结构

```
herdr-plugin.toml   清单：action create + pane prompt
actions/create.sh   action 入口，只负责打开 popup
panes/prompt.sh     popup 主体：取上下文、输入分支、调用 herdr worktree create
lib/path.sh         共享纯函数：json_field / slugify / sibling_checkout_path
README.md           文档：中文（默认）
README.en.md        文档：英文
```

## 卸载

```bash
herdr plugin unlink sibling-worktree                      # 本地 link 安装的
herdr plugin uninstall sibling-worktree                   # GitHub 安装的（也可用 AlphaGodzilla/herdr-plugin-sibling-worktree）
```

再删除 `~/.config/herdr/config.toml` 里的 `[[keys.command]]`（`sibling-worktree.create`），并按需恢复 `[keys] new_worktree = "prefix+shift+g"`，然后 `herdr server reload-config`。
