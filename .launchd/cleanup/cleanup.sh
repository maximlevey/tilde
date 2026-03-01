#!/usr/bin/env zsh
# shellcheck shell=bash
#
# Organize ~/Downloads by month and file type. Items older than
# 30 days are sorted into YYYY-MM/<Category>/ folders based on
# Spotlight UTI content types. Supports --dry-run.

#TODO: Add functionality running script on iCloud downloads
#TODO: Add functionality for offloading older items to iCloud downloads

# shellcheck source=../../.tilde/lib/zsh/logging.zsh
source "${ZSH_LIB}/logging.zsh"

# ─── Constants ────────────────────────────────────────────────────────────────

readonly DOWNLOADS_DIR="${HOME}/Downloads"
readonly AGE_THRESHOLD=30
readonly MONTH_PATTERN="^[0-9]{4}-(0[1-9]|1[0-2])$"

# ─── Helpers ──────────────────────────────────────────────────────────────────

# Execute or simulate a command based on dry-run mode.
run() {
  if [[ "${DRY_RUN}" == true ]]; then
    log "[dry-run] $*"
  else
    "$@"
  fi
}

# Get the date an item was added to Downloads (falls back to creation date).
# Arguments:
#   $1 - path to the item
# Outputs:
#   Writes date string to stdout
get_item_date() {
  local item="$1"
  local date_added
  date_added="$(mdls -name kMDItemDateAdded -raw "${item}" 2>/dev/null)"
  if [[ -z "${date_added}" || "${date_added}" == "(null)" ]]; then
    date_added="$(mdls -name kMDItemContentCreationDate -raw "${item}" 2>/dev/null)"
  fi
  if [[ -z "${date_added}" || "${date_added}" == "(null)" ]]; then
    date_added="$(stat -f '%SB' -t '%Y-%m-%d %H:%M:%S %z' "${item}" 2>/dev/null)"
  fi
  printf "%s" "${date_added}"
}

# Extract YYYY-MM from a date string.
# Arguments:
#   $1 - date string
# Outputs:
#   Writes YYYY-MM to stdout
get_month_folder() {
  local date_str="$1"
  local yyyy_mm
  yyyy_mm="$(printf "%s" "${date_str}" | /usr/bin/sed -E 's/^([0-9]{4}-[0-9]{2}).*/\1/')"
  printf "%s" "${yyyy_mm}"
}

# Check whether an item is older than AGE_THRESHOLD days.
# Arguments:
#   $1 - path to the item
# Returns:
#   0 if old enough, 1 otherwise
is_old_enough() {
  local item="$1"
  local date_str
  date_str="$(get_item_date "${item}")"
  if [[ -z "${date_str}" || "${date_str}" == "(null)" ]]; then
    return 1
  fi
  local item_epoch
  item_epoch="$(/bin/date -j -f '%Y-%m-%d %H:%M:%S %z' "${date_str}" '+%s' 2>/dev/null)"
  if [[ -z "${item_epoch}" ]]; then
    item_epoch="$(/bin/date -j -f '%Y-%m-%d %H:%M:%S +0000' "${date_str}" '+%s' 2>/dev/null)"
  fi
  if [[ -z "${item_epoch}" ]]; then
    return 1
  fi
  local now_epoch
  now_epoch="$(/bin/date '+%s')"
  local age_seconds=$((now_epoch - item_epoch))
  local threshold_seconds=$((AGE_THRESHOLD * 86400))
  [[ ${age_seconds} -ge ${threshold_seconds} ]]
}

