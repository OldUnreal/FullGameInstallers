# shellcheck shell=bash

step::unarchive_generic() {
  local ITEM_NAME="${1:-}"
  local ARCHIVE_PATH="${2:-}"
  local TARGET_PATH="${3:-}"
  local IGNORE_PATTERNS_VAR_NAME="${4:-}"
  local IGNORE_PATTERNS_RECURSIVE_VAR_NAME="${5:-}"

  if [ -z "${ITEM_NAME}" ] || [ -z "${ARCHIVE_PATH}" ] || [ -z "${TARGET_PATH}" ]; then
    return 1
  fi

  if [ ! -d "${TARGET_PATH}" ]; then
    # Create the installation folder
    mkdir -p "${TARGET_PATH}" &>/dev/null || { 
      term::step::failed_with_error "User does not have permission to create staging folder. Aborting installation."
      return 77 #E_PERM
    }
  fi

  unarchiver::unarchive_file "${ITEM_NAME}" "${ARCHIVE_PATH}" "${TARGET_PATH}" "${IGNORE_PATTERNS_VAR_NAME}" "${IGNORE_PATTERNS_RECURSIVE_VAR_NAME}"
}
