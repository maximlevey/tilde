# Bootstrap Overhaul Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all bootstrap.sh issues: non-interactive Xcode CLT, Homebrew idempotency, setapp-cli output format, plist readiness, quarantine removal, background Xcode install, clean script.

**Architecture:** Incremental fixes to the existing bootstrap.sh + sub-scripts structure. New logging library replaces log_inf/log_err. Helper functions added for retry, quiet execution, and plist readiness. New clean.sh for teardown.

**Tech Stack:** zsh, macOS defaults, Homebrew, xcodes, softwareupdate

---

### Task 1: Rewrite logging library

**Files:**
- Modify: `lib/zsh/logging.zsh` (complete rewrite)

**Step 1: Write the new logging.zsh**

Replace the entire file with:

```zsh
#
# Shared logging, helpers, and usage functions for shell scripts.
# Output format matches setapp-cli Printer style.

# TTY detection for color support
if [[ -t 1 ]]; then
  readonly _BOLD=$'\033[1m'
  readonly _BOLD_BLUE=$'\033[1;34m'
  readonly _YELLOW=$'\033[33m'
  readonly _RED=$'\033[31m'
  readonly _RESET=$'\033[0m'
else
  readonly _BOLD=''
  readonly _BOLD_BLUE=''
  readonly _YELLOW=''
  readonly _RED=''
  readonly _RESET=''
fi

#######################################
# Print a section header (bold blue ==> bold text).
# Arguments:
#   message - the section header text
# Outputs:
#   Writes formatted header to stdout
#######################################
log_info() {
  printf '%s==>%s %s%s%s\n' \
    "${_BOLD_BLUE}" "${_RESET}" "${_BOLD}" "$1" "${_RESET}"
}

#######################################
# Print a detail message (4-space indented).
# Arguments:
#   message - the detail text
# Outputs:
#   Writes indented message to stdout
#######################################
log() {
  printf '    %s\n' "$1"
}

#######################################
# Print a warning message (yellow Warning: prefix).
# Arguments:
#   message - the warning text
# Outputs:
#   Writes warning to stdout
#######################################
log_warn() {
  printf '%sWarning:%s %s\n' "${_YELLOW}" "${_RESET}" "$1"
}

#######################################
# Print an error message (red Error: prefix).
# Arguments:
#   message - the error text
# Outputs:
#   Writes error to stderr
#######################################
log_err() {
  printf '%sError:%s %s\n' "${_RED}" "${_RESET}" "$1" >&2
}

#######################################
# Print usage string and exit.
# Arguments:
#   usage_string - the usage pattern to display
# Outputs:
#   Writes "Usage: <string>" to stderr
#######################################
usage() {
  printf 'Usage: %s\n' "$1" >&2
  exit 9
}

#######################################
# Run a command with output captured. On failure,
# print captured stderr via log_err.
# Arguments:
#   cmd... - the command and arguments to run
# Returns:
#   Exit code of the command
#######################################
run_quiet() {
  local output
  output="$("$@" 2>&1)" || {
    local rc=$?
    log_err "Command failed: $1"
    printf '    %s\n' "${output}" >&2
    return "${rc}"
  }
}

#######################################
# Retry a command up to N times with 5-second delay.
# Arguments:
#   n   - maximum number of attempts
#   cmd... - the command and arguments to run
# Returns:
#   Exit code of the last attempt
#######################################
retry() {
  local max_attempts=$1; shift
  local attempt=1
  local rc=0

  while (( attempt <= max_attempts )); do
    "$@" && return 0
    rc=$?
    if (( attempt < max_attempts )); then
      log_warn "Attempt ${attempt}/${max_attempts} failed, retrying in 5s..."
      sleep 5
    fi
    (( attempt++ ))
  done

  log_err "Failed after ${max_attempts} attempts: $1"
  return "${rc}"
}

#######################################
# Ensure an app's plist exists by briefly opening
# the app if needed, then quitting it.
# Arguments:
#   app_name  - display name (e.g. "Raycast")
#   bundle_id - bundle identifier (e.g. "com.raycast.macos")
# Returns:
#   0 on success, 1 if plist never appeared
#######################################
ensure_app() {
  local app_name="$1"
  local bundle_id="$2"
  local plist="${HOME}/Library/Preferences/${bundle_id}.plist"
  local waited=0

  if [[ -f "${plist}" ]]; then
    return 0
  fi

  log "Opening ${app_name} to initialise preferences..."
  open -a "${app_name}" 2>/dev/null || {
    log_warn "${app_name} is not installed, skipping preferences"
    return 1
  }

  while [[ ! -f "${plist}" ]] && (( waited < 10 )); do
    sleep 1
    (( waited++ ))
  done

  osascript -e "quit app \"${app_name}\"" 2>/dev/null || true
  sleep 1

  if [[ ! -f "${plist}" ]]; then
    log_warn "${app_name} plist did not appear after ${waited}s"
    return 1
  fi

  return 0
}
```

