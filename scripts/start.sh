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
