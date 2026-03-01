# Restructure: Move bin/lib/src into ~/.tilde/

**Date:** 2026-03-01

## Goal

Move `~/bin`, `~/lib`, `~/src` and the `~/.tilde` entry-point file into a
single `~/.tilde/` directory. This eliminates three visible top-level
directories from `$HOME` and groups all dotfile tooling under one namespace
that matches the project name.

## Directory changes

| Before | After |
|--------|-------|
| `~/bin/` | `~/.tilde/bin/` |
| `~/lib/` | `~/.tilde/lib/` |
| `~/src/` | `~/.tilde/src/` |
| `~/.tilde` (file) | `~/.tilde/bootstrap` (file) |

## File-by-file changes

### Environment and PATH

**`.zshrc`** (lines 5, 6, 8):
```
SRC="$HOME/src"        → "$HOME/.tilde/src"
ZSH_LIB="$HOME/lib/zsh" → "$HOME/.tilde/lib/zsh"
PATH="$HOME/bin:$PATH"  → "$HOME/.tilde/bin:$PATH"
```

Shellcheck comment on line 74 updated to `./lib/zsh` → `./.tilde/lib/zsh`.

**`.tilde/bootstrap`** (was `.tilde`):
- Line 8: Fresh-install URL → `.../main/.tilde/bootstrap`
- Line 9: Usage → `.tilde/bootstrap`
- Line 10: Usage → `.tilde/bootstrap clean [--all]`
- Line 102: `ZSH_LIB` → `"${HOME}/.tilde/lib/zsh"`
- Line 103: PATH → `"${HOME}/.tilde/bin:..."`
- Line 221: `ZSH_LIB` → `"${HOME}/.tilde/lib/zsh"`

### .gitignore

Remove `!bin/`, `!bin/**`, `!lib/`, `!lib/**`, `!src/`, `!src/**` — these
directories are now under `.tilde/` which is already whitelisted by `!.*/**`.

### Shellcheck source comments

All 10 `bin/` scripts have `# shellcheck source=../lib/zsh/logging.zsh`.
Update to `# shellcheck source=../lib/zsh/logging.zsh` → `./logging.zsh`
or simply remove since shellcheck follows `$ZSH_LIB` anyway.

### LaunchAgent plists (3 files)

`.launchd/cleanup/cleanup.plist`, `.launchd/unmount/unmount.plist`,
`.launchd/update/update.plist` all contain:
```xml
<string>/Users/maximlevey/lib/zsh</string>
```
Change to:
```xml
<string>/Users/maximlevey/.tilde/lib/zsh</string>
```

### Bootstrap scripts

All 9 bootstrap scripts (`source "${ZSH_LIB}/logging.zsh"`) use the
`$ZSH_LIB` variable — no changes needed. The variable is set before these
scripts run.

## Fresh install

New curl-pipe command:
```sh
/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/maximlevey/tilde/main/.tilde/bootstrap)"
```

The script runs in memory via curl-pipe. It clones the repo (creating
`~/.tilde/` on disk), then sources `~/.tilde/lib/zsh/logging.zsh`. No
circular dependency.

## What stays the same

- Script logic (bootstrap, clean, dispatcher) — unchanged
- All `bin/` script functionality — unchanged
- All bootstrap script functionality — unchanged
- Homebrew, Setapp, Xcode sections — unchanged
- Clean command domain lists — unchanged

## Risks

None significant. All changes are mechanical path substitutions. The
`$ZSH_LIB` indirection means most scripts need zero changes.
