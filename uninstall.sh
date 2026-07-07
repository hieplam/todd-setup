#!/usr/bin/env bash
#
# todd-setup uninstaller
# Removes the symlinks created by install.sh (Stow's native --delete) and
# restores the most recent backup, returning the machine to its pre-install
# state. Non-destructive: never removes a target it did not create.
#
# Usage:  ./uninstall.sh
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES=(tmux nvim claude karabiner)

# Must match install.sh.
TARGETS=(
  ".tmux.conf"
  ".tmux/prefix-highlight.sh"
  ".tmux/pane-aura.sh"
  ".config/nvim"
  ".claude/statusline-command.sh"
  ".claude/statusline-class.sh"
  ".config/karabiner/karabiner.json"
)

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! \033[0m%s\n' "$*"; }
die()  { printf '\033[1;31mxx \033[0m%s\n' "$*" >&2; exit 1; }

command -v stow >/dev/null 2>&1 || die "stow not installed; nothing to remove."

# --- 1. Remove the symlinks Stow owns ---------------------------------------
info "Removing symlinks: ${PACKAGES[*]}"
stow --dir="$REPO_DIR" --target="$HOME" --delete "${PACKAGES[@]}"

# --- 2. Restore the most recent backup, if one exists -----------------------
latest="$(ls -1d "$HOME"/.todd-setup-backup/*/ 2>/dev/null | sort | tail -n1 || true)"
if [[ -z "${latest:-}" ]]; then
  info "No backup found; symlinks removed. (Repo copy is untouched.)"
  exit 0
fi

info "Restoring originals from $latest"
for rel in "${TARGETS[@]}"; do
  [[ -e "$latest/$rel" ]] || continue
  if [[ -e "$HOME/$rel" || -L "$HOME/$rel" ]]; then
    warn "$HOME/$rel still exists — leaving it in place, skipping restore."
    continue
  fi
  mkdir -p "$HOME/$(dirname "$rel")"
  cp -R "$latest/$rel" "$HOME/$rel"
done

info "Restore complete. Backup left intact at $latest"
info "Note: cloned tmux plugins in ~/.tmux/plugins were left in place (harmless; rm manually if desired)."
