#!/usr/bin/env bash
# Start an opencode session running in the background.
# Usage: start.sh <dir> [origin-window-id]
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "$DIR/helpers.sh"

path="${1:-$PWD}"
window="${2:-}"

prefix="$(get_tmux_option @opencode_session_prefix 'opencode-')"
cmd="$(get_tmux_option @opencode_command 'opencode')"

session="${prefix}$(session_hash "$path")"

# Create a background session if it does not exist yet
if ! tmux has-session -t "$session" 2>/dev/null; then
  directory=$(cd "$path" && pwd -P) || exit 1
  payload=$(jq -n --arg directory "$directory" '{location: {directory: $directory}}') || exit 1

  # CLI discovery starts the shared service if needed. Allow cold startup to
  # finish before sending the session-creation request with its shorter timeout.
  startup_timeout="$(get_tmux_option @opencode_startup_timeout '30')"
  if ! opencode_api_with_timeout "$startup_timeout" get /api/info >/dev/null; then
    message="OpenCode server startup/connection failed (timeout: ${startup_timeout}s). Check server settings or increase @opencode_startup_timeout."
    printf '%s\n' "$message" >&2
    tmux display-message "$message"
    exit 1
  fi

  response=$(opencode_api post /api/session --data "$payload") || exit 1
  session_id=$(printf '%s' "$response" | jq -er '.data.id') || exit 1
  valid_session_id "$session_id" || exit 1

  # IDs are validated above; shell configuration in $cmd is user-controlled.
  tmux new-session -d -s "$session" -c "$path" "$cmd --session $session_id" || exit 1
  tmux set-option -t "$session" @opencode_session_id "$session_id" || exit 1
fi

# Record the origin window if provided
if [ -n "$window" ]; then
  tmux set-option -t "$session" @opencode_origin "$window"
fi
