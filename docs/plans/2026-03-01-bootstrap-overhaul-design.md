# Bootstrap Overhaul Design

Date: 2026-03-01

## Problem

First-run bootstrap has multiple issues: interactive Xcode CLT prompt, Homebrew
fails to install/detect correctly across re-runs, no output middle-ground
(either silent or noisy), app preferences fail on fresh installs where plists
don't exist yet, deprecated Homebrew taps cause errors, Gatekeeper warnings on
cask apps, no way to undo changes for re-testing, and the script hangs after
printing "done".

## Approach

Incremental fixes to the existing `bootstrap.sh` + sub-scripts architecture.
No structural refactor — each fix is surgical and independently testable.

## Changes

### 1. Logging Overhaul (`lib/zsh/logging.zsh`)

Replace `log_inf`/`log_err` with setapp-cli Printer format:

- `log_info "msg"` — bold blue `==>` + bold white text (section headers)
- `log "msg"` — 4-space indented plain text (detail)
- `log_warn "msg"` — yellow `Warning:` prefix
- `log_err "msg"` — red `Error:` prefix, stderr

TTY-aware: color when interactive, plain when piped. All external command
output captured and suppressed; on failure, captured stderr printed via
`log_err`; on success, one-liner summary via `log`.

Add helper functions to the same file:

- `retry <n> <cmd...>` — retry a command up to n times with 5s delay
- `ensure_app "App Name" "com.bundle.id"` — open app to create plist if
  missing, then quit
- `run_quiet <cmd...>` — run a command with output captured, print stderr
  on failure

### 2. Non-Interactive Xcode CLT

Replace `xcode-select --install` (GUI prompt) with:

```
sudo touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
softwareupdate -l  # parse for CLT package name
softwareupdate -i "<package>"
sudo rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
```

Keep `xcode-select -p` guard and `sudo xcodebuild -license accept`.

### 3. Homebrew Fixes

- Move `eval "$(/opt/homebrew/bin/brew shellenv)"` before `command -v brew`
  check so re-runs detect existing install.
- After install, verify with `brew --version` health check.
- Remove deprecated taps (`homebrew/bundle`, `homebrew/cask-fonts`) from
  Brewfile.
- After `brew bundle`, clear quarantine on cask apps:
  `xattr -dr com.apple.quarantine /Applications/<app>.app`

### 4. Full Xcode via xcodes (Background)

- Add `xcodes` to Brewfile.
- After main bootstrap completes, background a detached Xcode install:
  `xcodes install --latest --experimental-unxip`
- Logs to `~/Desktop/xcode-install.log`.
- Guard: skip if `/Applications/Xcode.app` already exists.

### 5. Plist Readiness (`ensure_app`)

Each third-party app bootstrap calls `ensure_app` before `setprefs`:

1. Check `~/Library/Preferences/com.bundle.id.plist`
2. If missing: `open -a "App Name"`, poll for plist (10s timeout), quit app
3. Then proceed with `setprefs`

System domains (com.apple.*) don't need this.

### 6. Output Verbosity

Every phase gets `==> Section header` with indented summaries. External command
output captured. Example:

```
==> Installing Xcode Command Line Tools
    Found Command Line Tools 16.0
    Installation complete
==> Installing Homebrew
    Homebrew 4.5.0 installed
==> Installing Homebrew packages
    Installed 8 formulae and 10 casks
    Cleared quarantine on 8 apps
```

### 7. Script Exit Fix

The sudo keepalive loop (`while true; sleep 50; done &`) is killed via trap.
Add explicit `kill $SUDO_PID` + `wait` before final message to prevent hang.

### 8. Self-Remediation

- `retry 3` wrapper on network operations (brew bundle, git clone, softwareupdate)
- On final failure: log error and continue to next phase (don't abort)
- Each phase is independent enough to tolerate upstream failures

### 9. Clean Script (`clean.sh`)

Selective reset with prompts at each stage:

1. LaunchAgents — unload
2. App preferences — `defaults delete` per domain
3. macOS preferences — reset modified system domains
4. Homebrew casks — uninstall
5. Homebrew formulae — uninstall
6. Homebrew itself — official uninstall script
7. Dotfiles — remove tracked files from $HOME, remove .git

Never cleaned: Xcode CLT, full Xcode. Default No at each prompt. `--all` flag
skips prompts.

## Files Modified

- `lib/zsh/logging.zsh` — complete rewrite
- `bootstrap.sh` — reworked flow
- `.brew/Brewfile` — remove deprecated taps, add xcodes
- `.macos/bootstrap.sh` — new logging format
- `.cleanshot/bootstrap.sh` — add ensure_app
- `.coderunner/bootstrap.sh` — add ensure_app
- `.raycast/bootstrap.sh` — add ensure_app
- `.rectangle/bootstrap.sh` — add ensure_app
- `.warp/bootstrap.sh` — add ensure_app
- `.launchd/bootstrap.sh` — new logging format

## Files Added

- `clean.sh` — selective reset script

## Deferred

- Raycast replacing Finder
- GitHub Actions CI
- Setapp-cli related fixes
