#!/usr/bin/env bash
# Reopen the TUI for the bound conversation; does not interrupt server execution.
# Usage: restart.sh <session-name>
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "$DIR/helpers.sh"

session="$1"

path=$(tmux display-message -p -t "$session" '#{pane_current_path}' 2>/dev/null) || exit 1
session_id=$(tmux show-options -qv -t "$session" @opencode_session_id 2>/dev/null)

# Preserve unbound legacy TUIs instead of accidentally replacing their conversation.
if ! valid_session_id "$session_id"; then
  tmux display-message 'Select a conversation in OpenCode with the auto-bind plugin enabled before restarting'
  exit 1
fi

# Verify before closing anything. Respawning preserves the tmux name, binding,
# origin, and attached clients even when a conversation has moved directories.
response=$(opencode_api get "/api/session/$session_id") || exit 1
printf '%s' "$response" | jq -e --arg id "$session_id" '.data.id == $id' >/dev/null || exit 1
cmd="$(get_tmux_option @opencode_command 'opencode')"
tmux respawn-pane -k -t "$session" -c "$path" "$cmd --session $session_id"
