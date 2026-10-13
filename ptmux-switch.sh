#!/usr/bin/env bash
# Session picker: switch to a running tmux session, or pick a project and start it with ptmux.
# Running sessions are listed first (green ▶), followed by projects without a session (dim +).
# The session of the client that opened the picker is highlighted (bold yellow ●).
set -uo pipefail

config_file="${XDG_CONFIG_HOME:-$HOME/.config}/ptmux/ptmux.conf"
base_path="$(sed -nE 's/^[[:space:]]*base-path[[:space:]]*=[[:space:]]*//p' "$config_file" | head -1 | xargs)"
base_path="${base_path/#\~/$HOME}"
[[ -d "$base_path" ]] || { echo "ptmux base-path not found: $base_path" >&2; read -r; exit 1; }

# Emits: state <tab> tag <tab> display <tab> session name <tab> project path (empty for non-ptmux sessions)
# Only tag and display are shown; state is "run" or "new" and drives the action.
list() {
  # Projects are git repos directly in base-path, or one level down (e.g. storytel/library-service)
  find "$base_path" -mindepth 2 -maxdepth 3 -name .git -not -path "$base_path/.*" | sed "s|^$base_path/||; s|/\.git$||" |
    SESSIONS="$(tmux list-sessions -F '#{session_name}' 2>/dev/null)" CURRENT="$current" awk '
      BEGIN { run = "\033[32m▶\033[0m"; new = "\033[2m+\033[0m"; cur = "\033[1;33m●\033[0m"
              n = split(ENVIRON["SESSIONS"], s, "\n"); for (i = 1; i <= n; i++) if (s[i] != "") running[s[i]] = 1 }
      # Same session naming as ptmux: last path segment, . replaced with _
      { name = $0; sub(/.*\//, "", name); gsub(/\./, "_", name)
        if (name in running) { used[name] = 1; row("run", $0, name, $0) }
        else printf "1\t%s\tnew\t" new "\t%s\t%s\t%s\n", $0, $0, name, $0 }
      END { for (name in running) if (!(name in used)) row("run", name, name, "") }
      function row(state, display, name, project) {
        # Plain display goes in column 2 as the sort key, so the highlight escape codes do not affect order
        if (name == ENVIRON["CURRENT"]) printf "0\t%s\trun\t" cur "\t\033[1;33m%s\033[0m\t%s\t%s\n", display, display, name, project
        else printf "0\t%s\t%s\t" run "\t%s\t%s\t%s\n", display, state, display, name, project }' |
    sort -t $'\t' -k1,1 -k2,2 | cut -f3-
}

# Exported so the ctrl-x reload (which re-runs this script with --list) keeps the same value
export PTMUX_CURRENT="${PTMUX_CURRENT:-$(tmux display-message -p '#{client_session}' 2>/dev/null)}"
current="$PTMUX_CURRENT"

if [[ "${1:-}" == "--list" ]]; then
  list
  exit 0
fi

selection="$(list | env FZF_DEFAULT_OPTS= SHELL=/bin/bash fzf --ansi --reverse --no-border --margin=1 \
  --color=dark,pointer:#fca311,marker:#fca311 \
  --delimiter=$'\t' --with-nth=2,3 --nth=2 --header='^x kill' \
  --bind "ctrl-x:execute-silent([ {1} = run ] && tmux kill-session -t ={4})+reload('$0' --list)")"
[[ -n "$selection" ]] || exit 0

IFS=$'\t' read -r state _ _ session project <<<"$selection"
if [[ "$state" == "new" ]]; then
  # ptmux creates the session and then tries to attach to it. Without a terminal that attach fails,
  # otherwise it would attach inside this popup.
  ptmux "$project" </dev/null >/dev/null 2>&1
fi
tmux switch-client -t "=$session"
