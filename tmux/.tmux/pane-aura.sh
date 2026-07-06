#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
#  pane-aura.sh — animated "aura" on the ACTIVE tmux pane border.
#
#  tmux has no native animation, so this loop repaints the active
#  pane border color every frame, breathing dim → bright → dim to
#  fake a pulsing glow. Launched (backgrounded) from ~/.tmux.conf.
#
#  Self-guards to a single instance via a pidfile, and exits on its
#  own when the tmux server goes away.
#
#  Stop it:   pkill -f pane-aura.sh
#  Tune it:   edit COLORS (palette) or FRAME (seconds per step) below.
# ─────────────────────────────────────────────────────────────────

PIDFILE="$HOME/.tmux/pane-aura.pid"

# Single-instance guard: if a live instance owns the pidfile, bail out.
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
  exit 0
fi
echo $$ >"$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

# Cyan breathe: dark teal → bright cyan → near-white, then back down.
# (256-color codes.) Swap these for a different aura hue.
COLORS=(23 30 37 44 51 87 123 159 195 159 123 87 51 44 37 30)
FRAME=0.15   # seconds per step (~2.4s per full breath); raise for calmer/less CPU

i=0
while true; do
  # Repaint the active border. If tmux is gone, this fails and we exit.
  tmux set-option -g pane-active-border-style "fg=colour${COLORS[$i]}" 2>/dev/null || exit 0
  i=$(( (i + 1) % ${#COLORS[@]} ))
  sleep "$FRAME"
done
