# shellcheck shell=bash
#
# Shared logging, retry, and helper functions for shell scripts.
# Output format follows setapp-cli Printer.swift conventions:
#   ==>  bold blue arrow + bold white text  (section headers)
#        4-space indented plain text         (detail lines)
#   Warning:  yellow prefix                  (warnings)
#   Error:    red prefix, stderr             (errors)
#
# TTY-aware: colour codes are emitted only when stdout is a terminal.

# Guard against double-sourcing: skip colour setup if already defined.
if [[ -z "${_LOGGING_LOADED:-}" ]]; then
  typeset -g _LOGGING_LOADED=1

  # ------------------------------------------------------------------
  # Colour constants (TTY-aware)
  # ------------------------------------------------------------------
  if [[ -t 1 ]]; then
    typeset -g _CLR_BOLD=$'\033[1m'
    typeset -g _CLR_BLUE=$'\033[1;34m'
    typeset -g _CLR_WHITE=$'\033[1;37m'
    typeset -g _CLR_YELLOW=$'\033[0;33m'
    typeset -g _CLR_RED=$'\033[0;31m'
    typeset -g _CLR_RESET=$'\033[0m'
  else
    typeset -g _CLR_BOLD=""
    typeset -g _CLR_BLUE=""
    typeset -g _CLR_WHITE=""
    typeset -g _CLR_YELLOW=""
    typeset -g _CLR_RED=""
    typeset -g _CLR_RESET=""
  fi
fi

#######################################
# Print a section-header line.
# Mimics setapp-cli: bold blue "==>" + bold white message.
# Globals:
#   _CLR_BLUE, _CLR_WHITE, _CLR_RESET
# Arguments:
#   message - the text to display
# Outputs:
#   Writes formatted line to stdout
#######################################
log_info() {
  printf '%s==>%s %s%s%s\n' \
    "${_CLR_BLUE}" "${_CLR_RESET}" \
    "${_CLR_WHITE}${_CLR_BOLD}" "$1" "${_CLR_RESET}"
}

#######################################
# Print a detail line (4-space indent, plain text).
# Globals:
#   None
# Arguments:
#   message - the text to display
# Outputs:
#   Writes indented line to stdout
#######################################
log() {
  printf '    %s\n' "$1"
}

#######################################
# Print a warning with yellow "Warning:" prefix.
# Globals:
#   _CLR_YELLOW, _CLR_RESET
# Arguments:
#   message - the text to display
# Outputs:
#   Writes warning to stdout
#######################################
log_warn() {
  printf '%sWarning:%s %s\n' \
    "${_CLR_YELLOW}" "${_CLR_RESET}" "$1"
}

#######################################
# Print an error with red "Error:" prefix to stderr.
# Globals:
#   _CLR_RED, _CLR_RESET
# Arguments:
#   message - the text to display
# Outputs:
#   Writes error to stderr
#######################################
log_err() {
  printf '%sError:%s %s\n' \
    "${_CLR_RED}" "${_CLR_RESET}" "$1" >&2
}

#######################################
# Print usage string and exit.
# Arguments:
#   usage_string - the usage pattern to display
# Outputs:
#   Writes "Usage: <string>" to stderr
#######################################
usage() {
  printf 'Usage: %s\n' "$1" >&2
  exit 9
}

# ====================================================================
# Helper functions
# ====================================================================

#######################################
# Run a command quietly; on failure print captured stderr.
# Arguments:
#   cmd... - the command and its arguments
# Returns:
#   The exit code of the wrapped command
#######################################
run_quiet() {
  local _rq_stderr _rq_rc
  _rq_stderr="$(mktemp)"

  if "$@" >/dev/null 2>"${_rq_stderr}"; then
    _rq_rc=0
  else
    _rq_rc=$?
    log_err "Command failed: $*"
    while IFS= read -r _rq_line; do
      log "  ${_rq_line}"
    done < "${_rq_stderr}"
  fi

  rm -f "${_rq_stderr}"
  return "${_rq_rc}"
}

#######################################
# Retry a command up to n times with a 5-second delay between attempts.
# Arguments:
#   n   - maximum number of attempts
#   cmd... - the command and its arguments
# Returns:
#   0 on success, last exit code on exhaustion
#######################################
retry() {
  local _rt_max="$1"; shift
  local _rt_attempt=1 _rt_rc=0

  while (( _rt_attempt <= _rt_max )); do
    if "$@"; then
      return 0
    else
      _rt_rc=$?
      if (( _rt_attempt < _rt_max )); then
        log_warn "Attempt ${_rt_attempt}/${_rt_max} failed, retrying in 5s..."
        sleep 5
      fi
    fi
    (( _rt_attempt++ ))
  done

  log_err "Command failed after ${_rt_max} attempts: $*"
  return "${_rt_rc}"
}

#######################################
# Ensure a macOS app has been launched at least once so its plist
# exists. Opens the app, polls for the plist for up to 10 seconds,
# then quits the app.
# Arguments:
#   app_name  - human-readable name (e.g. "Bartender 4")
#   bundle_id - CFBundleIdentifier (e.g. "com.surteesstudios.Bartender")
# Returns:
#   0 if plist found, 1 on timeout
#######################################
ensure_app() {
  local _ea_app_name="$1"
  local _ea_bundle_id="$2"
  local _ea_plist="${HOME}/Library/Preferences/${_ea_bundle_id}.plist"
  local _ea_waited=0

  if [[ -f "${_ea_plist}" ]]; then
    return 0
  fi

  log "Opening ${_ea_app_name} to generate preferences..."
  if ! open -a "${_ea_app_name}" 2>/dev/null; then
    log_warn "${_ea_app_name} is not installed, skipping preferences"
    return 1
  fi

  while (( _ea_waited < 30 )); do
    if [[ -f "${_ea_plist}" ]]; then
      log "${_ea_app_name} preferences created."
      osascript -e "quit app \"${_ea_app_name}\"" 2>/dev/null
      return 0
    fi
    sleep 1
    (( _ea_waited++ ))
  done

  osascript -e "quit app \"${_ea_app_name}\"" 2>/dev/null
  log_warn "Timed out waiting for ${_ea_app_name} preferences."
  return 1
}
