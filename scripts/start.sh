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

# Derive a port from the path hash
path_hash=$(printf '%s' "$path" | md5sum | cut -c1-8)
port=$((16#${path_hash:0:4} % 55536 + 10000))

# Create a background session if it does not exist yet
if ! tmux has-session -t "$session" 2>/dev/null; then
  tmux new-session -d -s "$session" -c "$path" "$cmd --port $port"
fi

# Record the origin window if provided
[ -n "$window" ] && tmux set-option -t "$session" @opencode_origin "$window"
