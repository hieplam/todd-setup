#!/usr/bin/env bash
#
# todd-setup installer
# Bootstraps a machine: symlinks the tracked dotfiles (tmux, Neovim, Claude
# Code statusline, Karabiner) into $HOME using GNU Stow, clones tmux's
# third-party plugins, then front-loads Neovim plugins. Idempotent: safe to
# run repeatedly (e.g. after a git pull).
#
# Usage:  ./install.sh
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PACKAGES=(tmux nvim claude karabiner)

# Every leaf path (relative to $HOME) that Stow will occupy. Kept in sync with
# uninstall.sh so backup/restore cover exactly what we manage.
#
# Two rules for this list:
#   - List every leaf a package provides. Step 4 moves a pre-existing real file
#     out of the way; a leaf that is missing here makes stow abort on a conflict.
#   - List nothing a package does not provide. Step 4 would move that file into
#     the backup dir and then link nothing back in its place.
TARGETS=(
  ".tmux.conf"
  ".tmux/prefix-highlight.sh"
  ".tmux/pane-aura.sh"
  ".config/nvim"
  ".markdownlint-cli2.yaml"
  ".claude/statusline-command.sh"
  ".claude/statusline-class.sh"
  ".config/karabiner/karabiner.json"
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

# Physical path of $1 with every symlinked parent directory resolved away.
# Empty if the parent directory does not exist.
physical_path() {
  ( cd -P "$(dirname "$1")" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$(basename "$1")" ) || true
}

# --- 1. Ensure GNU Stow is available (install via Homebrew if needed) --------
[[ "$(uname -s)" == "Darwin" ]] || warn "This installer targets macOS; continuing anyway."

if ! command -v stow >/dev/null 2>&1; then
  info "GNU Stow not found — installing via Homebrew…"
  command -v brew >/dev/null 2>&1 || die "Homebrew required to install stow. See https://brew.sh"
  brew install stow
fi

# --- 2. Every listed package must exist ---------------------------------------
# Without this, dropping a package dir leaves PACKAGES stale and stow aborts the
# whole run on a cryptic error, stowing nothing at all.
for pkg in "${PACKAGES[@]}"; do
  [[ -d "$REPO_DIR/$pkg" ]] || die "PACKAGES lists '$pkg' but $REPO_DIR/$pkg does not exist."
done

# --- 3. Clone tmux plugins BEFORE stowing -------------------------------------
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

# --- 4. Back up any real (non-symlink) files Stow would collide with ---------
backed_up=0
for rel in "${TARGETS[@]}"; do
  tgt="$HOME/$rel"
  [[ -e "$tgt" && ! -L "$tgt" ]] || continue

  # A target that physically resolves inside this repo is our own tracked file,
  # reached through a symlinked parent directory (see step 4 on tree folding).
  # It only looks like a stray $HOME file; moving it would delete it from the repo.
  resolved="$(physical_path "$tgt")"
  if [[ -n "$resolved" && "$resolved" == "$REPO_DIR"/* ]]; then
    warn "$tgt resolves into the repo ($resolved) — not backing up; step 5 relinks it."
    continue
  fi

  info "Backing up existing $tgt"
  mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
  mv "$tgt" "$BACKUP_DIR/$rel"
  backed_up=1
done
[[ $backed_up -eq 1 ]] && info "Originals saved to $BACKUP_DIR"

# --- 5. Symlink the packages into $HOME -------------------------------------
# Unstow, recreate each leaf's parent directory, then stow — in that order.
#
# Stow "tree folds": when a directory it would populate does not exist in $HOME,
# it symlinks the package's whole directory instead of creating a real directory
# with leaf symlinks inside. On a machine that has never run Karabiner, that turns
# ~/.config/karabiner into a link to the repo, which makes every repo file under it
# look like a $HOME file — and the next run's step 4 then moves karabiner.json OUT
# of the repo. Creating the parents first forces the leaf-only symlinks we want.
info "Stowing: ${PACKAGES[*]}"
stow --dir="$REPO_DIR" --target="$HOME" --delete "${PACKAGES[@]}" 2>/dev/null || true
for rel in "${TARGETS[@]}"; do
  mkdir -p "$HOME/$(dirname "$rel")"
done
stow --dir="$REPO_DIR" --target="$HOME" --stow "${PACKAGES[@]}"

# --- 6. Sync Neovim plugins (LazyVim self-bootstraps lazy.nvim on first run) --
if command -v nvim >/dev/null 2>&1; then
  info "Syncing Neovim plugins (headless)…"
  nvim --headless "+Lazy! sync" +qa 2>/dev/null || \
    warn "Neovim plugin sync hit an issue; just open nvim to let LazyVim finish."
else
  warn "nvim not installed — skipping plugin sync (install Neovim, then re-run)."
fi

# --- 7. Reload tmux config if a server is already running --------------------
if command -v tmux >/dev/null 2>&1 && tmux info >/dev/null 2>&1; then
  tmux source-file "$HOME/.tmux.conf" >/dev/null 2>&1 && info "Reloaded running tmux config."
fi

info "Done. Configs symlink into $REPO_DIR; plugins installed."
info "Edit here, 'git push', then 'git pull && ./install.sh' on the next machine."