**Step 2: Verify the file parses**

Run: `zsh -n lib/zsh/logging.zsh`
Expected: no output (clean parse)

**Step 3: Commit**

```bash
git add lib/zsh/logging.zsh
git commit -m "refactor: rewrite logging library to match setapp-cli output format

Add log_info, log, log_warn, log_err with TTY-aware color.
Add run_quiet, retry, and ensure_app helpers."
```

---

### Task 2: Update symlink script for new logging

**Files:**
- Modify: `bin/symlink`

**Step 1: Update the symlink script**

Replace `log_inf --exit` and `log_err --exit` calls with new functions.
The `--exit` pattern is gone; use explicit returns/exits instead.

Replace entire file:

```zsh
#!/usr/bin/env zsh
# shellcheck shell=bash
#
# Create or update a symbolic link with backup support.

# shellcheck source=../lib/zsh/logging.zsh
source "${ZSH_LIB}/logging.zsh"

readonly TARGET="$1"
readonly DEST="$2"

[[ "$#" -ge 2 ]] || usage "symlink <source> <destination>"

if [[ ! -e "${TARGET}" ]]; then
  log_err "${TARGET} does not exist"
  exit 3
fi

if [[ "${TARGET}" = "$(readlink -f "${DEST}")" ]]; then
  log "Symbolic link already exists"
  exit 0
fi

[[ -L "${DEST}" ]] && rm -rf "${DEST}" >/dev/null

[[ -e "${DEST}" ]] && mv "${DEST}" "${DEST}.bak" >/dev/null

ln -sfn "${TARGET}" "${DEST}" >/dev/null
```

**Step 2: Verify**

Run: `zsh -n bin/symlink`
Expected: no output

**Step 3: Commit**

```bash
git add bin/symlink
git commit -m "refactor: update symlink script for new logging API"
```

---

### Task 3: Update Brewfile

**Files:**
- Modify: `.brew/Brewfile`

**Step 1: Remove deprecated taps, add xcodes**

Replace entire file:

```ruby
# Homebrew packages
brew 'curl'
brew 'gh'
brew 'jq'
brew 'shfmt'
brew 'shellcheck'
brew 'swiftformat'
brew 'swiftlint'
brew 'xcodes'
brew 'yq'

# Homebrew casks
cask 'affinity'
cask 'claude'
cask 'cursor'
cask 'font-hack-nerd-font'
cask 'raycast'
cask 'rectangle-pro'
cask 'setapp'
cask 'spotify'
cask 'warp'
cask 'whatsapp'
```

**Step 2: Validate syntax**

Run: `brew bundle check --file="${HOME}/.brew/Brewfile" 2>&1 || true`
Expected: may report missing packages but no syntax errors

**Step 3: Commit**

```bash
git add .brew/Brewfile
git commit -m "fix: remove deprecated taps, add xcodes to Brewfile

homebrew/bundle and homebrew/cask-fonts are deprecated and built
into Homebrew core. Add xcodes for full Xcode installation."
```

---

### Task 4: Rewrite main bootstrap.sh

**Files:**
- Modify: `bootstrap.sh` (complete rewrite)

**Step 1: Write the new bootstrap.sh**

