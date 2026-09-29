#!/usr/bin/env bash
# Shared helpers for tmux-opencode-session-manager.

# get_tmux_option <option-name> <default>
# Echoes the global tmux option value, or the default when unset/empty.
get_tmux_option() {
  local value
  value="$(tmux show-option -gqv "$1" 2>/dev/null)"
  if [ -n "$value" ]; then
    printf '%s' "$value"
  else
    printf '%s' "$2"
  fi
}

# session_hash <string>
# Short, stable, portable 8-char hash for deriving a session name from a path.
# Prefers md5sum (Linux), falls back to md5 (macOS) then shasum. The trailing
# newline matches the conventional `echo "$path" | md5sum` scheme, so it stays
# compatible with sessions created that way.
session_hash() {
  local out
  if command -v md5sum >/dev/null 2>&1; then
    out="$(printf '%s\n' "$1" | md5sum)"
  elif command -v md5 >/dev/null 2>&1; then
    out="$(printf '%s\n' "$1" | md5 -q)"
  else
    out="$(printf '%s\n' "$1" | shasum)"
  fi
  printf '%s' "${out%% *}" | cut -c1-8
}

# Full API command prefix; override for wrappers with different TUI/API syntax.
get_opencode_api_command() {
  local cmd
  cmd="$(get_tmux_option @opencode_command 'opencode')"
  get_tmux_option @opencode_api_command "$cmd api"
}

opencode_api() {
  opencode_api_with_timeout "$(get_tmux_option @opencode_api_timeout '2')" "$@"
}

# Startup may need more time than routine API calls or picker refreshes.
opencode_api_with_timeout() {
  local script_dir timeout cmd
  timeout="$1"
  shift
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cmd="$(get_opencode_api_command)"
  python3 "$script_dir/opencode-api.py" "$timeout" "$cmd" request "$@"
}

valid_session_id() {
  [[ "$1" =~ ^ses[a-zA-Z0-9_-]+$ ]]
}