# Determine category from Spotlight UTI content type tree.
# Arguments:
#   $1 - path to the item
# Outputs:
#   Writes category name to stdout
get_category() {
  local item="$1"

  if [[ -d "${item}" ]]; then
    printf "Directories"
    return
  fi

  local uti_tree
  uti_tree="$(mdls -name kMDItemContentTypeTree -raw "${item}" 2>/dev/null)"

  # Order matters: first match wins
  if [[ "${uti_tree}" == *"com.apple.application-bundle"* ]]; then
    printf "Applications"
    return
  fi

  if [[ "${uti_tree}" == *"com.apple.installer-package"* ]] ||
    [[ "${uti_tree}" == *"com.apple.installer-meta-package"* ]] ||
    [[ "${uti_tree}" == *"com.apple.disk-image"* ]] ||
    [[ "${uti_tree}" == *"com.apple.disk-image-udif"* ]] ||
    [[ "${uti_tree}" == *"com.apple.disk-image-ndif"* ]] ||
    [[ "${uti_tree}" == *"com.apple.disk-image-cdr"* ]]; then
    printf "Installers"
    return
  fi

  if [[ "${uti_tree}" == *"public.executable"* ]] ||
    [[ "${uti_tree}" == *"public.unix-executable"* ]]; then
    printf "Executables"
    return
  fi

  if [[ "${uti_tree}" == *"public.shell-script"* ]] ||
    [[ "${uti_tree}" == *"public.zsh-script"* ]] ||
    [[ "${uti_tree}" == *"public.bash-script"* ]] ||
    [[ "${uti_tree}" == *"public.csh-script"* ]] ||
    [[ "${uti_tree}" == *"public.ksh-script"* ]] ||
    [[ "${uti_tree}" == *"public.perl-script"* ]] ||
    [[ "${uti_tree}" == *"public.python-script"* ]] ||
    [[ "${uti_tree}" == *"public.ruby-script"* ]] ||
    [[ "${uti_tree}" == *"public.php-script"* ]] ||
    [[ "${uti_tree}" == *"com.apple.applescript"* ]] ||
    [[ "${uti_tree}" == *"com.netscape.javascript-source"* ]]; then
    printf "Scripts"
    return
  fi

  if [[ "${uti_tree}" == *"public.archive"* ]] ||
    [[ "${uti_tree}" == *"com.pkware.zip-archive"* ]] ||
    [[ "${uti_tree}" == *"org.gnu.gnu-tar-archive"* ]] ||
    [[ "${uti_tree}" == *"org.gnu.gnu-zip-archive"* ]] ||
    [[ "${uti_tree}" == *"public.tar-archive"* ]] ||
    [[ "${uti_tree}" == *"com.rarlab.rar-archive"* ]] ||
    [[ "${uti_tree}" == *"org.7-zip.7-zip-archive"* ]] ||
    [[ "${uti_tree}" == *"org.tukaani.xz-archive"* ]] ||
    [[ "${uti_tree}" == *"com.apple.bom-compressed-cpio"* ]] ||
    [[ "${uti_tree}" == *"com.apple.xar-archive"* ]] ||
    [[ "${uti_tree}" == *"public.zip-archive"* ]] ||
    [[ "${uti_tree}" == *"com.sun.java-archive"* ]]; then
    printf "Archives"
    return
  fi

  if [[ "${uti_tree}" == *"public.image"* ]]; then
    printf "Images"
    return
  fi

  if [[ "${uti_tree}" == *"public.audio"* ]]; then
    printf "Audio"
    return
  fi

  if [[ "${uti_tree}" == *"public.video"* ]] ||
    [[ "${uti_tree}" == *"public.movie"* ]]; then
    printf "Video"
    return
  fi

  if [[ "${uti_tree}" == *"com.adobe.pdf"* ]] ||
    [[ "${uti_tree}" == *"org.openxmlformats.wordprocessingml.document"* ]] ||
    [[ "${uti_tree}" == *"org.openxmlformats.spreadsheetml.sheet"* ]] ||
    [[ "${uti_tree}" == *"org.openxmlformats.presentationml.presentation"* ]] ||
    [[ "${uti_tree}" == *"com.microsoft.word.doc"* ]] ||
    [[ "${uti_tree}" == *"com.microsoft.excel.xls"* ]] ||
    [[ "${uti_tree}" == *"com.microsoft.powerpoint.ppt"* ]] ||
    [[ "${uti_tree}" == *"org.oasis-open.opendocument"* ]] ||
    [[ "${uti_tree}" == *"com.apple.iwork"* ]] ||
    [[ "${uti_tree}" == *"com.apple.keynote"* ]] ||
    [[ "${uti_tree}" == *"com.apple.numbers"* ]] ||
    [[ "${uti_tree}" == *"com.apple.pages"* ]] ||
    [[ "${uti_tree}" == *"public.rtf"* ]] ||
    [[ "${uti_tree}" == *"com.apple.rtfd"* ]] ||
    [[ "${uti_tree}" == *"com.apple.flat-rtfd"* ]] ||
    [[ "${uti_tree}" == *"public.composite-content"* ]] ||
    [[ "${uti_tree}" == *"com.microsoft.word.wordml"* ]]; then
    printf "Documents"
    return
  fi

  if [[ "${uti_tree}" == *"public.html"* ]]; then
    printf "HTML"
    return
  fi

  if [[ "${uti_tree}" == *"public.comma-separated-values-text"* ]]; then
    printf "CSV"
    return
  fi

  if [[ "${uti_tree}" == *"public.json"* ]]; then
    printf "JSON"
    return
  fi

  if [[ "${uti_tree}" == *"public.xml"* ]] ||
    [[ "${uti_tree}" == *"com.apple.property-list"* ]] ||
    [[ "${uti_tree}" == *"com.apple.xml-property-list"* ]]; then
    printf "XML"
    return
  fi

  if [[ "${uti_tree}" == *"public.font"* ]] ||
    [[ "${uti_tree}" == *"public.opentype-font"* ]] ||
    [[ "${uti_tree}" == *"public.truetype-font"* ]] ||
    [[ "${uti_tree}" == *"com.apple.font-suitcase"* ]] ||
    [[ "${uti_tree}" == *"public.truetype-collection-font"* ]]; then
    printf "Fonts"
    return
  fi

  if [[ "${uti_tree}" == *"public.plain-text"* ]] ||
    [[ "${uti_tree}" == *"public.utf8-plain-text"* ]] ||
    [[ "${uti_tree}" == *"public.utf16-plain-text"* ]] ||
    [[ "${uti_tree}" == *"public.text"* ]] ||
    [[ "${uti_tree}" == *"public.source-code"* ]]; then
    printf "Text"
    return
  fi

  printf "Other"
}

