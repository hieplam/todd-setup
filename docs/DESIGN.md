# Design: todd-setup dotfiles sync

**Date:** 2026-07-06
**Status:** Approved

## Problem

Configs for tmux, Neovim, and the Claude Code statusline are maintained by hand on
multiple machines. A change on one machine has to be re-applied everywhere by hand,
so machines drift apart.

## Goal

One git repo is the single source of truth. Each machine clones it once and runs an
install script that symlinks the tracked files into place. Editing a config edits the
repo (via the symlink); `git push` / `git pull && ./install.sh` propagates it.

## Tooling

- **GNU Stow** — the only engine. A symlink-farm manager: given a package directory
  that mirrors `$HOME`, it creates matching symlinks. No custom framework.
- **git** for sync between machines.
- **Homebrew** only to install Stow the first time.

Platform: macOS only (per requirements).

## Repo layout (Stow packages)

```
todd-setup/
├── install.sh
├── uninstall.sh
├── README.md
├── docs/DESIGN.md
├── tmux/   .tmux.conf                        → ~/.tmux.conf
├── nvim/   .config/nvim/…                     → ~/.config/nvim
└── claude/ .claude/statusline-command.sh      → ~/.claude/statusline-command.sh
          .claude/statusline-class.sh          → ~/.claude/statusline-class.sh
```

Each package's inner tree mirrors `$HOME`. Stow is invoked as
`stow --dir=<repo> --target=$HOME --restow <pkg>`. Because `~/.config` and `~/.claude`
already exist as real directories, Stow folds into them and only symlinks the leaf
files listed above — it never captures the whole directory.

## install.sh

Idempotent. Steps:
1. Ensure `stow` exists; `brew install stow` if not (fail clearly if no Homebrew).
2. For each managed leaf target, if it exists as a **real** (non-symlink) file/dir,
   move it to `~/.todd-setup-backup/<timestamp>/` preserving relative path. Existing
   symlinks we own are left alone.
3. `stow --restow` the packages.

## uninstall.sh (revert)

1. `stow --delete` removes only the symlinks Stow created.
2. Restore the most recent `~/.todd-setup-backup/<timestamp>/`, but never clobber a
   target that still exists — skip and warn instead. Backups are preserved.

Guarantee: **install backs up → uninstall unlinks + restores.** Fully reversible, no
data loss.

## Per-machine overrides (.local)

- tmux: tracked config appends `source-file -q ~/.tmux.conf.local` (untracked, optional).
- nvim: gitignored `lua/plugins/local.lua`, auto-loaded by LazyVim.

## Non-goals (YAGNI)

- zsh / gitconfig syncing (not selected).
- Secrets management, templating, cross-distro Linux support.
- These can be added later as new Stow packages without reworking anything.
