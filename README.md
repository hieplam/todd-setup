# todd-setup

My portable dotfiles — one source of truth for **tmux**, **Neovim** (LazyVim), and
my **Claude Code statusline**, synced across every machine with [GNU Stow](https://www.gnu.org/software/stow/).

Edit a config on any machine → `git push` → `git pull && ./install.sh` on the next
machine. Because the real files are symlinks into this repo, a pulled change is live
immediately.

## What's tracked

| Package | Symlinks to | Contents |
|---------|-------------|----------|
| `tmux`  | `~/.tmux.conf`, `~/.tmux/prefix-highlight.sh`, `~/.tmux/pane-aura.sh` | tmux config + custom status/pane scripts |
| `nvim`  | `~/.config/nvim` | full LazyVim setup incl. `lazy-lock.json` (pinned plugin versions) |
| `claude`| `~/.claude/statusline-command.sh`, `~/.claude/statusline-class.sh` | Claude Code statusline scripts |

Stow "folds into" existing directories like `~/.config`, `~/.claude`, and `~/.tmux`,
so it only ever creates the leaf symlinks above — it never takes over the whole
directory.

### Plugins (installed by the script, not committed)

Symlinks alone don't bootstrap plugin managers, so `install.sh` also installs them:

- **tmux** — clones `tpm` and the active `tokyo-night-tmux` theme into
  `~/.tmux/plugins/`. (The commented-out catppuccin/nord/rose-pine themes aren't
  cloned by default; add them to `TMUX_PLUGINS` in `install.sh` if you switch to one.)
- **nvim** — runs a headless `Lazy! sync` so LazyVim's plugins are ready immediately.
  LazyVim self-bootstraps `lazy.nvim`, so first launch would install them anyway.

## Install (new or existing machine)

```bash
git clone git@github.com:hieplam/todd-setup.git ~/repos/todd-setup
cd ~/repos/todd-setup
./install.sh
```

`install.sh` will:
1. Ensure GNU Stow is installed (`brew install stow` if missing).
2. Back up any pre-existing real config it would replace into
   `~/.todd-setup-backup/<timestamp>/` — nothing is ever overwritten or deleted.
3. Symlink the packages into `$HOME`.

It's idempotent — re-run it any time (e.g. after a `git pull`).

## Uninstall / revert

```bash
cd ~/repos/todd-setup
./uninstall.sh
```

Removes the symlinks (Stow's native `--delete`, only touches links it created) and
restores the most recent `~/.todd-setup-backup/<timestamp>/`, returning the machine
to its pre-install state. Backups are left intact.

## Per-machine overrides

Keep machine-specific tweaks out of the repo:

- **tmux** — put local lines in `~/.tmux.conf.local`; the tracked config ends with
  `source-file -q ~/.tmux.conf.local`, loaded only if it exists.
- **nvim** — drop a `lua/plugins/local.lua`; LazyVim auto-loads it and it's gitignored.

## Requirements

- macOS with [Homebrew](https://brew.sh)
- `git`, `tmux`, `nvim` (LazyVim)
