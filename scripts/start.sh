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
  # Let the TUI select/create conversations; the companion binds the viewed ID.
  # Shell configuration in $cmd is user-controlled.
  tmux new-session -d -s "$session" -c "$path" "$cmd" || exit 1
fi

# Record the origin window if provided
if [ -n "$window" ]; then
  tmux set-option -t "$session" @opencode_origin "$window"
fi
