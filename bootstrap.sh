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

echo "==> Requesting administrator privileges..."
sudo -v

# Refresh sudo timestamp in the background until this script exits.
while true; do sudo -n true; sleep 50; done 2>/dev/null &
SUDO_PID=$!

cleanup() {
  kill "${SUDO_PID}" 2>/dev/null
  wait "${SUDO_PID}" 2>/dev/null
}
trap cleanup EXIT

#######################################
# Xcode Command Line Tools
#######################################

if ! xcode-select -p &>/dev/null; then
  echo "==> Installing Xcode Command Line Tools..."

  # Non-interactive install via softwareupdate.
  sudo touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

  clt_package="$(softwareupdate -l 2>/dev/null \
    | grep -o 'Command Line Tools.*' \
    | grep -v 'beta' \
    | sort -V \
    | tail -1)"

  if [[ -n "${clt_package}" ]]; then
    echo "    Installing ${clt_package}..."
    softwareupdate -i "${clt_package}" &>/dev/null
  fi

  sudo rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

  # Fallback to interactive installer if softwareupdate failed.
  if ! xcode-select -p &>/dev/null; then
    echo "    softwareupdate failed, falling back to xcode-select --install..."
    xcode-select --install
    until xcode-select -p &>/dev/null; do
      sleep 5
    done
  fi
else
  echo "==> Xcode Command Line Tools already installed."
fi

sudo xcodebuild -license accept 2>/dev/null || true

#######################################
# Clone / update dotfiles
#######################################

if [[ ! -d "${HOME}/.git" ]]; then
  echo "==> Cloning dotfiles..."
  TMP="$(mktemp -d)"
  readonly TMP
  trap 'cleanup; rm -rf "${TMP}"' EXIT

  git clone --depth 1 "${REPO}" "${TMP}" &>/dev/null
  rsync -ah --exclude '.git' "${TMP}/" "${HOME}/" &>/dev/null
  mv "${TMP}/.git" "${HOME}/.git"
  rm -rf "${TMP}"
  echo "    Dotfiles cloned."
else
  echo "==> Updating dotfiles..."
  if git -C "${HOME}" pull --ff-only &>/dev/null; then
    echo "    Dotfiles updated."
  else
    echo "    Dotfiles pull failed; continuing with local copy."
  fi
fi

#######################################
# Source environment
#######################################

export ZSH_LIB="${HOME}/lib/zsh"
export PATH="${HOME}/bin:${HOME}/.local/bin:${PATH}"

# shellcheck source=./lib/zsh/logging.zsh
source "${ZSH_LIB}/logging.zsh"

#######################################
# Homebrew
#######################################

# Ensure existing Homebrew is on PATH before checking.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

if ! command -v brew &>/dev/null; then
  log_info "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" &>/dev/null

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  log_info "Homebrew already installed."
fi

log "$(brew --version | head -1)"

#######################################
# Homebrew bundle
#######################################

log_info "Installing Homebrew packages..."

if retry 3 run_quiet brew bundle --no-lock --file "${HOME}/.brew/Brewfile"; then
  formulae_count="$(brew list --formula -1 | wc -l | tr -d ' ')"
  cask_count="$(brew list --cask -1 | wc -l | tr -d ' ')"
  log "${formulae_count} formulae, ${cask_count} casks installed."
else
  log_err "brew bundle failed after retries."
fi

# Clear quarantine flags on installed applications.
for app in /Applications/*.app; do
  [[ -e "${app}" ]] || continue
  xattr -dr com.apple.quarantine "${app}" 2>/dev/null || true
done

#######################################
# Setapp
#######################################

if ! command -v setapp-cli &>/dev/null; then
  log_info "Installing setapp-cli..."
  /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/maximlevey/setapp-cli/main/install.sh)" &>/dev/null
  export PATH="${HOME}/.local/bin:${PATH}"

  if ! command -v setapp-cli &>/dev/null; then
    log_warn "setapp-cli installation may have failed; not found on PATH"
  fi
else
  log_info "setapp-cli already installed."
fi

if [[ -f "${HOME}/.setapp/AppList" ]]; then
  log_info "Installing Setapp apps..."
  setapp-cli bundle install --file "${HOME}/.setapp/AppList" 2>/dev/null || true
fi

#######################################
# App-specific bootstrap scripts
#######################################

log_info "Running bootstrap scripts..."

for script in "${HOME}"/.*/"bootstrap.sh"; do
  [[ -f "${script}" ]] || continue
  dir_name="${script%/*}"
  dir_name="${dir_name##*/}"
  dir_name="${dir_name#.}"
  log_info "Running ${dir_name} bootstrap..."
  zsh "${script}"
done

#######################################
# Background Xcode install
#######################################

if [[ ! -d /Applications/Xcode.app ]] && command -v xcodes &>/dev/null; then
  log_info "Starting background Xcode install..."
  log "Progress logged to ~/Desktop/xcode-install.log"
  nohup xcodes install --latest --experimental-unxip \
    > "${HOME}/Desktop/xcode-install.log" 2>&1 &
  disown
fi

#######################################
# Done
#######################################

# Kill sudo keepalive before final message.
kill "${SUDO_PID}" 2>/dev/null
wait "${SUDO_PID}" 2>/dev/null
trap - EXIT

log_info "Bootstrap complete."
