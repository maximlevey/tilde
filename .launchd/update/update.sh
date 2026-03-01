#!/usr/bin/env zsh
# shellcheck shell=bash
#
# Update, upgrade, and clean up Homebrew packages.

# shellcheck source=../../.tilde/lib/zsh/logging.zsh
source "${ZSH_LIB}/logging.zsh"

if ! command -v brew &>/dev/null; then
  log_err "Homebrew is not installed"
  exit 3
fi

log "Updating Homebrew..."
brew update

log "Upgrading casks..."
brew upgrade --cask

log "Cleaning up..."
brew cleanup
