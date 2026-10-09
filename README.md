# tmux-opencode-session-manager

https://github.com/user-attachments/assets/4ef70f60-e4f0-40ee-914a-4c4057ba234e

Run many [opencode](https://opencode.ai) sessions across your
projects, each in its own tmux session — then **list their bound conversations,
see which are active, and jump to one** from a single popup.

If you launch opencode per-directory (one nested session per project), you quickly
end up with a dozen of them and no way to tell which are finished without opening
each one. This plugin gives you:

- **A central picker** (`prefix` + `T`) listing every running opencode session.
- **Live status** per bound conversation — `busy` / `idle` / `unknown` — read from the
  opencode server API, so you instantly see which need you.
- **A live preview** of each session's screen right in the picker.
- **Smart jump** — selecting a session switches your client to the window it
  was launched from, then resumes it in a popup over it.
- **A launcher** (`prefix` + `t`) that opens/attaches an opencode session for
  the current directory.
- **Close TUI** (`ctrl-x`) or **reopen TUI** (`ctrl-r`) from the picker.

New launches bind a conversation automatically. The picker queries the shared
OpenCode V2 service. Missing bindings or unavailable status show `?`.

## Prerequisites

- **tmux ≥ 3.2** (for `display-popup`)
- **[fzf](https://github.com/junegunn/fzf)** — the picker UI
- **[OpenCode V2](https://opencode.ai/v2/docs/cli/)** CLI (the `opencode` command)
- **jq**, **Python ≥ 3.8** (`python3`, standard library only)
- bash; macOS or Linux

## Install (tpm)

Add to `~/.tmux.conf` (or `~/.config/tmux/tmux.conf`):

```tmux
set -g @plugin 'githubcuaan/tmux-opencode-session-manager'
```

Then hit `prefix` + <kbd>I</kbd> to install.

> **Keybinding note:** by default the plugin binds `prefix` + `t` (launch) and
> `prefix` + `T` (list). If your config binds those elsewhere, either change the
> options below, or make sure the plugin loads **after** your own bindings (put
> `run '~/.tmux/plugins/tpm/tpm'` _after_ them) so the one you want wins.

### Manual install

```sh
git clone https://github.com/githubcuaan/tmux-opencode-session-manager ~/clone/path
```

Add to `~/.tmux.conf`, then reload (`prefix` + <kbd>r</kbd> or `tmux source ~/.tmux.conf`):

```tmux
run-shell ~/clone/path/tmux-opencode-session-manager.tmux
```

## Usage

| Key            | Action                                                                             |
| -------------- | ---------------------------------------------------------------------------------- |
| `prefix` + `t` | Launch (or re-attach to) an opencode session for the current directory, in a popup |
| `prefix` + `T` | Open the session picker                                                            |

Inside the picker:

| Key                                         | Action                                                                    |
| ------------------------------------------- | ------------------------------------------------------------------------- |
| `enter`                                     | Jump to the session (switches to its origin window, resumes in the popup) |
| `ctrl-x`                                    | Close the highlighted TUI (agent execution can continue on the server)    |
| `ctrl-r`                                    | Reopen the TUI with its bound conversation                                |
| `ctrl-n`,`ctrl-p`,`↑` / `↓`, type to filter | fzf navigation                                                            |

Inactive conversations (`idle`) sort to the top. This does not imply successful
completion or that background work has stopped.

## Status setup

The launcher opens `opencode` in the project directory without API requests or
forcing a conversation ID. Select or create conversations inside OpenCode;
the companion binds the viewed conversation automatically. Existing tmux
sessions are reattached without starting another TUI.

Status describes the **bound conversation**. The companion TUI plugin below
automatically updates the binding when `context.ui.router.current()` changes:
switching tabs makes status follow the conversation being viewed. Returning to
the home screen clears the binding until a conversation is selected.

Reopen `prefix + T` to refresh status after switching conversations. This also
works when the TUI tab strip is disabled: binding follows the current route.

### Install the TUI companion

Add this repository's `opencode-plugin` directory to the existing `plugins`
array in `~/.config/opencode/cli.json` (or `$XDG_CONFIG_HOME/opencode/cli.json`):

```json
{
  "plugins": ["/absolute/path/to/tmux-opencode-session-manager/opencode-plugin"]
}
```

Preserve your other settings and plugin entries. OpenCode reloads CLI settings;
reopen the TUI if the companion has not loaded yet.

The companion runs locally inside each TUI, using `TMUX_PANE` to identify its
managed tmux session. It checks focus every 300 ms and updates
`@opencode_session_id` only when the viewed conversation changes. It does not
publish tab lists or query server history. Separate project popup sessions keep
independent bindings, even when they use the same project directory.

Without the companion, new sessions remain unbound and display `?`;
load the companion and select a conversation to bind automatically.
Unbound sessions cannot be restarted through the picker.

### How it works

1. All default TUI and API commands use the same shared background service.
2. The picker reads each tmux session's explicit OpenCode ID.
3. `opencode api get /api/session/active` supplies one active snapshot per refresh.
4. Metadata comes from `/api/session/<id>`, deduplicated by ID with at most four
   concurrent requests. `data.time.updated` supplies the displayed age.
5. A known session with `type: running` is `busy`; a known session absent from
   the active map is `idle`. Missing IDs, deleted sessions, request failures,
   invalid responses, and unsupported active states are `unknown` (`?`).

The active endpoint reports only foreground drains owned by the queried server.
It does not expose V1's `retry` state. Calls use CLI discovery/authentication;
the plugin does not read passwords or scrape process ports.

Set the API timeout (seconds) with:

```tmux
set -g @opencode_api_timeout '2'
```

This is a total deadline for a status refresh, including queued metadata calls;
unfinished lookups show `?`. Individual restart API requests use the same
timeout. Increase it for slow requests or many sessions. Timed-out CLI
process groups are terminated and the child process reaped on Linux and macOS.

The launcher delegates server startup and connection handling to the OpenCode
TUI. It does not perform an API readiness check.

## Options

Set any of these before the plugin loads (defaults shown):

```tmux
set -g @opencode_launch_key     't'        # prefix key: launch/open for current dir
set -g @opencode_list_key       'T'        # prefix key: open the picker
set -g @opencode_command        'opencode' # command run in new sessions
set -g @opencode_api_command    ''         # empty: @opencode_command followed by "api"
set -g @opencode_session_prefix 'opencode-' # tmux session name prefix
set -g @opencode_popup_width    '90%'      # popup width
set -g @opencode_popup_height   '85%'      # popup height
set -g @opencode_popup_border_lines ''        # -b: single|rounded|double|heavy|simple|padded|none
set -g @opencode_popup_border_style ''        # -S: style, vd 'fg=red,bg=black,bold'
set -g @opencode_api_timeout    '2'        # API request / status refresh deadline (s)
```

Custom wrappers must support the `--session <id>` TUI flag and API subcommand.
If their API syntax differs, set `@opencode_api_command` to the full API prefix.
Both commands must connect to the same server. For example:

```tmux
set -g @opencode_command 'opencode --server http://127.0.0.1:4096'
set -g @opencode_api_command 'opencode api --server http://127.0.0.1:4096'
```

Use the same authenticated server context as your normal OpenCode client.
`--standalone` is unsuitable here: each API invocation would have a different
private server. Default shared-service web access is available via `opencode pair`.

## How it works

- The **launcher** creates a detached `opencode-<hash-of-dir>` tmux session
  running `opencode`, records the origin window in `@opencode_origin`, and attaches
  to it in a popup. The companion updates `@opencode_session_id` after a
  conversation is selected.
- The **status** wrapper `scripts/opencode-status.sh` reads bindings, then uses
  `scripts/opencode-api.py` for bounded V2 CLI requests and metadata lookups.
- The **picker** lists sessions matching the prefix, reads their live API
  status and a `capture-pane` preview, and on selection moves your client to
  the session's origin window before resuming it in the popup.
- Pressing `prefix` + `T` **from inside a session popup** detaches that popup
  first (closing it), then reopens the picker full-size on the outer host
  client — so you never end up with a cramped popup-in-popup.

## Development checks

```sh
python3 -m unittest discover -s tests -v
for script in scripts/*.sh; do bash -n "$script" || break; done
```

## Acknowledgments

This project is a fork of [tmux-claude-session-manager](https://github.com/craftzdog/tmux-claude-session-manager)
by **[Takuya Matsuyama (craftzdog)](https://github.com/craftzdog)** — the original
idea and implementation for managing Claude Code sessions across projects.

Thank you for the brilliant design and clean code that made this adaptation possible.

## Related projects

- **[opvi.nvim](https://github.com/githubcuaan/opvi)** — a Neovim Ask UI for
  OpenCode V2, bound to the conversations managed by this plugin.

## License

[MIT](LICENSE) © Takuya Matsuyama
