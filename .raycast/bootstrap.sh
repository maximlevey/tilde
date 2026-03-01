#!/usr/bin/env zsh
# shellcheck shell=bash
#
# Configures Raycast on a new device.

# shellcheck source=../.tilde/lib/zsh/logging.zsh
source "${ZSH_LIB}/logging.zsh"

readonly APP_NAME="Raycast"
readonly BUNDLE_ID="com.raycast.macos"
readonly CONFIG_DIR="${HOME}/.raycast"

ensure_app "${APP_NAME}" "${BUNDLE_ID}" || exit 0

log "Creating symlinks..."
symlink "${CONFIG_DIR}" "${HOME}/.config/raycast"

setprefs "${CONFIG_DIR}/preferences.json"