```zsh
#!/usr/bin/env zsh
# shellcheck shell=bash
#
# Bootstrap a fresh macOS installation. Installs developer tools,
# clones dotfiles into $HOME (retaining .git), installs Homebrew
# packages and Setapp apps, then runs app-specific bootstrap scripts.
#
# Usage: /bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/maximlevey/tilde/main/bootstrap.sh)"

readonly REPO="https://github.com/maximlevey/tilde.git"

#######################################
# Sudo keepalive
#######################################

echo "Requesting administrator privileges..."
sudo -v

while true; do sudo -n true; sleep 50; done 2>/dev/null &
SUDO_PID=$!
trap 'kill ${SUDO_PID} 2>/dev/null; wait ${SUDO_PID} 2>/dev/null' EXIT

#######################################
# Xcode Command Line Tools
#######################################

if ! xcode-select -p &>/dev/null; then
  echo "==> Installing Xcode Command Line Tools"

  sudo touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

  clt_package="$(softwareupdate -l 2>/dev/null \
    | grep -o 'Command Line Tools for Xcode-[0-9.]*' \
    | sort -V \
    | tail -n1)"

  if [[ -n "${clt_package}" ]]; then
    echo "    Found ${clt_package}"
    softwareupdate -i "${clt_package}" --verbose 2>&1 \
      | grep -E '^(Software Update|Installing|Done)' || true
    echo "    Installation complete"
  else
    echo "    Error: Could not find CLT package via softwareupdate" >&2
    echo "    Falling back to xcode-select --install" >&2
    xcode-select --install
    until xcode-select -p &>/dev/null; do sleep 5; done
  fi

  sudo rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
else
  echo "==> Xcode Command Line Tools already installed"
fi

sudo xcodebuild -license accept 2>/dev/null || true

#######################################
# Clone / update dotfiles
#######################################

if [[ ! -d "${HOME}/.git" ]]; then
  echo "==> Cloning dotfiles"
  TMP="$(mktemp -d)"
  readonly TMP
  trap 'kill ${SUDO_PID} 2>/dev/null; wait ${SUDO_PID} 2>/dev/null; rm -rf "${TMP}"' EXIT

  if git clone --depth 1 "${REPO}" "${TMP}" 2>/dev/null; then
    rsync -ah --exclude '.git' "${TMP}/" "${HOME}/" 2>/dev/null
    mv "${TMP}/.git" "${HOME}/.git"
    echo "    Dotfiles cloned"
  else
    echo "    Error: Failed to clone dotfiles" >&2
    exit 1
  fi
else
  echo "==> Updating dotfiles"
  if git -C "${HOME}" pull --ff-only 2>/dev/null; then
    echo "    Dotfiles updated"
  else
    echo "    Pull failed; continuing with local copy"
  fi
fi

#######################################
# Source environment
#######################################

export ZSH_LIB="${HOME}/lib/zsh"
export PATH="${HOME}/bin:${PATH}"

# shellcheck source=./lib/zsh/logging.zsh
source "${ZSH_LIB}/logging.zsh"

#######################################
# Homebrew
#######################################

# Source brew shellenv first so re-runs detect existing install
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if ! command -v brew &>/dev/null; then
  log_info "Installing Homebrew"
  if NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    &>/dev/null; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    log "Homebrew $(brew --version | head -n1 | awk '{print $2}') installed"
  else
    log_err "Homebrew installation failed"
  fi
else
  log_info "Homebrew already installed"
fi

if command -v brew &>/dev/null; then
  log_info "Installing Homebrew packages"
  if retry 3 brew bundle --no-lock --file "${HOME}/.brew/Brewfile" &>/dev/null; then
    local_formulae="$(brew bundle list --formula --file "${HOME}/.brew/Brewfile" 2>/dev/null | wc -l | tr -d ' ')"
    local_casks="$(brew bundle list --cask --file "${HOME}/.brew/Brewfile" 2>/dev/null | wc -l | tr -d ' ')"
    log "Installed ${local_formulae} formulae and ${local_casks} casks"
  else
    log_err "brew bundle failed after retries"
  fi

  # Remove quarantine attributes from Homebrew cask apps
  log_info "Clearing quarantine attributes"
  local_cleared=0
  for app in /Applications/*.app; do
    if xattr -l "${app}" 2>/dev/null | grep -q com.apple.quarantine; then
      xattr -dr com.apple.quarantine "${app}" 2>/dev/null && (( local_cleared++ ))
    fi
  done
  log "Cleared quarantine on ${local_cleared} apps"
fi

#######################################
# Setapp
#######################################

if ! command -v setapp-cli &>/dev/null; then
  log_info "Installing setapp-cli"
  if /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/maximlevey/setapp-cli/main/install.sh)" \
    &>/dev/null; then
    export PATH="${HOME}/.local/bin:${PATH}"
    log "setapp-cli installed"
  else
    log_err "setapp-cli installation failed"
  fi
else
  log_info "setapp-cli already installed"
fi

if command -v setapp-cli &>/dev/null && [[ -f "${HOME}/.setapp/AppList" ]]; then
  log_info "Installing Setapp apps"
  setapp-cli bundle install --file "${HOME}/.setapp/AppList" || true
fi

#######################################
# App-specific bootstrap scripts
#######################################

log_info "Running app bootstrap scripts"

for script in "${HOME}"/.*/"bootstrap.sh"; do
  [[ -f "${script}" ]] || continue
  dir_name="${script%/*}"
  dir_name="${dir_name##*/}"
  dir_name="${dir_name#.}"
  log_info "Configuring ${dir_name}"
  zsh "${script}" || log_err "Failed: ${script}"
done

#######################################
# Full Xcode (background)
#######################################

if [[ ! -d "/Applications/Xcode.app" ]] && command -v xcodes &>/dev/null; then
  log_info "Starting Xcode installation in background"
  log "Progress logged to ~/Desktop/xcode-install.log"
  nohup zsh -c '
    xcodes install --latest --experimental-unxip \
      >> ~/Desktop/xcode-install.log 2>&1
    sudo xcodebuild -license accept 2>/dev/null || true
  ' &>/dev/null &
  disown
elif [[ -d "/Applications/Xcode.app" ]]; then
  log_info "Xcode already installed"
fi

#######################################
# Done
#######################################

# Kill sudo keepalive before exiting
kill ${SUDO_PID} 2>/dev/null
wait ${SUDO_PID} 2>/dev/null
trap - EXIT

log_info "Bootstrap complete"
```

