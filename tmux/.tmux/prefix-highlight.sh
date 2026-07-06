#!/usr/bin/env bash
# Runs AFTER tokyo-night-tmux's own run-shell (see tmux.conf ordering) and
# re-sets status-left with a neon-yellow highlight (#FFFF00 bg, black fg)
# while tmux's prefix key is armed. Re-sources themes.sh so the "off" state
# always matches whatever @tokyo-night-tmux_theme variant is currently active.

PLUGIN_SRC="$HOME/.tmux/plugins/tokyo-night-tmux/src"
source "$PLUGIN_SRC/themes.sh"

hostname="#($PLUGIN_SRC/hostname-widget.sh)"

tmux set -g status-left \
  "#[fg=#{?client_prefix,#000000,${THEME[bblack]}},bg=#{?client_prefix,#FFFF00,${THEME[blue]}},bold]#{?client_prefix,#[blink],} #{?client_prefix,󰠠 PREFIX ,#[dim]󰤂 }#[bold,nodim]#S$hostname "
