# Sibling Worktree

**English** | [中文](README.md)

A Herdr plugin that puts worktree checkouts beside the repo instead of under `worktrees.directory`.
Press the key binding, type a branch name, and it creates `<repo parent>/<repo name>-<branch slug>`, for example:

```
workspace:  ~/proj/myrepo
branch:     feature/x
checkout:   ~/proj/myrepo-feature-x
```

## Install

Either way works; both register the same plugin id, `sibling-worktree`, globally for the current user.

### Install from GitHub

```bash
herdr plugin install AlphaGodzilla/herdr-plugin-sibling-worktree
herdr plugin install AlphaGodzilla/herdr-plugin-sibling-worktree -y          # already trust the source; skip the preview
herdr plugin install AlphaGodzilla/herdr-plugin-sibling-worktree --ref v0.1.0   # pin a tag or commit
herdr plugin update sibling-worktree          # follow upstream later
herdr plugin action list --plugin sibling-worktree
```

`install` clones the repository with `git` into a Herdr-managed installation directory. In an interactive terminal it previews the manifest and the commands it will run, and registers the plugin only after you confirm.

### Local install (personal use or development)

```bash
herdr plugin link ~/.pi/herdr-plugins/sibling-worktree   # your local plugin working directory
herdr plugin action list --plugin sibling-worktree
```

`link` uses the working directory as is and does not run the manifest's build commands (this plugin has none), so edits need no re-registration.

A plugin id cannot be both linked and GitHub-installed: `install` is refused while a local link exists, so run `herdr plugin unlink sibling-worktree` first.

### Key binding (same for both installs)

Unbind the built-in New worktree and trigger the plugin from the same key (`~/.config/herdr/config.toml`):

```toml
[keys]
new_worktree = ""          # unbind the built-in; it writes to <worktrees.directory>/<repo>/<slug>

[[keys.command]]
key = "prefix+shift+g"
type = "plugin_action"
command = "sibling-worktree.create"
description = "create sibling worktree"
```

After saving, run `reload config` inside Herdr (default `prefix+shift+r`), or `herdr server reload-config`.

## Coverage

| Creation entry point | Covered by this plugin? |
| --- | --- |
| Key binding (whatever `keys.new_worktree` is set to) | Covered, once the built-in is unbound as shown above |
| Right-click a workspace row → `New worktree` | Not covered; the client menu item is hard-coded to the built-in action |
| `herdr worktree create` (without `--path`) | Not covered; the server derives the path from `worktrees.directory` |
| Other plugins calling `worktree.create` (without `path`) | Not covered, same as above |

`Open worktree...` and `Delete worktree checkout...` need no override: this plugin creates ordinary herdr-managed Git worktrees, so the built-in open and delete actions work on them too.

Making the built-in entry points use sibling paths requires changing herdr itself: server side `src/worktree.rs::default_checkout_path` (decides the path when `--path` is omitted) and client side `src/client/shell/worktrees.rs::checkout_path_preview` (the dialog preview). The herdr plugin manifest has no way to override built-in actions.

## Behavior

- Triggering `sibling-worktree.create` opens the `prompt` popup (`placement = "popup"`).
- The popup shows `repo` and a live `checkout` preview, then asks for a branch name.
- Enter creates, Esc cancels; an empty branch name falls back to an auto-generated `worktree/<hex>`.
- The branch name is validated with `git check-ref-format --branch`; invalid input is reported in the popup and the prompt comes back.
- Creation runs `herdr worktree create --cwd <repo root> --branch <branch> --path <checkout> --no-focus`:
  - `--cwd` points at the main repo root, so triggering from a linked worktree still groups the new workspace under that repo's parent.
  - The new workspace does not steal focus.
- If creation fails, the popup keeps herdr's raw error output and closes on Enter.

## Requirements and limits

| Item | Notes |
| --- | --- |
| Platforms | `linux` / `macos` only (raw-mode key reading via `stty`) |
| Runtime | `bash` (3.2 compatible, the macOS built-in), `git`, `stty`; no jq/node/python |
| Branch names | Read byte by byte, so non-ASCII characters cannot be typed; the directory slug keeps lowercase ASCII alphanumerics only |

## Layout

```
herdr-plugin.toml   manifest: action create + pane prompt
actions/create.sh   action entry point; only opens the popup
panes/prompt.sh     popup body: read the context, prompt for the branch, call herdr worktree create
lib/path.sh         shared pure functions: json_field / slugify / sibling_checkout_path
README.md           docs, Chinese (default)
README.en.md        docs, English
```

## Uninstall

```bash
herdr plugin unlink sibling-worktree                      # installed with plugin link
herdr plugin uninstall sibling-worktree                   # installed from GitHub (or: AlphaGodzilla/herdr-plugin-sibling-worktree)
```

Then remove the `[[keys.command]]` (`sibling-worktree.create`) from `~/.config/herdr/config.toml`, restore `[keys] new_worktree = "prefix+shift+g"` if you want the built-in back, and run `herdr server reload-config`.
