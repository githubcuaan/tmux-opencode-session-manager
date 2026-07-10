#!/usr/bin/env bash
# Get opencode session status from server API.
# Usage: opencode-status.sh [--list] [tmux-session-name]
#   --list                 output status for all opencode sessions
#   <tmux-session-name>    output status for that specific session
#
# Output format (tab-separated):  session_name \t status \t session_id \t updated_ms
# Status values: busy, idle, retry, unknown
#   - busy/retry: session is in the live /session/status map
#   - idle:      session exists in /session but not in the status map
#   - unknown:   server unreachable or session id not found
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "$DIR/helpers.sh"

prefix="$(get_tmux_option @opencode_session_prefix 'opencode-')"
timeout="$(get_tmux_option @opencode_api_timeout '2')"

# Get port from a tmux session's pane PID by reading its cmdline.
get_port_from_session() {
  local session="$1" pid port
  pid=$(tmux list-panes -t "$session" -F '#{pane_pid}' 2>/dev/null | head -1)
  [ -z "$pid" ] && return 1
  port=$(tr '\0' '\n' < "/proc/$pid/cmdline" 2>/dev/null | grep -A1 -- "--port" | tail -1)
  [ -z "$port" ] && return 1
  printf '%s' "$port"
}

# Find an opencode session id + last-updated time (ms) for a directory via the
# server API. Output: "session_id \t updated_ms" (updated_ms may be empty).
get_session_from_api() {
  local port="$1" dir="$2" sessions out
  sessions=$(curl -s --connect-timeout "$timeout" "http://127.0.0.1:${port}/session" 2>/dev/null)
  [ -z "$sessions" ] && return 1
  out=$(printf '%s' "$sessions" | jq -r --arg dir "$dir" \
    '.[] | select(.directory == $dir) | "\(.id)\t\(.time.updated)"' 2>/dev/null | head -1)
  [ -z "$out" ] && return 1
  printf '%s' "$out"
}

# Resolve a status type for a session id.
# The session id is known to exist in /session (the DB). The /session/status
# map only contains sessions that are currently busy/retry; idle sessions are
# absent from it. So: present in the map -> its type; absent -> idle. An empty
# response (server unreachable) -> unknown.
get_session_status() {
  local port="$1" session_id="$2" resp type
  resp=$(curl -s --connect-timeout "$timeout" "http://127.0.0.1:${port}/session/status" 2>/dev/null)
  [ -z "$resp" ] && { printf 'unknown'; return; }
  type=$(printf '%s' "$resp" | jq -r --arg id "$session_id" '.[$id].type // empty' 2>/dev/null)
  case "$type" in
    busy|retry) printf '%s' "$type" ;;
    idle)      printf 'idle' ;;
    *)         printf 'idle' ;;   # exists in /session but not in the status map
  esac
}

output_all_status() {
  tmux list-sessions -F '#{session_name}' 2>/dev/null | grep "^${prefix}" | while IFS= read -r s; do
    local port session_id updated path status

    port=$(get_port_from_session "$s")

    if [ -z "$port" ]; then printf '%s\t%s\t%s\t\n' "$s" "unknown" ""; continue; fi

    path=$(tmux display-message -p -t "$s" '#{pane_current_path}' 2>/dev/null)
    local api_out
    api_out=$(get_session_from_api "$port" "$path")

    if [ -z "$api_out" ]; then printf '%s\t%s\t%s\t\n' "$s" "unknown" ""; continue; fi

    session_id=$(printf '%s' "$api_out" | cut -f1)
    updated=$(printf '%s' "$api_out" | cut -f2)

    status=$(get_session_status "$port" "$session_id")
    printf '%s\t%s\t%s\t%s\n' "$s" "$status" "$session_id" "$updated"
  done
}

output_session_status() {
  local target_session="$1" port session_id updated status path
  port=$(get_port_from_session "$target_session")
  [ -z "$port" ] && { printf 'unknown'; return; }
  path=$(tmux display-message -p -t "$target_session" '#{pane_current_path}' 2>/dev/null)
  local api_out
  api_out=$(get_session_from_api "$port" "$path")
  [ -z "$api_out" ] && { printf 'unknown'; return; }
  session_id=$(printf '%s' "$api_out" | cut -f1)
  updated=$(printf '%s' "$api_out" | cut -f2)
  status=$(get_session_status "$port" "$session_id")
  printf '%s' "$status"
}

case "${1:-}" in
  --list) output_all_status ;;
  "")     output_all_status ;;
  *)      output_session_status "$1" ;;
esac
