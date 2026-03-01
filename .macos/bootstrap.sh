#!/usr/bin/env zsh
# shellcheck shell=bash
#
# Set macOS system preferences.

# shellcheck source=../lib/zsh/logging.zsh
source "${ZSH_LIB}/logging.zsh"

osascript -e "quit app \"System Preferences\"" 2>/dev/null || true
osascript -e "quit app \"System Settings\"" 2>/dev/null || true

setprefs "$(dirname "${0}")/preferences.json"

log "Clearing Dock..."
defaults write com.apple.dock persistent-apps -array
defaults write com.apple.dock persistent-others -array

chflags nohidden "${HOME}/Library"

log "Restarting affected services..."
killall ControlCenter 2>/dev/null || true
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true