**Step 2: Verify syntax**

Run: `zsh -n bootstrap.sh`
Expected: no output

**Step 3: Commit**

```bash
git add bootstrap.sh
git commit -m "feat: rewrite bootstrap.sh with non-interactive Xcode CLT,
Homebrew idempotency, captured output, quarantine removal,
and background Xcode installation"
```

---

### Task 5: Update app bootstrap scripts with ensure_app

**Files:**
- Modify: `.cleanshot/bootstrap.sh`
- Modify: `.coderunner/bootstrap.sh`
- Modify: `.raycast/bootstrap.sh`
- Modify: `.rectangle/bootstrap.sh`
- Modify: `.warp/bootstrap.sh`

**Step 1: Rewrite each app bootstrap**

`.cleanshot/bootstrap.sh`:
```zsh
#!/usr/bin/env zsh
# shellcheck shell=bash
#
# Configures CleanShot X on a new device.

# shellcheck source=../lib/zsh/logging.zsh
source "${ZSH_LIB}/logging.zsh"

readonly APP_NAME="CleanShot X"
readonly BUNDLE_ID="com.getcleanshot.app-setapp"
readonly CONFIG_DIR="${HOME}/.cleanshot"

ensure_app "${APP_NAME}" "${BUNDLE_ID}" || return 0
setprefs "${CONFIG_DIR}/preferences.json"
```

`.coderunner/bootstrap.sh`:
```zsh
#!/usr/bin/env zsh
# shellcheck shell=bash
#
# Configures CodeRunner on a new device.

# shellcheck source=../lib/zsh/logging.zsh
source "${ZSH_LIB}/logging.zsh"

readonly APP_NAME="CodeRunner"
readonly BUNDLE_ID="com.krill.CodeRunner"
readonly CONFIG_DIR="${HOME}/.coderunner"

ensure_app "${APP_NAME}" "${BUNDLE_ID}" || return 0

log "Creating symlinks..."
symlink "${CONFIG_DIR}/themes" "${HOME}/Library/Application Support/CodeRunner/Themes"
symlink "${CONFIG_DIR}/languages" "${HOME}/Library/Application Support/CodeRunner/Languages"

setprefs "${CONFIG_DIR}/preferences.json"
```

