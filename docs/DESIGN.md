# Design: todd-setup dotfiles sync

**Date:** 2026-07-06
**Status:** Approved — superseded in part, see Amendments

## Amendments

This section records what changed after approval. Everything below it describes the
original 2026-07-06 design; where the two disagree, `install.sh` and `README.md` are
the source of truth for what the repo does today.

- **2026-07-30 — `tmux` package dropped.** The tmux config and plugin scripts were
  removed in `041efca`, so the tmux Stow package, its `TARGETS` entries, the
  `TMUX_PLUGINS` clone step (original step 2) and the config-reload step (original
  step 6) are all gone from `install.sh`. Current packages: `nvim`, `claude`,
  `karabiner`.
- **`karabiner` package added** after approval — `karabiner/.config/karabiner/karabiner.json`
  → `~/.config/karabiner/karabiner.json`. It predates this amendment and is not in the
  layout diagram below.
- **2026-07-30 — tree folding is now prevented explicitly.** The original design assumed
  `~/.config` and `~/.claude` already exist, so Stow would fold into them and only link
  leaves. That assumption does not hold for `~/.config/karabiner`, which does not exist
  until Karabiner-Elements first runs: Stow then linked the package's whole directory,
  every repo file under it looked like a `$HOME` file, and the backup step moved
  `karabiner.json` out of the repo on the next run. `install.sh` now unstows, `mkdir -p`s
  each target's parent, then stows — and the backup step skips any target whose physical
  path resolves inside the repo.
- **2026-07-30 — `nvim` also owns `~/.markdownlint-cli2.yaml`** (added in `be915a8`), now
  listed in `TARGETS` so it is backed up and restored like every other leaf.

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
2. Clone tmux plugins (`tpm`, `tokyo-night-tmux`) into `~/.tmux/plugins/` if missing.
   Done **before** stow so `~/.tmux` is a real dir and Stow folds in (only linking our
   leaf scripts) instead of hijacking the whole `~/.tmux`.
3. For each managed leaf target, if it exists as a **real** (non-symlink) file/dir,
   move it to `~/.todd-setup-backup/<timestamp>/` preserving relative path. Existing
   symlinks we own are left alone.
4. `stow --restow` the packages.
5. Headless `nvim +Lazy! sync` to front-load Neovim plugins (skipped if nvim absent).
6. If a tmux server is running, `source-file` the config to reload it.

### Plugins: track vs. clone

- **Tracked in repo** (they're the user's own, unclonable): `~/.tmux/prefix-highlight.sh`,
  `~/.tmux/pane-aura.sh`.
- **Cloned by install.sh** (external repos): `tpm`, `tokyo-night-tmux`. nvim plugins are
  handled by LazyVim/lazy.nvim, which self-bootstraps.

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
