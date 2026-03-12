function __tmuxp_base_path
    set -l config_file (set -q XDG_CONFIG_HOME; and echo $XDG_CONFIG_HOME; or echo $HOME/.config)/tmuxp/tmuxp.conf
    if test -f $config_file
        string match -rq '^\s*base-path\s*=\s*(?<val>.+)' < $config_file
        if set -q val
            echo (string replace '~' $HOME (string trim $val))
            return
        end
    end
end

complete -c tmuxp -f -a '(set -l bp (__tmuxp_base_path); test -n "$bp"; and find $bp -mindepth 1 -maxdepth 2 -type d | string replace "$bp/" "")'
