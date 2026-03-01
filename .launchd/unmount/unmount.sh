#!/usr/bin/env zsh
# shellcheck shell=bash
#
# Safely unmount transient disk-image volumes on macOS.
#
# Targets only volumes backed by disk images (.dmg). Explicitly
# excludes network volumes, external/physical drives, and the
# system volume. Idempotent and safe to run repeatedly.
#
# Flags:
#   --dry-run   Print what would be unmounted without taking action
#   --force     Retry with force unmount if graceful unmount fails

# shellcheck source=../../.tilde/lib/zsh/logging.zsh
source "${ZSH_LIB}/logging.zsh"

readonly SCRIPT_NAME="${0:t}"
readonly EXCLUDED_PROTOCOLS="USB|Thunderbolt|SATA|SAS|Apple Fabric|Secure Digital|FireWire"
readonly EXCLUDED_FSTYPES="smbfs|afpfs|nfs|webdav|cifs"

DRY_RUN=false
FORCE=false

for arg in "$@"; do
  case "${arg}" in
  --dry-run) DRY_RUN=true ;;
  --force) FORCE=true ;;
  *) usage "${SCRIPT_NAME} [--dry-run] [--force]" ;;
  esac
done

unmount_count=0

for mount_point in /Volumes/*(N); do
  [[ -d "${mount_point}" ]] || continue

  vol_name="${mount_point:t}"
  [[ "${vol_name}" == "Macintosh HD"* ]] && continue
  [[ "${mount_point}" == "/" ]] && continue

  dev_node="$(diskutil info "${mount_point}" 2>/dev/null |
    awk -F: '/Device Node/ { gsub(/^[ \t]+/,"",$2); print $2 }')"
  [[ -z "${dev_node}" ]] && continue

  disk_info="$(diskutil info "${dev_node}" 2>/dev/null)"
  [[ -z "${disk_info}" ]] && continue

  protocol="$(printf "%s" "${disk_info}" |
    awk -F: '/Protocol/ { gsub(/^[ \t]+/,"",$2); print $2 }')"
  disk_image_url="$(printf "%s" "${disk_info}" |
    awk -F: '/Disk Image URL/ { gsub(/^[ \t]+/,"",$2); print $2 }')"
  device_location="$(printf "%s" "${disk_info}" |
    awk -F: '/Device Location/ { gsub(/^[ \t]+/,"",$2); print $2 }')"

  is_disk_image=false
  [[ "${protocol}" == "Disk Image" ]] && is_disk_image=true
  [[ -n "${disk_image_url}" ]] && is_disk_image=true
  [[ "${device_location}" == "Virtual" ]] && is_disk_image=true

  [[ "${is_disk_image}" == false ]] && continue

  if [[ -n "${protocol}" ]] &&
    printf "%s" "${protocol}" | grep -qE "${EXCLUDED_PROTOCOLS}"; then
    continue
  fi

  fs_type="$(printf "%s" "${disk_info}" |
    awk -F: '/Type \(Bundle\)/ { gsub(/^[ \t]+/,"",$2); print $2 }')"
  if [[ -n "${fs_type}" ]] &&
    printf "%s" "${fs_type}" | grep -qiE "${EXCLUDED_FSTYPES}"; then
    continue
  fi

  internal="$(printf "%s" "${disk_info}" |
    awk -F: '/Internal/ { gsub(/^[ \t]+/,"",$2); print $2 }')"
  if [[ "${internal}" == "Yes" ]] && [[ "${is_disk_image}" == false ]]; then
    continue
  fi

  if [[ "${DRY_RUN}" == true ]]; then
    log "[dry-run] Would unmount: ${mount_point} (${dev_node})"
    ((unmount_count++))
    continue
  fi

  log "Unmounting: ${mount_point} (${dev_node})"

  if diskutil unmount "${mount_point}" >/dev/null 2>&1; then
    log "Unmounted: ${mount_point}"
    ((unmount_count++))
  else
    if [[ "${FORCE}" == true ]]; then
      log "Graceful unmount failed, retrying with force: ${mount_point}"
      if diskutil unmount force "${mount_point}" >/dev/null 2>&1; then
        log "Force unmounted: ${mount_point}"
        ((unmount_count++))
      else
        log_err "Failed to force unmount: ${mount_point}"
      fi
    else
      log_err "Failed to unmount (volume busy): ${mount_point}"
    fi
  fi
done

if [[ ${unmount_count} -eq 0 ]]; then
  log "No disk-image volumes found to unmount"
elif [[ "${DRY_RUN}" == true ]]; then
  log "[dry-run] ${unmount_count} volume(s) would be unmounted"
else
  log "${unmount_count} volume(s) unmounted"
fi
