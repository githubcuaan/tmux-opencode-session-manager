#!/usr/bin/env bash
# Status of bound OpenCode V2 conversations on the shared service.
# --list (default): tmux_name<TAB>status<TAB>session_id<TAB>updated_ms
# <tmux-session-name>: status only
# busy = running foreground drain; idle = known session absent from active map.
# Missing bindings, failed requests, and invalid responses are unknown.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "$DIR/helpers.sh"

prefix="$(get_tmux_option @opencode_session_prefix 'opencode-')"
timeout="$(get_tmux_option @opencode_api_timeout '2')"
cmd="$(get_opencode_api_command)"
target="${1:-}"

bindings() {
  local s session_id

  # arg check
  if [ -n "$target" ] && [ "$target" != '--list' ]; then
    printf '%s\n' "$target"
  else
    tmux list-sessions -F '#{session_name}' 2>/dev/null
  fi | while IFS= read -r s; do
    if [ -z "$target" ] || [ "$target" = '--list' ]; then
      [[ "$s" == "$prefix"* ]] || continue
    fi

    # take the session_id
    session_id=$(tmux show-option -qv -t "$s" @opencode_session_id 2>/dev/null) || session_id=''
    valid_session_id "$session_id" || session_id=''

    printf '%s\t%s\n' "$s" "$session_id"
  done
}

rows=$(bindings)
[ -n "$rows" ] || exit 0
if ! output=$(printf '%s\n' "$rows" | python3 "$DIR/opencode-api.py" "$timeout" "$cmd" status); then
  output=$(printf '%s\n' "$rows" | awk -F '\t' 'BEGIN { OFS="\t" } { print $1, "unknown", $2, "" }')
fi

if [ -n "$target" ] && [ "$target" != '--list' ]; then
  printf '%s\n' "$output" | cut -f2
else
  printf '%s\n' "$output"
fi
