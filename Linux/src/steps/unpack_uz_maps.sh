# shellcheck shell=bash

step::unpack_uz_maps() {
  term::step::new "Unpack Maps"

  local KDIALOG_DBUS_ADDRESS=()

  if [[ "${_arg_ui_mode:-none}" == "kdialog" ]]; then
    read -ra KDIALOG_DBUS_ADDRESS < <(kdialog --title "${CURRENT_STEP_NAME}" --progressbar "Unpacking maps..." 0 2>/dev/null)
    busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "showCancelButton" b "false" 2>/dev/null || true
  fi

  helper::progress::make_consistant __step::unpack_uz_maps::run | while IFS= read -r UNPACK_PROGRESS; do
    if [[ -z "${UNPACK_PROGRESS}" ]]; then
      term::step::progress "" >&6

      if [[ "${_arg_ui_mode:-none}" == "kdialog" ]]; then
        busctl --user set-property "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "maximum" i 0 2>/dev/null || true
      fi
      continue
    fi

    local TOTAL_FILES PERCENT CURRENT_FILE_INDEX MAP_NAME

    TOTAL_FILES=$(helper::string::unshift::next_value "${UNPACK_PROGRESS}")
    UNPACK_PROGRESS=$(helper::string::unshift::remainder "${UNPACK_PROGRESS}")

    PERCENT=$(helper::string::unshift::next_value "${UNPACK_PROGRESS}")
    UNPACK_PROGRESS=$(helper::string::unshift::remainder "${UNPACK_PROGRESS}")

    CURRENT_FILE_INDEX=$(helper::string::unshift::next_value "${UNPACK_PROGRESS}")
    UNPACK_PROGRESS=$(helper::string::unshift::remainder "${UNPACK_PROGRESS}")

    MAP_NAME=$(helper::string::unshift::next_value "${UNPACK_PROGRESS}")
    UNPACK_PROGRESS=$(helper::string::unshift::remainder "${UNPACK_PROGRESS}")

    term::step::progress "${CURRENT_FILE_INDEX} of ${TOTAL_FILES} - ${MAP_NAME}" >&6

    local DIALOG_TEXT="Unpacking ${MAP_NAME} (${CURRENT_FILE_INDEX} of ${TOTAL_FILES})"

    if [[ "${_arg_ui_mode:-none}" == "kdialog" ]]; then
      local ESCAPED_DIALOG_TEXT
      ESCAPED_DIALOG_TEXT="$(echo -e "${DIALOG_TEXT}")"
      busctl --user set-property "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "maximum" i "${TOTAL_FILES}" 2>/dev/null || true
      busctl --user set-property "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "value" i "${CURRENT_FILE_INDEX}" 2>/dev/null || true
      busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "setLabelText" s "${ESCAPED_DIALOG_TEXT}" 2>/dev/null || true
    elif [[ "${_arg_ui_mode:-none}" == "zenity" ]]; then
      echo "${PERCENT}"
      echo "# ${DIALOG_TEXT}"
    fi
  done | {
    if [[ "${_arg_ui_mode:-none}" == "zenity" ]]; then
      zenity --progress --percentage=0 --text="Unpacking maps..." --no-cancel --time-remaining --auto-close 2>/dev/null
    else
      cat - >/dev/null
    fi
  } || {
    if [[ "${_arg_ui_mode:-none}" == "kdialog" ]]; then
      busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "close" 2>/dev/null || true
    fi

    term::step::failed_with_error "Failed to unpack all maps. Installation aborted."
    return 1
  }

  if [[ "${_arg_ui_mode:-none}" == "kdialog" ]]; then
    busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "close" 2>/dev/null || true
  fi

  term::step::complete
}

__step::unpack_uz_maps::run() {
  local UCC_BIN_PATH="${_arg_destination%/}/System${UE_SYSTEM_FOLDER_SUFFIX:-}/ucc-bin${ARCHITECTURE_BINARY_SUFFIX}"

  local MAP_FILES=()
  local MAP_FILE

  for MAP_FILE in "${_arg_destination%/}/Maps"/*.unr.uz; do
    if [[ ! -f "${MAP_FILE}" ]]; then
      continue
    fi

    local MAP_BASENAME="${MAP_FILE##*/}"
    MAP_FILES+=("${MAP_BASENAME}")
  done

  local TOTAL_MAP_FILES="${#MAP_FILES[@]}"
  local MAP_FILES_PROCESSED=0

  for MAP_FILE in "${MAP_FILES[@]}"; do
    local MAP_BASENAME_UNCOMPRESSED="${MAP_FILE%.uz}"

    local COMPRESSED_FILE="${_arg_destination%/}/Maps/${MAP_FILE}"
    local DECOMPRESS_STAGING="${_arg_destination%/}/System${UE_SYSTEM_FOLDER_SUFFIX:-}/${MAP_BASENAME_UNCOMPRESSED}"
    local DECOMPRESS_TARGET="${_arg_destination%/}/Maps/${MAP_BASENAME_UNCOMPRESSED}"

    local PERCENT_PROGRESS="$(((MAP_FILES_PROCESSED * 100) / TOTAL_MAP_FILES))"
    MAP_FILES_PROCESSED=$((MAP_FILES_PROCESSED + 1))

    echo "${TOTAL_MAP_FILES}|${PERCENT_PROGRESS}|${MAP_FILES_PROCESSED}|${MAP_BASENAME_UNCOMPRESSED}"

    if [[ -f "${DECOMPRESS_TARGET}" ]]; then
      rm -f "${COMPRESSED_FILE}"
    else
      "${UCC_BIN_PATH}" decompress "../Maps/${MAP_FILE}" -nohomedir &>/dev/null || {
        return 1
      }

      if [[ -f "${DECOMPRESS_STAGING}" ]]; then
        { mv -f "${DECOMPRESS_STAGING}" "${DECOMPRESS_TARGET}" && rm -f "${COMPRESSED_FILE}"; } || {
          return 1
        }
      else
        return 1
      fi
    fi
  done
}
