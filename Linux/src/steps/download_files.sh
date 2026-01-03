# shellcheck shell=bash

step::download_files() {
  local DOWNLOAD_SOURCE_KEY

  for DOWNLOAD_SOURCE_KEY in "${!DOWNLOADS_SOURCE_LIST[@]}"; do
    local DOWNLOAD_URL_SETS="${DOWNLOADS_SOURCE_LIST[${DOWNLOAD_SOURCE_KEY}]}"
    local DOWNLOAD_FILENAME="${DOWNLOADS_FILENAME_LIST[${DOWNLOAD_SOURCE_KEY}]}"
    local IS_DOWNLOAD_SKIPPED="no"

    DOWNLOAD_PATH="${_arg_destination%/}/Installer/${DOWNLOAD_FILENAME}"

    local TARGET_STEP_NAME="Download ${DOWNLOAD_FILENAME}"

    # If the file exist and isn't a partial download
    if [[ -f "${DOWNLOAD_PATH}" ]] && [[ ! -f "${DOWNLOAD_PATH}.aria2" ]]; then
      term::step::new "${TARGET_STEP_NAME}"

      local EXISTING_FILESIZE EXISTING_HASH
      EXISTING_FILESIZE=$(stat --format=%s "${DOWNLOAD_PATH}")
      EXISTING_HASH=$(helper::progress::run_with_progress "Verifying existing file" downloader::compute_sha256sum "${DOWNLOAD_PATH}")

      local REMAINING_DOWNLOAD_URL_SETS="${DOWNLOAD_URL_SETS}"
      while true; do
        # We looped through all the possible values, we can break out
        if [[ -z "${REMAINING_DOWNLOAD_URL_SETS}" ]]; then
          break
        fi

        CURRENT_DOWNLOAD_URL_SET=$(helper::string::unshift::next_value "${REMAINING_DOWNLOAD_URL_SETS}" ";;")
        REMAINING_DOWNLOAD_URL_SETS=$(helper::string::unshift::remainder "${REMAINING_DOWNLOAD_URL_SETS}" ";;")

        local DOWNLOAD_URL DOWNLOAD_SIZE DOWNLOAD_HASH

        DOWNLOAD_URL=$(helper::string::unshift::next_value "${CURRENT_DOWNLOAD_URL_SET}")
        CURRENT_DOWNLOAD_URL_SET=$(helper::string::unshift::remainder "${CURRENT_DOWNLOAD_URL_SET}")

        DOWNLOAD_SIZE=$(helper::string::unshift::next_value "${CURRENT_DOWNLOAD_URL_SET}")
        CURRENT_DOWNLOAD_URL_SET=$(helper::string::unshift::remainder "${CURRENT_DOWNLOAD_URL_SET}")

        DOWNLOAD_HASH=$(helper::string::unshift::next_value "${CURRENT_DOWNLOAD_URL_SET}")

        if [[ -n "${DOWNLOAD_SIZE}" ]] && [[ "${EXISTING_FILESIZE}" -ne "${DOWNLOAD_SIZE}" ]]; then
          continue
        fi

        if [[ -n "${DOWNLOAD_HASH}" ]] && [[ "${EXISTING_HASH}" != "${DOWNLOAD_HASH}" ]]; then
          continue
        fi

        IS_DOWNLOAD_SKIPPED="yes"
        break
      done
    fi

    if [[ "${IS_DOWNLOAD_SKIPPED}" == "yes" ]]; then
      term::step::skipped "SKIPPED: File already exists"
      continue
    fi

    downloader::download_file "${DOWNLOAD_URL_SETS}" "${DOWNLOAD_PATH}"
  done
}
