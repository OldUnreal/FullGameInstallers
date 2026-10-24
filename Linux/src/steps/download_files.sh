# shellcheck shell=bash

step::download_files() {
  local DOWNLOAD_SOURCE_KEY

  for DOWNLOAD_SOURCE_KEY in "${!DOWNLOADS_SOURCE_LIST[@]}"; do
    local DOWNLOAD_URL_SETS="${DOWNLOADS_SOURCE_LIST[${DOWNLOAD_SOURCE_KEY}]}"
    local DOWNLOAD_FILENAME="${DOWNLOADS_FILENAME_LIST[${DOWNLOAD_SOURCE_KEY}]}"
    local IS_DOWNLOAD_SKIPPED="no"

    local DOWNLOAD_PATH="${_arg_destination%/}/Installer/${DOWNLOAD_FILENAME}"

    local TARGET_STEP_NAME="Download ${DOWNLOAD_FILENAME}"

    # Allow for the .iso and patch files to be alongside the script
    local POSSIBLE_EXISTING_FILES_TO_CHECK=(
      "${DOWNLOAD_PATH}"
      "${_SCRIPT_DIR}/${DOWNLOAD_FILENAME}"
    )

    term::step::new "${TARGET_STEP_NAME}"

    local POSSIBLE_EXISTING_FILE
    for POSSIBLE_EXISTING_FILE in "${POSSIBLE_EXISTING_FILES_TO_CHECK[@]}"; do
      # If the file exist and isn't a partial download
      if [[ -f "${POSSIBLE_EXISTING_FILE}" ]] && [[ ! -f "${POSSIBLE_EXISTING_FILE}.aria2" ]]; then
        local EXISTING_FILESIZE EXISTING_HASH
        EXISTING_FILESIZE=$(stat --format=%s "${POSSIBLE_EXISTING_FILE}")
        EXISTING_HASH=$(helper::progress::run_with_progress "Verifying existing file" downloader::compute_sha256sum "${POSSIBLE_EXISTING_FILE}")

        local SET_INDEX=0
        local CURRENT_DOWNLOAD_URL_SET
        while true; do
          SET_INDEX=$((SET_INDEX + 1))
          CURRENT_DOWNLOAD_URL_SET=$(helper::string::field "${DOWNLOAD_URL_SETS}" "${SET_INDEX}" ";;")

          # We looped through all the possible values, we can break out
          if [[ -z "${CURRENT_DOWNLOAD_URL_SET}" ]]; then
            break
          fi

          local DOWNLOAD_SIZE DOWNLOAD_HASH

          # Archive sources describe the extracted file in their member fields
          if [[ -n "$(helper::string::field "${CURRENT_DOWNLOAD_URL_SET}" 4)" ]]; then
            DOWNLOAD_SIZE=$(helper::string::field "${CURRENT_DOWNLOAD_URL_SET}" 5)
            DOWNLOAD_HASH=$(helper::string::field "${CURRENT_DOWNLOAD_URL_SET}" 6)
          else
            DOWNLOAD_SIZE=$(helper::string::field "${CURRENT_DOWNLOAD_URL_SET}" 2)
            DOWNLOAD_HASH=$(helper::string::field "${CURRENT_DOWNLOAD_URL_SET}" 3)
          fi

          if [[ -n "${DOWNLOAD_SIZE}" ]] && [[ "${EXISTING_FILESIZE}" -ne "${DOWNLOAD_SIZE}" ]]; then
            continue
          fi

          if [[ -n "${DOWNLOAD_HASH}" ]] && [[ "${EXISTING_HASH}" != "${DOWNLOAD_HASH}" ]]; then
            continue
          fi

          IS_DOWNLOAD_SKIPPED="yes"
          break
        done

        if [[ "${IS_DOWNLOAD_SKIPPED}" == "yes" ]]; then
          if [[ "${POSSIBLE_EXISTING_FILE}" != "${DOWNLOAD_PATH}" ]]; then
            ln -fs "${POSSIBLE_EXISTING_FILE}" "${DOWNLOAD_PATH}"
          fi
          break
        fi
      fi
    done

    if [[ "${IS_DOWNLOAD_SKIPPED}" == "yes" ]]; then
      term::step::skipped "SKIPPED: File already exists"
      continue
    fi

    downloader::download_file "${DOWNLOAD_URL_SETS}" "${DOWNLOAD_PATH}" || {
      echo
      term::error_with_dialog "Failed to download ${DOWNLOAD_FILENAME} from all available sources. Installation aborted."
      return 1
    }
  done
}
