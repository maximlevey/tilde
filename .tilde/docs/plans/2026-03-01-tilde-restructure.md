# Tilde Restructure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Move `~/bin`, `~/lib`, `~/src` and the `~/.tilde` entry-point file into `~/.tilde/` to consolidate dotfile tooling under one namespace.

**Architecture:** Rename files via `git mv`, update path references in ~27 files. Most scripts use the `$ZSH_LIB` variable and need no changes. The entry point moves from `~/.tilde` (file) to `~/.tilde/bootstrap` (file inside directory).

**Tech Stack:** zsh, git, plist XML

---

### Task 1: Move directories and entry point with git mv

**Files:**
- Move: `bin/` → `.tilde/bin/`
- Move: `lib/` → `.tilde/lib/`
- Move: `src/` → `.tilde/src/`
- Move: `.tilde` (file) → `.tilde/bootstrap` (file)

**Step 1: Create the .tilde directory and move the entry point**

The `.tilde` file must become `.tilde/bootstrap`. Since git can't directly
move a file into a directory named the same thing, do it in stages:

```bash
cd ~
git mv .tilde .tilde-bootstrap-tmp
mkdir -p .tilde
git mv .tilde-bootstrap-tmp .tilde/bootstrap
```

**Step 2: Move bin/, lib/, src/ into .tilde/**

```bash
cd ~
git mv bin .tilde/bin
git mv lib .tilde/lib
git mv src .tilde/src
```

**Step 3: Verify the moves**

```bash
ls -la ~/.tilde/
# Expected: bootstrap, bin/, lib/, src/
ls ~/.tilde/bin/
# Expected: clone, domain, handler, lint, osabuild, setprefs, settings, shellbuild, symlink, tidy
ls ~/.tilde/lib/zsh/
# Expected: functions.zsh, logging.zsh, wrappers.zsh
```

**Step 4: Commit**

```bash
git add -A
git commit -m "refactor: move bin, lib, src into .tilde directory

Move entry point from .tilde (file) to .tilde/bootstrap.
Move bin/, lib/, src/ under .tilde/ to consolidate dotfile tooling."
```

---

### Task 2: Update .zshrc paths

**Files:**
- Modify: `.zshrc:5-8` (SRC, ZSH_LIB, PATH exports)
- Modify: `.zshrc:74` (shellcheck source comment)

**Step 1: Update environment exports**

In `.zshrc`, change lines 5-8 from:
```zsh
export SRC="$HOME/src"
export ZSH_LIB="$HOME/lib/zsh"

export PATH="$HOME/bin:$PATH"
```
to:
```zsh
export SRC="$HOME/.tilde/src"
export ZSH_LIB="$HOME/.tilde/lib/zsh"

export PATH="$HOME/.tilde/bin:$PATH"
```

**Step 2: Update shellcheck source comment**

In `.zshrc`, change line 74 from:
```zsh
  # shellcheck source=./lib/zsh
```
to:
```zsh
  # shellcheck source=./.tilde/lib/zsh
```

**Step 3: Commit**

```bash
git add .zshrc
git commit -m "refactor: update .zshrc paths to .tilde directory"
```

---

### Task 3: Update .tilde/bootstrap paths

**Files:**
- Modify: `.tilde/bootstrap:8-10` (usage comments)
- Modify: `.tilde/bootstrap:102-103` (cmd_bootstrap ZSH_LIB + PATH)
- Modify: `.tilde/bootstrap:105` (shellcheck source comment)
- Modify: `.tilde/bootstrap:221` (cmd_clean ZSH_LIB)
- Modify: `.tilde/bootstrap:223` (shellcheck source comment)
- Modify: `.tilde/bootstrap:235` (usage in clean)
- Modify: `.tilde/bootstrap:434` (usage in dispatcher)

**Step 1: Update usage comments at top of file**

Change lines 8-10 from:
```zsh
#   Fresh install:  /bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/maximlevey/tilde/main/.tilde)"
#   Bootstrap:      .tilde
#   Clean:          .tilde clean [--all]
```
to:
```zsh
#   Fresh install:  /bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/maximlevey/tilde/main/.tilde/bootstrap)"
#   Bootstrap:      .tilde/bootstrap
#   Clean:          .tilde/bootstrap clean [--all]
```

**Step 2: Update cmd_bootstrap environment**

Change lines 102-103 from:
```zsh
  export ZSH_LIB="${HOME}/lib/zsh"
  export PATH="${HOME}/bin:${HOME}/.local/bin:${PATH}"
```
to:
```zsh
  export ZSH_LIB="${HOME}/.tilde/lib/zsh"
  export PATH="${HOME}/.tilde/bin:${HOME}/.local/bin:${PATH}"
```

**Step 3: Update cmd_bootstrap shellcheck comment**

Change line 105 from:
```zsh
  # shellcheck source=./lib/zsh/logging.zsh
```
to:
```zsh
  # shellcheck source=./.tilde/lib/zsh/logging.zsh
```

**Step 4: Update cmd_clean ZSH_LIB**

Change line 221 from:
```zsh
  export ZSH_LIB="${HOME}/lib/zsh"
```
to:
```zsh
  export ZSH_LIB="${HOME}/.tilde/lib/zsh"
```

**Step 5: Update cmd_clean shellcheck comment**

Change line 223 from:
```zsh
  # shellcheck source=./lib/zsh/logging.zsh
```
to:
```zsh
  # shellcheck source=./.tilde/lib/zsh/logging.zsh
```

**Step 6: Update usage strings in clean and dispatcher**

Change line 235 from:
```zsh
        usage ".tilde clean [--all]"
```
to:
```zsh
        usage ".tilde/bootstrap clean [--all]"
```

Change line 434 from:
```zsh
    echo "Usage: .tilde [bootstrap|clean [--all]]" >&2
```
to:
```zsh
    echo "Usage: .tilde/bootstrap [bootstrap|clean [--all]]" >&2
```

**Step 7: Commit**

```bash
git add .tilde/bootstrap
git commit -m "refactor: update .tilde/bootstrap paths to new directory structure"
```

---

### Task 4: Update .gitignore whitelist

**Files:**
- Modify: `.gitignore:10-19`

**Step 1: Remove non-dotfile whitelist entries that are now under .tilde/**

`bin/`, `lib/`, `src/` are now `.tilde/bin/`, `.tilde/lib/`, `.tilde/src/` — already covered by the `!.*` and `!.*/**` rules. Remove the now-unnecessary whitelist entries.

Change lines 10-19 from:
```
# Non-dotfile directories and files.
!bin/
!bin/**
!lib/
!lib/**
!src/
!src/**
!docs/
!docs/**
!README.md
```
to:
```
# Non-dotfile directories and files.
!docs/
!docs/**
!README.md
```

**Step 2: Commit**

```bash
git add .gitignore
git commit -m "refactor: remove bin/lib/src from gitignore whitelist

These directories are now under .tilde/ and covered by the !.* rules."
```

---

### Task 5: Update shellcheck source comments in bin/ scripts

**Files:**
- Modify: `.tilde/bin/clone:4`
- Modify: `.tilde/bin/domain:6`
- Modify: `.tilde/bin/handler:4`
- Modify: `.tilde/bin/lint:6`
- Modify: `.tilde/bin/osabuild:6`
- Modify: `.tilde/bin/settings:4`
- Modify: `.tilde/bin/shellbuild:4`
- Modify: `.tilde/bin/symlink:6`
- Modify: `.tilde/bin/tidy:6`

**Step 1: Update all shellcheck source comments**

In each of the 9 bin/ scripts listed above, change:
```zsh
# shellcheck source=../lib/zsh/logging.zsh
```
to:
```zsh
# shellcheck source=../lib/zsh/logging.zsh
```

Wait — the relative path `../lib/zsh/logging.zsh` is still correct.
From `.tilde/bin/handler`, `..` resolves to `.tilde/`, and `../lib/zsh/logging.zsh`
resolves to `.tilde/lib/zsh/logging.zsh`. **No changes needed for bin/ scripts.**

Skip this task.

---

### Task 5 (revised): Update shellcheck source comments in bootstrap scripts

**Files:**
- Modify: `.macos/bootstrap.sh:6`
- Modify: `.rectangle/bootstrap.sh:6`
- Modify: `.cleanshot/bootstrap.sh:6`
- Modify: `.raycast/bootstrap.sh:6`
- Modify: `.warp/bootstrap.sh:6`
- Modify: `.launchd/bootstrap.sh:7`
- Modify: `.launchd/cleanup/cleanup.sh:11`
- Modify: `.launchd/unmount/unmount.sh:14`
- Modify: `.launchd/update/update.sh:6`

**Step 1: Update shellcheck source paths in app bootstrap scripts**

These scripts live at `~/.appname/bootstrap.sh`. Their shellcheck comments
point to `../lib/zsh/logging.zsh` which previously resolved from `~/.appname/`
up to `~/` then into `lib/zsh/`. Now `lib/` is at `~/.tilde/lib/`, so the
relative path needs updating.

In `.macos/bootstrap.sh`, `.rectangle/bootstrap.sh`, `.cleanshot/bootstrap.sh`,
`.raycast/bootstrap.sh`, `.warp/bootstrap.sh`, and `.launchd/bootstrap.sh`, change:
```zsh
# shellcheck source=../lib/zsh/logging.zsh
```
to:
```zsh
# shellcheck source=../.tilde/lib/zsh/logging.zsh
```

In `.launchd/cleanup/cleanup.sh`, `.launchd/unmount/unmount.sh`, and
`.launchd/update/update.sh`, change:
```zsh
# shellcheck source=../../lib/zsh/logging.zsh
```
to:
```zsh
# shellcheck source=../../.tilde/lib/zsh/logging.zsh
```

**Step 2: Commit**

```bash
git add .macos/bootstrap.sh .rectangle/bootstrap.sh .cleanshot/bootstrap.sh \
  .raycast/bootstrap.sh .warp/bootstrap.sh .launchd/bootstrap.sh \
  .launchd/cleanup/cleanup.sh .launchd/unmount/unmount.sh .launchd/update/update.sh
git commit -m "refactor: update shellcheck source paths for new .tilde layout"
```

---

### Task 6: Update LaunchAgent plist files

**Files:**
- Modify: `.launchd/cleanup/cleanup.plist:28`
- Modify: `.launchd/unmount/unmount.plist:28`
- Modify: `.launchd/update/update.plist:28`

**Step 1: Update ZSH_LIB path in all three plists**

In each of the three plist files, change:
```xml
            <string>/Users/maximlevey/lib/zsh</string>
```
to:
```xml
            <string>/Users/maximlevey/.tilde/lib/zsh</string>
```

**Step 2: Commit**

```bash
git add .launchd/cleanup/cleanup.plist .launchd/unmount/unmount.plist .launchd/update/update.plist
git commit -m "refactor: update ZSH_LIB path in LaunchAgent plists"
```

---

### Task 7: Verify everything works

**Step 1: Source .zshrc and verify paths resolve**

```bash
source ~/.zshrc
echo "ZSH_LIB=$ZSH_LIB"
# Expected: /Users/maximlevey/.tilde/lib/zsh
echo "SRC=$SRC"
# Expected: /Users/maximlevey/.tilde/src
which symlink
# Expected: /Users/maximlevey/.tilde/bin/symlink
```

**Step 2: Verify logging.zsh can be sourced**

```bash
source "$ZSH_LIB/logging.zsh"
log "test message"
# Expected: prints formatted test message
```

**Step 3: Verify git tracks everything**

```bash
git status
# Expected: clean working tree (no untracked files from old locations)
git ls-files | head -20
# Expected: paths like .tilde/bin/clone, .tilde/lib/zsh/logging.zsh, etc.
```

**Step 4: Check no old paths remain**

```bash
grep -r '"${HOME}/lib/zsh"' ~ --include='*.sh' --include='*.zsh' --include='.zshrc' --include='.tilde' 2>/dev/null || echo "No old paths found"
grep -r '"${HOME}/bin"' ~ --include='*.sh' --include='*.zsh' --include='.zshrc' 2>/dev/null || echo "No old paths found"
grep -r '/Users/maximlevey/lib/zsh' ~ --include='*.plist' 2>/dev/null || echo "No old plist paths found"
```
