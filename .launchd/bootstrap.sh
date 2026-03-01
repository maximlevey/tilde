#!/usr/bin/env zsh
# shellcheck shell=bash
#
# Load LaunchAgents from subdirectories that contain both a
# .plist and .sh file.

# shellcheck source=../.tilde/lib/zsh/logging.zsh
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
  # Unload first for idempotency (ignore error if not loaded).
  launchctl bootout "gui/$(id -u)" "${plist}" 2>/dev/null
  launchctl bootstrap "gui/$(id -u)" "${plist}" 2>/dev/null ||
    log_err "Failed to load ${plist##*/}"
done
