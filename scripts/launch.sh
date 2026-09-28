#!/usr/bin/env bash
# Ensure an opencode session exists and open/attach to it in a popup.
# Usage: launch.sh <dir> [origin-window-id]
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "$DIR/helpers.sh"

path="${1:-$PWD}"
window="${2:-}"

prefix="$(get_tmux_option @opencode_session_prefix 'opencode-')"
w="$(get_tmux_option @opencode_popup_width '90%')"
h="$(get_tmux_option @opencode_popup_height '90%')"

session="${prefix}$(session_hash "$path")"

# Prevent opening a popup inside an existing popup
if [[ "$(tmux display-message -p '#S')" == "$prefix"* ]]; then
  tmux display-message '🫪 Popup window already open'
  exit 0
fi

# 1. Delegate session creation/check to start.sh
"$DIR/start.sh" "$path" "$window" || exit 1

# 2. Open popup and attach to the session
tmux display-popup -w "$w" -h "$h" -E "tmux attach-session -t $session"
