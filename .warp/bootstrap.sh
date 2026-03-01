#!/usr/bin/env zsh
# shellcheck shell=bash
#
# Configures Warp on a new device.

# shellcheck source=../lib/zsh/logging.zsh
source "${ZSH_LIB}/logging.zsh"

readonly APP_NAME="Warp"
readonly BUNDLE_ID="dev.warp.Warp-Stable"
readonly CONFIG_DIR="${HOME}/.warp"

ensure_app "${APP_NAME}" "${BUNDLE_ID}" || exit 0

setprefs "${CONFIG_DIR}/preferences.json"
