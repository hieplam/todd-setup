#!/usr/bin/env bash
#
# todd-setup installer
# Symlinks the tracked dotfiles (tmux, nvim, Claude statusline) into $HOME
# using GNU Stow. Idempotent: safe to run repeatedly.
#
# Usage:  ./install.sh
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES=(tmux nvim claude)

# Leaf paths (relative to $HOME) that Stow will occupy. Kept in sync with
# uninstall.sh so backup/restore cover exactly what we manage.
TARGETS=(
  ".tmux.conf"
  ".config/nvim"
  ".claude/statusline-command.sh"
  ".claude/statusline-class.sh"
)

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.todd-setup-backup/$TIMESTAMP"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! \033[0m%s\n' "$*"; }
die()  { printf '\033[1;31mxx \033[0m%s\n' "$*" >&2; exit 1; }

# --- 1. Ensure GNU Stow is available (install via Homebrew if needed) --------
[[ "$(uname -s)" == "Darwin" ]] || warn "This installer targets macOS; continuing anyway."

if ! command -v stow >/dev/null 2>&1; then
  info "GNU Stow not found — installing via Homebrew…"
  command -v brew >/dev/null 2>&1 || die "Homebrew required to install stow. See https://brew.sh"
  brew install stow
fi

# --- 2. Back up any real (non-symlink) files Stow would collide with ---------
backed_up=0
for rel in "${TARGETS[@]}"; do
  tgt="$HOME/$rel"
  if [[ -e "$tgt" && ! -L "$tgt" ]]; then
    info "Backing up existing $tgt"
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    mv "$tgt" "$BACKUP_DIR/$rel"
    backed_up=1
  fi
done
[[ $backed_up -eq 1 ]] && info "Originals saved to $BACKUP_DIR"

# --- 3. Symlink the packages into $HOME -------------------------------------
info "Stowing: ${PACKAGES[*]}"
stow --dir="$REPO_DIR" --target="$HOME" --restow "${PACKAGES[@]}"

info "Done. Your configs now symlink into $REPO_DIR."
info "Edit here, 'git push', then 'git pull && ./install.sh' on the next machine."
