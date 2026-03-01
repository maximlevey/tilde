#!/usr/bin/env zsh
# shellcheck shell=bash
#
# Configures Rectangle Pro on a new device.

# shellcheck source=../.tilde/lib/zsh/logging.zsh
source "${ZSH_LIB}/logging.zsh"

readonly APP_NAME="Rectangle Pro"
readonly BUNDLE_ID="com.knollsoft.Hookshot"
readonly CONFIG_DIR="${HOME}/.rectangle"

ensure_app "${APP_NAME}" "${BUNDLE_ID}" || exit 0

setprefs "${CONFIG_DIR}/preferences.json"
