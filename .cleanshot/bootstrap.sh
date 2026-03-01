#!/usr/bin/env zsh
# shellcheck shell=bash
#
# Configures CleanShot X on a new device.

# shellcheck source=../.tilde/lib/zsh/logging.zsh
source "${ZSH_LIB}/logging.zsh"

readonly APP_NAME="CleanShot X"
readonly BUNDLE_ID="com.getcleanshot.app-setapp"
readonly CONFIG_DIR="${HOME}/.cleanshot"

ensure_app "${APP_NAME}" "${BUNDLE_ID}" || exit 0

setprefs "${CONFIG_DIR}/preferences.json"
