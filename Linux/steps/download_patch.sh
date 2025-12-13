#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR

# Do not execute this script unless bootstrapped from the main install runner
if [ -z "${_SCRIPT_DIR:-}" ]; then
  exit
fi

if ! type "installer::download::text" &>/dev/null; then
  # shellcheck disable=SC1090
  source "${_SCRIPT_DIR}/../lib/download_shared.sh"
fi

# Ensure required variables exist
if [ -z "${fore[*]:-}" ] \
   || [ -z "${style[*]:-}" ] \
   || [ -z "${INSTALL_DIRECTORY:-}" ] \
   || [ -z "${PATCH_METADATA_URL:-}" ] \
   || [ -z "${INSTALLATION_MODE:-}" ]; then
  exit 1
fi

PATCH_DOWNLOAD_PATH=""

if ! type "installer_step::download_patch::metadata_filter" &>/dev/null; then
  installer_step::download_patch::metadata_filter() {
    echo "-linux-${ARCHITECTURE_TAG}"
  }
fi

installer_step::download_patch() {
  mkdir -p "${INSTALL_DIRECTORY}/Installer"

  PATCH_METADATA_JSON=$(wget "${PATCH_METADATA_URL}" -O - 2>/dev/null || installer::abort_on_error "Unable to fetch patch information from GitHub. Try again later.");

  JQ_FILTER='.assets[] | select(.browser_download_url | ascii_downcase | contains("'$(installer_step::download_patch::metadata_filter)'"))'

  PATCH_DOWNLOAD_URL=$(echo "${PATCH_METADATA_JSON}" | jq -r "[ ${JQ_FILTER} ] | .[0].browser_download_url")

  if [ -z "${PATCH_DOWNLOAD_URL:-}" ]; then
    installer::abort_on_error "Couldn't determine which patch to download. Cannot continue."
  fi

  PATCH_DOWNLOAD_FILENAME="${PATCH_DOWNLOAD_URL##*/}"
  PATCH_DOWNLOAD_FILENAME="${PATCH_DOWNLOAD_FILENAME%%\?*}"
  PATCH_DOWNLOAD_PATH="${INSTALL_DIRECTORY}/Installer/${PATCH_DOWNLOAD_FILENAME}"

  PATCH_DOWNLOAD_SIZE=$(echo "${PATCH_METADATA_JSON}" | jq -r "[ ${JQ_FILTER} ] | .[0].size")

  if [ -f "${PATCH_DOWNLOAD_PATH}" ] && [ -n "${PATCH_DOWNLOAD_SIZE:-}" ]; then
    local EXISTING_FILESIZE
    EXISTING_FILESIZE=$(stat --format=%s "${PATCH_DOWNLOAD_PATH}")

    if [ "${EXISTING_FILESIZE}" -eq "${PATCH_DOWNLOAD_SIZE}" ]; then
      echo "- File ${PATCH_DOWNLOAD_FILENAME} already exists, skipping download." 1>&2
      return
    fi
  fi

  "installer::download::${INSTALLATION_MODE}" "${PATCH_DOWNLOAD_URL}" "${PATCH_DOWNLOAD_PATH}" \
    || installer::abort_on_error "Unable to download ${PATCH_DOWNLOAD_FILENAME}. Cannot continue."
}
