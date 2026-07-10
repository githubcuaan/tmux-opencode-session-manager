# tmux-opencode-session-manager

https://github.com/user-attachments/assets/37670340-06f7-4b57-ab49-84118897be47

Run many [opencode](https://opencode.ai) sessions across your
projects, each in its own tmux session — then **list them, see which are done
vs. still working, and jump to one** from a single popup.

If you launch opencode per-directory (one nested session per project), you quickly
end up with a dozen of them and no way to tell which are finished without opening
each one. This plugin gives you:

- **A central picker** (`prefix` + `T`) listing every running opencode session.
- **Live status** per session — `busy` / `idle` / `retry` — read from the
  opencode server API, so you instantly see which need you.
- **A live preview** of each session's screen right in the picker.
- **Smart jump** — selecting a session switches your client to the window it
  was launched from, then resumes it in a popup over it.
- **A launcher** (`prefix` + `t`) that opens/attaches an opencode session for
  the current directory.
- **Quick kill** (`ctrl-x`) of finished sessions from the picker.

Status is automatic: the picker queries each running opencode server for its
state. If a server is not reachable, that session shows `?` instead of a color.

## Prerequisites

- **tmux ≥ 3.2** (for `display-popup`)
- **[fzf](https://github.com/junegunn/fzf)** — the picker UI
- **[opencode](https://opencode.ai)** CLI (the `opencode` command)
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

| Key                       | Action                                                                    |
| ------------------------- | ------------------------------------------------------------------------- |
| `enter`                   | Jump to the session (switches to its origin window, resumes in the popup) |
| `ctrl-x`                  | Kill the highlighted session                                              |
| `↑` / `↓`, type to filter | fzf navigation                                                            |

Sessions needing your attention (`idle`) sort to the top.

## Status setup

Session status (`busy` / `idle` / `retry`) is detected **automatically** via the
opencode server API — no configuration required.

When you open the picker, it finds each session's server port (from the tmux
pane's process), calls `GET /session/status`, and shows the real-time state.
If a server is not reachable, the session shows `?`.

### How it works

1. Each opencode session runs on a unique port (set by `launch.sh`).
2. The picker finds the port from the tmux pane's process cmdline.
3. It calls `GET /session/status` to get the `busy` / `idle` / `retry` state.
4. Results are color-coded in the picker.

Set the API timeout (seconds) with:

```tmux
set -g @opencode_api_timeout '2'
```

## Options

Set any of these before the plugin loads (defaults shown):

```tmux
set -g @opencode_launch_key     't'        # prefix key: launch/open for current dir
set -g @opencode_list_key       'T'        # prefix key: open the picker
set -g @opencode_command        'opencode' # command run in new sessions
set -g @opencode_session_prefix 'opencode-' # tmux session name prefix
set -g @opencode_popup_width    '90%'      # popup width
set -g @opencode_popup_height   '85%'      # popup height
set -g @opencode_api_timeout     '2'        # opencode server API timeout (s)
```

## How it works

- The **launcher** creates a detached `opencode-<hash-of-dir>` tmux session
  running `opencode --port <port>`, records the window it came from in
  `@opencode_origin`, and attaches to it in a popup.
- The **status** is read from the opencode server API (`GET /session/status`)
  by `scripts/opencode-status.sh`, which maps each tmux session to its server
  port via the pane's process.
- The **picker** lists sessions matching the prefix, reads their live API
  status and a `capture-pane` preview, and on selection moves your client to
  the session's origin window before resuming it in the popup.
- Pressing `prefix` + `T` **from inside a session popup** detaches that popup
  first (closing it), then reopens the picker full-size on the outer host
  client — so you never end up with a cramped popup-in-popup.

## Acknowledgments

This project is a fork of [tmux-claude-session-manager](https://github.com/craftzdog/tmux-claude-session-manager)
by **[Takuya Matsuyama (craftzdog)](https://github.com/craftzdog)** — the original
idea and implementation for managing Claude Code sessions across projects.

Thank you for the brilliant design and clean code that made this adaptation possible.

## License

[MIT](LICENSE) © Takuya Matsuyama