`.raycast/bootstrap.sh`:
```zsh
#!/usr/bin/env zsh
# shellcheck shell=bash
#
# Configures Raycast on a new device.

# shellcheck source=../lib/zsh/logging.zsh
source "${ZSH_LIB}/logging.zsh"

readonly APP_NAME="Raycast"
readonly BUNDLE_ID="com.raycast.macos"
readonly CONFIG_DIR="${HOME}/.raycast"

ensure_app "${APP_NAME}" "${BUNDLE_ID}" || return 0

log "Creating symlinks..."
symlink "${CONFIG_DIR}" "${HOME}/.config/raycast"

setprefs "${CONFIG_DIR}/preferences.json"
```

`.rectangle/bootstrap.sh`:
```zsh
#!/usr/bin/env zsh
# shellcheck shell=bash
#
# Configures Rectangle Pro on a new device.

# shellcheck source=../lib/zsh/logging.zsh
source "${ZSH_LIB}/logging.zsh"

readonly APP_NAME="Rectangle Pro"
readonly BUNDLE_ID="com.knollsoft.Hookshot"
readonly CONFIG_DIR="${HOME}/.rectangle"

ensure_app "${APP_NAME}" "${BUNDLE_ID}" || return 0
setprefs "${CONFIG_DIR}/preferences.json"
```

`.warp/bootstrap.sh`:
```zsh
#!/usr/bin/env zsh
# shellcheck shell=bash
#
# Configures Warp terminal on a new device.

# shellcheck source=../lib/zsh/logging.zsh
source "${ZSH_LIB}/logging.zsh"

readonly APP_NAME="Warp"
readonly BUNDLE_ID="dev.warp.Warp-Stable"
readonly CONFIG_DIR="${HOME}/.warp"

ensure_app "${APP_NAME}" "${BUNDLE_ID}" || return 0
setprefs "${CONFIG_DIR}/preferences.json"
```

**Step 2: Verify all parse cleanly**

Run: `for f in .cleanshot .coderunner .raycast .rectangle .warp; do zsh -n "${HOME}/${f}/bootstrap.sh" && echo "OK: ${f}" || echo "FAIL: ${f}"; done`
Expected: all OK

**Step 3: Commit**

```bash
git add .cleanshot/bootstrap.sh .coderunner/bootstrap.sh .raycast/bootstrap.sh \
  .rectangle/bootstrap.sh .warp/bootstrap.sh
git commit -m "feat: add ensure_app plist readiness to all app bootstrap scripts"
```

---

### Task 6: Update macOS bootstrap script

**Files:**
- Modify: `.macos/bootstrap.sh`

**Step 1: Update to new logging format**

```zsh
#!/usr/bin/env zsh
# shellcheck shell=bash
#
# Set macOS system preferences.

# shellcheck source=../lib/zsh/logging.zsh
source "${ZSH_LIB}/logging.zsh"

osascript -e "quit app \"System Preferences\"" 2>/dev/null || true
osascript -e "quit app \"System Settings\"" 2>/dev/null || true

setprefs "$(dirname "${0}")/preferences.json"

# Remove all apps from the Dock
log "Clearing Dock..."
defaults write com.apple.dock persistent-apps -array
defaults write com.apple.dock persistent-others -array

# Show the ~/Library folder (hidden by default)
chflags nohidden "${HOME}/Library"

log "Restarting affected services..."
killall ControlCenter 2>/dev/null || true
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true
```

**Step 2: Verify**

Run: `zsh -n .macos/bootstrap.sh`

**Step 3: Commit**

```bash
git add .macos/bootstrap.sh
git commit -m "refactor: update macOS bootstrap to new logging format"
```

---

### Task 7: Update launchd bootstrap script

**Files:**
- Modify: `.launchd/bootstrap.sh`

