#!/usr/bin/env bash
#
# todd-setup installer
# Bootstraps a machine: installs plugin managers/plugins, then symlinks the
# tracked dotfiles (tmux, nvim, Claude statusline) into $HOME using GNU Stow.
# Idempotent: safe to run repeatedly (e.g. after a git pull).
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
  ".tmux/prefix-highlight.sh"
  ".tmux/pane-aura.sh"
  ".config/nvim"
  ".claude/statusline-command.sh"
  ".claude/statusline-class.sh"
)

# Third-party tmux plugins to clone into ~/.tmux/plugins (name|repo). These are
# external git repos, so they're cloned here rather than committed to this repo.
TMUX_PLUGINS=(
  "tpm|https://github.com/tmux-plugins/tpm"
  "tokyo-night-tmux|https://github.com/janoamaral/tokyo-night-tmux"
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

# --- 2. Clone tmux plugins BEFORE stowing ------------------------------------
# Cloning first makes ~/.tmux a real directory, so Stow folds into it and only
# symlinks our leaf scripts instead of hijacking the whole ~/.tmux dir.
info "Installing tmux plugins into ~/.tmux/plugins…"
mkdir -p "$HOME/.tmux/plugins"
for entry in "${TMUX_PLUGINS[@]}"; do
  name="${entry%%|*}"; url="${entry#*|}"
  dest="$HOME/.tmux/plugins/$name"
  if [[ -d "$dest/.git" ]]; then
    info "  $name already present"
  else
    info "  cloning $name"
    git clone --depth 1 "$url" "$dest"
  fi
done

# --- 3. Back up any real (non-symlink) files Stow would collide with ---------
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

# --- 4. Symlink the packages into $HOME -------------------------------------
info "Stowing: ${PACKAGES[*]}"
stow --dir="$REPO_DIR" --target="$HOME" --restow "${PACKAGES[@]}"

# --- 5. Sync Neovim plugins (LazyVim self-bootstraps lazy.nvim on first run) --
if command -v nvim >/dev/null 2>&1; then
  info "Syncing Neovim plugins (headless)…"
  nvim --headless "+Lazy! sync" +qa 2>/dev/null || \
    warn "Neovim plugin sync hit an issue; just open nvim to let LazyVim finish."
else
  warn "nvim not installed — skipping plugin sync (install Neovim, then re-run)."
fi

# --- 6. Reload tmux config if a server is already running --------------------
if command -v tmux >/dev/null 2>&1 && tmux info >/dev/null 2>&1; then
  tmux source-file "$HOME/.tmux.conf" >/dev/null 2>&1 && info "Reloaded running tmux config."
fi

info "Done. Configs symlink into $REPO_DIR; plugins installed."
info "Edit here, 'git push', then 'git pull && ./install.sh' on the next machine."
