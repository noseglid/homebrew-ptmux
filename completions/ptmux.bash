_ptmux() {
    local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/ptmux/ptmux.conf"
    local base_path=""

    if [[ -f "$config_file" ]]; then
        base_path=$(grep -E '^\s*base-path\s*=' "$config_file" | head -1 | sed 's/^[^=]*=\s*//' | xargs)
        base_path="${base_path/#\~/$HOME}"
    fi

    [[ -z "$base_path" || ! -d "$base_path" ]] && return

    local cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=($(compgen -W "$(find "$base_path" -mindepth 1 -maxdepth 2 -type d | sed "s|$base_path/||")" -- "$cur"))
}

complete -F _ptmux ptmux