**Step 1: Update to new logging format**

```zsh
#!/usr/bin/env zsh
# shellcheck shell=bash
#
# Load LaunchAgents from subdirectories that contain both a
# .plist and .sh file.

# shellcheck source=../lib/zsh/logging.zsh
source "${ZSH_LIB}/logging.zsh"

readonly LAUNCHD_DIR="${HOME}/.launchd"

for subdir in "${LAUNCHD_DIR}"/*/; do
  [[ -d "${subdir}" ]] || continue

  plist="$(find "${subdir}" -maxdepth 1 -name '*.plist' -print -quit)"
  script="$(find "${subdir}" -maxdepth 1 -name '*.sh' -print -quit)"

  if [[ -z "${plist}" ]] || [[ -z "${script}" ]]; then
    log_warn "Skipping ${subdir##*/}: missing .plist or .sh"
    continue
  fi

  log "Loading ${plist##*/}..."
  launchctl load "${plist}" 2>/dev/null ||
    log_err "Failed to load ${plist##*/}"
done
```

**Step 2: Verify**

Run: `zsh -n .launchd/bootstrap.sh`

**Step 3: Commit**

```bash
git add .launchd/bootstrap.sh
git commit -m "refactor: update launchd bootstrap to new logging format"
```

---

### Task 8: Create clean.sh

**Files:**
- Create: `clean.sh`

**Step 1: Write clean.sh**

```zsh
#!/usr/bin/env zsh
# shellcheck shell=bash
#
# Undo changes made by bootstrap.sh. Prompts at each stage unless
# --all is passed. Xcode CLT and full Xcode are never removed.
#
# Usage: zsh clean.sh [--all]

export ZSH_LIB="${HOME}/lib/zsh"
export PATH="${HOME}/bin:${PATH}"

# shellcheck source=./lib/zsh/logging.zsh
source "${ZSH_LIB}/logging.zsh"

SKIP_PROMPTS=false
[[ "${1:-}" == "--all" ]] && SKIP_PROMPTS=true

#######################################
# Prompt the user for confirmation.
# Arguments:
#   message - the prompt text
# Returns:
#   0 if confirmed, 1 if declined
#######################################
confirm() {
  if ${SKIP_PROMPTS}; then
    return 0
  fi
  printf '%s==>%s %s%s [y/N] %s' \
    "${_BOLD_BLUE}" "${_RESET}" "${_BOLD}" "$1" "${_RESET}"
  read -r response
  [[ "${response}" =~ ^[Yy] ]]
}

#######################################
# Phase 1: LaunchAgents
#######################################

if confirm "Unload LaunchAgents?"; then
  for subdir in "${HOME}/.launchd"/*/; do
    [[ -d "${subdir}" ]] || continue
    plist="$(find "${subdir}" -maxdepth 1 -name '*.plist' -print -quit)"
    [[ -n "${plist}" ]] || continue
    launchctl unload "${plist}" 2>/dev/null &&
      log "Unloaded ${plist##*/}" ||
      log_warn "Could not unload ${plist##*/}"
  done
fi

#######################################
# Phase 2: App preferences
#######################################

readonly APP_DOMAINS=(
  "com.getcleanshot.app-setapp"
  "com.krill.CodeRunner"
  "com.raycast.macos"
  "com.knollsoft.Hookshot"
  "dev.warp.Warp-Stable"
)

if confirm "Reset app preferences?"; then
  for domain in "${APP_DOMAINS[@]}"; do
    defaults delete "${domain}" 2>/dev/null &&
      log "Reset ${domain}" ||
      log "Skipped ${domain} (no preferences found)"
  done
fi

#######################################
# Phase 3: macOS preferences
#######################################

readonly MACOS_DOMAINS=(
  "NSGlobalDomain"
  "com.apple.driver.AppleBluetoothMultitouch.trackpad"
  "com.apple.AppleMultitouchTrackpad"
  "com.apple.finder"
  "com.apple.dock"
  "com.apple.WindowManager"
  "com.apple.menuextra.clock"
  "com.apple.screencapture"
  "com.apple.desktopservices"
  "com.apple.DiskUtility"
  "com.apple.controlcenter"
  "com.apple.Siri"
  "com.apple.voicetrigger"
  "com.apple.Passwords"
  "com.apple.onetimepasscodes"
  "com.apple.ncprefs"
  "com.apple.sharingd"
  "org.cups.PrintingPrefs"
)

if confirm "Reset macOS preferences?"; then
  log_warn "This resets entire preference domains to system defaults"
  for domain in "${MACOS_DOMAINS[@]}"; do
    if [[ "${domain}" == "NSGlobalDomain" ]]; then
      log "Skipping NSGlobalDomain (too broad to safely reset)"
      continue
    fi
    defaults delete "${domain}" 2>/dev/null &&
      log "Reset ${domain}" ||
      log "Skipped ${domain}"
  done
  killall Dock 2>/dev/null || true
  killall Finder 2>/dev/null || true
  killall SystemUIServer 2>/dev/null || true
  log "Restarted affected services"
fi

#######################################
# Phase 4: Homebrew casks
#######################################

if confirm "Uninstall Homebrew casks?" && command -v brew &>/dev/null; then
  while IFS= read -r cask_name; do
    brew uninstall --cask "${cask_name}" 2>/dev/null &&
      log "Uninstalled ${cask_name}" ||
      log_warn "Could not uninstall ${cask_name}"
  done < <(brew bundle list --cask --file "${HOME}/.brew/Brewfile" 2>/dev/null)
fi

#######################################
# Phase 5: Homebrew formulae
#######################################

if confirm "Uninstall Homebrew formulae?" && command -v brew &>/dev/null; then
  while IFS= read -r formula; do
    brew uninstall "${formula}" 2>/dev/null &&
      log "Uninstalled ${formula}" ||
      log_warn "Could not uninstall ${formula}"
  done < <(brew bundle list --formula --file "${HOME}/.brew/Brewfile" 2>/dev/null)
fi

#######################################
# Phase 6: Homebrew itself
#######################################

if confirm "Uninstall Homebrew entirely?"; then
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" \
    &>/dev/null &&
    log "Homebrew uninstalled" ||
    log_err "Homebrew uninstall failed"
fi

#######################################
# Phase 7: Dotfiles
#######################################

if confirm "Remove dotfiles from \$HOME?"; then
  if [[ -d "${HOME}/.git" ]]; then
    # Get list of tracked files and remove them
    git -C "${HOME}" ls-files -z 2>/dev/null \
      | xargs -0 -I{} rm -f "${HOME}/{}" 2>/dev/null
    rm -rf "${HOME}/.git"
    log "Removed tracked dotfiles and .git directory"
  else
    log "No .git directory found, skipping"
  fi
fi

log_info "Clean complete"
```

