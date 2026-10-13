# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`ptmux` is a single bash script (`ptmux.sh`) that creates or attaches to a tmux session for a project directory. It ships as a Homebrew tap: this repo is both the source and the tap (`Formula/ptmux.rb`). There is no build step and no test suite.

`ptmux-switch.sh` is a companion fzf session picker, opened from a tmux popup (`prefix s` in the user's `~/.tmux.conf`). The formula does not install it. This repo is its source of truth: edit it here, never the installed copy.

## Running / checking

- Run locally: `./ptmux.sh <path-relative-to-base-path>`, `./ptmux.sh -k <path>` to kill, or `./ptmux.sh` with no args to attach to the first existing session.
- Requires `~/.config/ptmux/ptmux.conf` (honours `$XDG_CONFIG_HOME`) containing `base-path = ~/some/dir`. Without it the script exits with an error.
- Formula test (what `brew test` runs): `ptmux` with no args and no sessions must print `Usage:` and exit 1. Keep that contract when changing argument handling.
- `ptmux-switch.sh` runs from `${XDG_CONFIG_HOME:-$HOME/.config}/tmux/ptmux-switch.sh`, so copy it there before testing: `cp ptmux-switch.sh ~/.config/tmux/ptmux-switch.sh` (adjust if `XDG_CONFIG_HOME` is set). Without a popup, `ptmux-switch.sh --list` prints the raw rows. Set `PTMUX_CURRENT=<session>` to test the current-session highlight.
- Install from the local tap to try the formula: `brew install --build-from-source ./Formula/ptmux.rb`.

## Architecture

- **Session naming**: session name is the basename of the given path with `.` replaced by `_`. Lookups use `=name` for exact tmux matching. `-k` derives the name the same way, so it works even if the directory is gone.
- **Layout**: window `dev` has the editor pane (nvim, left) and a terminal split (right, 40%). A hidden window `alt` runs `claude`. The `prefix a` binding uses `swap-pane` between `:alt.<base>` and `:dev.<base>`, so nvim and claude trade places in the left slot while the terminal pane is never touched. Targets are positional (respecting the global `pane-base-index`) rather than pane IDs so the binding keeps working after every swap. Note the binding is set globally on the tmux server, not per session.
- **Switcher**: `ptmux-switch.sh` lists running sessions (sorted first) and then projects that have no session. The session the popup was opened from is highlighted. Picking a project without a session runs `ptmux <project>` with no terminal attached (so its final attach fails harmlessly) and then calls `tmux switch-client`. Rows are tab-separated: hidden sort keys come first and are removed with `cut`, and fzf shows only some fields (`--with-nth`). Keep ANSI colour codes out of sort keys. `^x` kills a session and reloads by re-running the script with `--list`.

## Duplicated logic must stay in sync

`completions/_ptmux` (zsh), `completions/ptmux.bash`, `completions/ptmux.fish`, and `ptmux-switch.sh` each re-implement config parsing (`base-path`, `~` expansion) and project discovery independently. Projects are directories containing `.git` at depth 1–2 below `base-path` (`find -mindepth 2 -maxdepth 3 -name .git`, skipping dot-directories). `ptmux-switch.sh` also repeats the session-naming rule. Any change to the config format, flags, discovery, or naming must be applied in every one of these files.

## Releasing

Releases are git tags (`vX.Y.Z`). After tagging, bump the `url` in `Formula/ptmux.rb` to the new tag tarball in a separate commit ("Formula: bump to vX.Y.Z"). The formula currently has no `sha256`.
