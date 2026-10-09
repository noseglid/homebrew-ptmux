#!/usr/bin/env bash
set -euo pipefail

kill_mode=0
if [[ "${1:-}" == "-k" ]]; then
  kill_mode=1
  shift
fi

config_file="${XDG_CONFIG_HOME:-$HOME/.config}/ptmux/ptmux.conf"
base_path=""

if [[ -f "$config_file" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    key="${line%%=*}"
    val="${line#*=}"
    key="$(echo "$key" | xargs)"
    val="$(echo "$val" | xargs)"
    case "$key" in
      base-path) base_path="${val/#\~/$HOME}" ;;
    esac
  done < "$config_file"
fi

if [[ -z "$base_path" ]]; then
  echo "Error: base-path not set. Configure it in $config_file" >&2
  exit 1
fi

# No arguments: attach to the first existing session, if any
if [[ $# -eq 0 && $kill_mode -eq 0 ]]; then
  first_session="$(tmux list-sessions -F '#{session_name}' 2>/dev/null | head -1 || true)"
  if [[ -n "$first_session" ]]; then
    exec tmux attach-session -t "=$first_session"
  fi
fi

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") [-k] [<path-relative-to-$base_path>]" >&2
  echo "  Without a path, attaches to the first existing session" >&2
  echo "Example: $(basename "$0") storytel/library-service" >&2
  echo "  -k  Kill the session instead of starting/attaching" >&2
  exit 1
fi

# Use last path segment as session name, replace . with _
session_name="$(basename "$1")"
session_name="${session_name//./_}"

if [[ $kill_mode -eq 1 ]]; then
  exec tmux kill-session -t "=$session_name"
fi

project_path="$base_path/$1"
if [[ ! -d "$project_path" ]]; then
  echo "Error: $project_path does not exist" >&2
  exit 1
fi

if tmux has-session -t "=$session_name" 2>/dev/null; then
  exec tmux attach-session -t "=$session_name"
fi

# One visible window: left slot (nvim) + terminal on the right.
# claude waits in a hidden "alt" window; toggle_key swaps it into the left slot,
# so the terminal pane is never touched.
toggle_key='a'

editor_pane="$(tmux new-session -d -s "$session_name" -c "$project_path" -n dev -P -F '#{pane_id}')"
tmux split-window -h -l 40% -t "$editor_pane" -c "$project_path"
tmux send-keys -t "$editor_pane" 'nvim' Enter

claude_pane="$(tmux new-window -d -t "$session_name" -c "$project_path" -n alt -P -F '#{pane_id}')"
tmux send-keys -t "$claude_pane" 'claude' Enter

# Positional targets, so the binding keeps working after each swap
pane_base="$(tmux show-options -gv pane-base-index 2>/dev/null || echo 0)"
tmux bind-key "$toggle_key" swap-pane -s ":alt.$pane_base" -t ":dev.$pane_base"

tmux select-pane -t "$editor_pane"
exec tmux attach-session -t "$session_name"