# Safely move an item, skipping if destination already exists.
# Arguments:
#   $1 - source path
#   $2 - destination directory
safe_move() {
  local src="$1"
  local dest_dir="$2"
  local item_basename
  item_basename="$(/usr/bin/basename "${src}")"
  local dest="${dest_dir}/${item_basename}"

  if [[ -e "${dest}" ]]; then
    log "Skipping '${item_basename}' — already exists at '${dest}'"
    return 0
  fi

  run /bin/mkdir -p "${dest_dir}"
  run /bin/mv "${src}" "${dest}"
  log "Moved '${item_basename}' → '${dest_dir}/'"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
  local dry_run=false
  if [[ "$1" == "--dry-run" ]]; then
    dry_run=true
    log "Dry-run mode enabled — no files will be moved"
  fi
  DRY_RUN="${dry_run}"

  if [[ ! -d "${DOWNLOADS_DIR}" ]]; then
    log_err "Downloads directory not found: ${DOWNLOADS_DIR}"
    exit 1
  fi

  log "Starting Downloads cleanup (threshold: ${AGE_THRESHOLD} days)"

  for item in "${DOWNLOADS_DIR}"/*; do
    [[ -e "${item}" ]] || continue

    local name
    name="$(/usr/bin/basename "${item}")"

    [[ "${name}" == .* ]] && continue

    if [[ "${name}" =~ ${MONTH_PATTERN} ]]; then
      continue
    fi

    if ! is_old_enough "${item}"; then
      log "Skipping '${name}' — newer than ${AGE_THRESHOLD} days"
      continue
    fi

    local date_str
    date_str="$(get_item_date "${item}")"
    local month_folder
    month_folder="$(get_month_folder "${date_str}")"

    if [[ -z "${month_folder}" || ! "${month_folder}" =~ ${MONTH_PATTERN} ]]; then
      log_err "Could not determine month for '${name}' — skipping"
      continue
    fi

    local month_dir="${DOWNLOADS_DIR}/${month_folder}"

    if [[ -d "${item}" ]]; then
      safe_move "${item}" "${month_dir}/Directories"
      continue
    fi

    local category
    category="$(get_category "${item}")"
    safe_move "${item}" "${month_dir}/${category}"
  done

  log "Downloads cleanup complete"
}

main "$@"
