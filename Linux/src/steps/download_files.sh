# shellcheck shell=bash

step::download_files() {
  for i in "${!DOWNLOADS_URL_LIST[@]}";
  do
    local DOWNLOAD_URL="${DOWNLOADS_URL_LIST[i]}"
    local DOWNLOAD_FILENAME="${DOWNLOADS_FILENAME_LIST[i]}"
    local DOWNLOAD_SIZE="${DOWNLOADS_SIZE_LIST[i]}"

    DOWNLOAD_PATH="${_arg_destination%/}/Installer/${DOWNLOAD_FILENAME}"

    if [ -f "${DOWNLOAD_PATH}" ] && [ -n "${DOWNLOAD_SIZE:-}" ]; then
      local EXISTING_FILESIZE
      EXISTING_FILESIZE=$(stat --format=%s "${DOWNLOAD_PATH}")

      if [ "${EXISTING_FILESIZE}" -eq "${DOWNLOAD_SIZE}" ]; then
        term::step::new "Download ${DOWNLOAD_FILENAME}"
        term::step::skipped "SKIPPED: File already exists"
        continue
      fi
    fi

    downloader::download_file "${DOWNLOAD_URL}" "${DOWNLOAD_PATH}"
  done
}
