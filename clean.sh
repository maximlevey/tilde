#!/usr/bin/env zsh
# shellcheck shell=bash
#
# Selective reset script that undoes bootstrap.sh changes.
# Prompts at each stage unless --all is passed.
#
# Usage: zsh clean.sh [--all]

# ------------------------------------------------------------------
# Source environment
# ------------------------------------------------------------------

export ZSH_LIB="${HOME}/lib/zsh"

# shellcheck source=./lib/zsh/logging.zsh
source "${ZSH_LIB}/logging.zsh"

# ------------------------------------------------------------------
# Parse arguments
# ------------------------------------------------------------------

SKIP_PROMPTS=false

for arg in "$@"; do
  case "${arg}" in
    --all)
      SKIP_PROMPTS=true
      ;;
    *)
      usage "zsh clean.sh [--all]"
      ;;
  esac
done

# ------------------------------------------------------------------
# confirm() helper
# ------------------------------------------------------------------

#######################################
# Prompt the user for confirmation.
# Returns 0 (yes) or 1 (no). Default is No.
# Skips the prompt and returns 0 when SKIP_PROMPTS is true.
# Globals:
#   SKIP_PROMPTS, _CLR_BLUE, _CLR_RESET, _CLR_BOLD
# Arguments:
#   message - the question to ask
# Returns:
#   0 if confirmed, 1 otherwise
#######################################
confirm() {
  if ${SKIP_PROMPTS}; then return 0; fi
  printf '%s==>%s %s%s [y/N] %s' \
    "${_CLR_BLUE}" "${_CLR_RESET}" "${_CLR_BOLD}" "$1" "${_CLR_RESET}"
  read -r response
  [[ "${response}" =~ ^[Yy] ]]
}

# ------------------------------------------------------------------
# Phase 1: LaunchAgents
# ------------------------------------------------------------------

if confirm "Unload LaunchAgents?"; then
  log_info "Unloading LaunchAgents..."

  for subdir in "${HOME}/.launchd"/*/; do
    [[ -d "${subdir}" ]] || continue

    for plist in "${subdir}"*.plist; do
      [[ -f "${plist}" ]] || continue
      log "Unloading ${plist##*/}..."
      launchctl bootout "gui/$(id -u)" "${plist}" 2>/dev/null ||
        log_warn "Failed to unload ${plist##*/}"
    done
  done
fi

# ------------------------------------------------------------------
# Phase 2: App preferences
# ------------------------------------------------------------------

if confirm "Reset app preferences?"; then
  log_info "Resetting app preferences..."

  readonly APP_DOMAINS=(
    com.getcleanshot.app-setapp
    com.krill.CodeRunner
    com.raycast.macos
    com.knollsoft.Hookshot
    dev.warp.Warp-Stable
  )

  for domain in "${APP_DOMAINS[@]}"; do
    if defaults read "${domain}" &>/dev/null; then
      log "Deleting ${domain}..."
      defaults delete "${domain}" 2>/dev/null ||
        log_warn "Failed to delete ${domain}"
    else
      log "Skipping ${domain} (not set)"
    fi
  done
fi

# ------------------------------------------------------------------
# Phase 3: macOS preferences
# ------------------------------------------------------------------

if confirm "Reset macOS preferences?"; then
  log_info "Resetting macOS preferences..."
  log_warn "This resets entire preference domains"

  readonly MACOS_DOMAINS=(
    com.apple.driver.AppleBluetoothMultitouch.trackpad
    com.apple.AppleMultitouchTrackpad
    com.apple.finder
    com.apple.dock
    com.apple.WindowManager
    com.apple.menuextra.clock
    com.apple.screencapture
    com.apple.desktopservices
    com.apple.DiskUtility
    com.apple.controlcenter
    com.apple.Siri
    com.apple.voicetrigger
    com.apple.Passwords
    com.apple.onetimepasscodes
    com.apple.ncprefs
    com.apple.sharingd
    org.cups.PrintingPrefs
  )

  for domain in "${MACOS_DOMAINS[@]}"; do
    if defaults read "${domain}" &>/dev/null; then
      log "Deleting ${domain}..."
      defaults delete "${domain}" 2>/dev/null ||
        log_warn "Failed to delete ${domain}"
    else
      log "Skipping ${domain} (not set)"
    fi
  done

  log "Restarting Dock, Finder, and SystemUIServer..."
  killall Dock 2>/dev/null || true
  killall Finder 2>/dev/null || true
  killall SystemUIServer 2>/dev/null || true
fi

# ------------------------------------------------------------------
# Phase 4: Homebrew casks
# ------------------------------------------------------------------

if command -v brew &>/dev/null; then
  if confirm "Uninstall Homebrew casks?"; then
    log_info "Uninstalling Homebrew casks..."

    while IFS= read -r cask; do
      [[ -n "${cask}" ]] || continue
      log "Uninstalling cask ${cask}..."
      brew uninstall --cask "${cask}" 2>/dev/null ||
        log_warn "Failed to uninstall cask ${cask}"
    done < <(brew bundle list --cask --file "${HOME}/.brew/Brewfile" 2>/dev/null)
  fi
fi

# ------------------------------------------------------------------
# Phase 5: Homebrew formulae
# ------------------------------------------------------------------

if command -v brew &>/dev/null; then
  if confirm "Uninstall Homebrew formulae?"; then
    log_info "Uninstalling Homebrew formulae..."

    while IFS= read -r formula; do
      [[ -n "${formula}" ]] || continue
      log "Uninstalling formula ${formula}..."
      brew uninstall "${formula}" 2>/dev/null ||
        log_warn "Failed to uninstall formula ${formula}"
    done < <(brew bundle list --formula --file "${HOME}/.brew/Brewfile" 2>/dev/null)
  fi
fi

# ------------------------------------------------------------------
# Phase 6: Homebrew itself
# ------------------------------------------------------------------

if command -v brew &>/dev/null; then
  if confirm "Uninstall Homebrew entirely?"; then
    log_info "Uninstalling Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" 2>/dev/null ||
      log_err "Homebrew uninstall failed"
  fi
fi

# ------------------------------------------------------------------
# Phase 7: Dotfiles
# ------------------------------------------------------------------

if confirm "Remove dotfiles from \$HOME?"; then
  if [[ -d "${HOME}/.git" ]]; then
    log_info "Removing dotfiles..."

    # Capture file list before deleting anything, so logging.zsh
    # removal doesn't affect the running script (functions stay in
    # memory, but we collect the list up-front to be safe).
    _clean_files=()
    while IFS= read -r -d '' file; do
      [[ -n "${file}" ]] || continue
      _clean_files+=("${file}")
    done < <(git -C "${HOME}" ls-files -z 2>/dev/null)

    for file in "${_clean_files[@]}"; do
      log "Removing ${file}..."
      rm -f "${HOME}/${file}"
    done

    log "Removing .git directory..."
    rm -rf "${HOME}/.git"
  else
    log_warn "No .git directory found in \$HOME, skipping dotfiles removal"
  fi
fi

# ------------------------------------------------------------------
# Done
# ------------------------------------------------------------------

log_info "Clean complete"