**Step 2: Verify syntax**

Run: `zsh -n clean.sh`

**Step 3: Commit**

```bash
git add clean.sh
git commit -m "feat: add clean.sh for selective bootstrap teardown

Prompts at each stage: LaunchAgents, app prefs, macOS prefs,
casks, formulae, Homebrew, dotfiles. Supports --all flag.
Never removes Xcode CLT or full Xcode."
```

---

### Task 9: Update .gitignore for new files

**Files:**
- Modify: `.gitignore`

**Step 1: Add clean.sh and docs to tracked files**

Add `!clean.sh` and `!docs/` entries to the dotfiles section.

**Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: track clean.sh and docs/ in gitignore"
```

---

### Task 10: Lint all scripts

**Step 1: Run shellcheck on all modified scripts**

Run: `shellcheck -x bootstrap.sh clean.sh lib/zsh/logging.zsh bin/symlink .macos/bootstrap.sh .launchd/bootstrap.sh .cleanshot/bootstrap.sh .coderunner/bootstrap.sh .raycast/bootstrap.sh .rectangle/bootstrap.sh .warp/bootstrap.sh`

**Step 2: Run shfmt on all scripts**

Run: `shfmt -d -i 2 -bn bootstrap.sh clean.sh lib/zsh/logging.zsh bin/symlink`

**Step 3: Fix any issues found and commit**

```bash
git add -A
git commit -m "fix: address shellcheck and shfmt findings"
```
