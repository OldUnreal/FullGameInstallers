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
   || [ -z "${DOWNLOADS_URL_LIST:-}" ] \
   || [ -z "${DOWNLOADS_FILENAME_LIST:-}" ] \
   || [ -z "${DOWNLOADS_SIZE_LIST:-}" ] \
   || [ -z "${INSTALLATION_MODE:-}" ]; then
  exit 1
fi

installer_step::download() {
  mkdir -p "${INSTALL_DIRECTORY}/Installer"

  for i in "${!DOWNLOADS_URL_LIST[@]}";
  do 
    DOWNLOAD_URL="${DOWNLOADS_URL_LIST[i]}"
    DOWNLOAD_FILENAME="${DOWNLOADS_FILENAME_LIST[i]}"
    DOWNLOAD_SIZE="${DOWNLOADS_SIZE_LIST[i]}"

    DOWNLOAD_PATH="${INSTALL_DIRECTORY}/Installer/${DOWNLOAD_FILENAME}"

    if [ -f "${DOWNLOAD_PATH}" ] && [ -n "${DOWNLOAD_SIZE:-}" ]; then
      local EXISTING_FILESIZE
      EXISTING_FILESIZE=$(stat --format=%s "${DOWNLOAD_PATH}")

      if [ "${EXISTING_FILESIZE}" -eq "${DOWNLOAD_SIZE}" ]; then
        echo "- File ${DOWNLOAD_FILENAME} already exists, skipping download." 1>&2
        continue
      fi
    fi

    installer_step::download::do_download "${DOWNLOAD_URL}" "${DOWNLOAD_FILENAME}" "${DOWNLOAD_PATH}"
  done
}

installer_step::download::do_download() {
  if [ -z "${1:-}" ]; then
    installer::abort_on_error "Unable to download ${2:-file}. Cannot continue."
    return 1
  fi

  DOWNLOAD_URL_WITHOUT_FALLBACKS="${1%%"||"*}"
  REMAINING_FALLBACKS="${1#*"||"}"

  if [ "${DOWNLOAD_URL_WITHOUT_FALLBACKS}" == "${REMAINING_FALLBACKS}" ]; then
    REMAINING_FALLBACKS=""
  fi

  "installer::download::${INSTALLATION_MODE}" "${DOWNLOAD_URL_WITHOUT_FALLBACKS}" "${3}" "${4:-}" || installer_step::download::do_download "${REMAINING_FALLBACKS}" "${2}" "${3}" "${4:-retry}"
}
