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

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") [-k] <path-relative-to-$base_path>" >&2
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

tmux new-session -d -s "$session_name" -c "$project_path" -n editor
tmux send-keys -t "$session_name:editor" 'nvim' Enter

tmux new-window -t "$session_name" -c "$project_path" -n claude
tmux send-keys -t "$session_name:claude" 'claude' Enter

tmux new-window -t "$session_name" -c "$project_path" -n terminal

tmux select-window -t "$session_name:editor"
exec tmux attach-session -t "$session_name"
