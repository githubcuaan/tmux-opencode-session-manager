#!/usr/bin/env bash
# Restart an opencode session: kill and relaunch with same config.
# Usage: restart.sh <session-name>
set -uo pipefail

session="$1"

path=$(tmux display-message -p -t "$session" '#{pane_current_path}' 2>/dev/null)
origin=$(tmux show-options -qv -t "$session" @opencode_origin 2>/dev/null)

tmux kill-session -t "$session" 2>/dev/null

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$DIR/start.sh" "$path" "$origin"
