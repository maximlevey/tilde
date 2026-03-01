#!/usr/bin/env zsh
# shellcheck shell=bash
#
# Configures CodeRunner on a new device.

# shellcheck source=../lib/zsh/logging.zsh
source "${ZSH_LIB}/logging.zsh"

readonly APP_NAME="CodeRunner"
readonly BUNDLE_ID="com.krill.CodeRunner"
readonly CONFIG_DIR="${HOME}/.coderunner"

ensure_app "${APP_NAME}" "${BUNDLE_ID}" || exit 0

log "Creating symlinks..."
symlink "${CONFIG_DIR}/themes" "${HOME}/Library/Application Support/CodeRunner/Themes"
symlink "${CONFIG_DIR}/languages" "${HOME}/Library/Application Support/CodeRunner/Languages"

setprefs "${CONFIG_DIR}/preferences.json"
