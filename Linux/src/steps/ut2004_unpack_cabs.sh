# shellcheck shell=bash

step::ut2004_unpack_cabs() {
  term::step::new "Unpack Install CABs"

  local STAGING_PATH="${_arg_destination%/}/Installer/.staging"
  local CABS_PATH="${STAGING_PATH}/Cabs"
  local TARGET_PATH="${STAGING_PATH}/Data"

  if [[ -d "${CABS_PATH}" ]]; then
    rm -rf "${CABS_PATH}" &>/dev/null || {
      term::step::failed_with_error "User does not have permission to create staging folder. Aborting installation."
      return 77 #E_PERM
    }
  fi

  # Create the cabs folder
  mkdir -p "${CABS_PATH}" &>/dev/null || {
    term::step::failed_with_error "User does not have permission to create staging folder. Aborting installation."
    return 77 #E_PERM
  }

  {
    local DISK_FOLDER
    for DISK_FOLDER in "${STAGING_PATH}"/Disk*; do
      if [[ ! -d "${DISK_FOLDER}" ]]; then
        continue
      fi

      local DISK_CAB
      for DISK_CAB in "${DISK_FOLDER}"/*.cab; do
        if [[ ! -f "${DISK_CAB}" ]]; then
          continue
        fi

        local DISK_CAB_BASE="${DISK_CAB##*/}"
        ln -fs "${DISK_CAB}" "${CABS_PATH}/${DISK_CAB_BASE}"
      done

      for DISK_CAB in "${DISK_FOLDER}"/*.hdr; do
        if [[ ! -f "${DISK_CAB}" ]]; then
          continue
        fi

        local DISK_CAB_BASE="${DISK_CAB##*/}"
        ln -fs "${DISK_CAB}" "${CABS_PATH}/${DISK_CAB_BASE}"
      done
    done
  } || {
    term::step::failed_with_error "Failed to prepare cabs for unpacking. Aborting installation."
    return 1
  }

  if [[ ! -d "${TARGET_PATH}" ]]; then
    # Create the installation folder
    mkdir -p "${TARGET_PATH}" &>/dev/null || {
      term::step::failed_with_error "User does not have permission to create staging folder. Aborting installation."
      return 77 #E_PERM
    }
  fi

  local KDIALOG_DBUS_ADDRESS=()

  if [[ "${_arg_ui_mode:-none}" == "kdialog" ]]; then
    read -ra KDIALOG_DBUS_ADDRESS < <(kdialog --title "${CURRENT_STEP_NAME}" --progressbar "Unpacking install CABs..." 0 2>/dev/null)
    busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "showCancelButton" b "false" 2>/dev/null || true
  fi

  helper::progress::make_consistant __step::ut2004_unpack_cabs::run "${CABS_PATH}/data1.cab" "${TARGET_PATH}" | while IFS= read -r UNPACK_PROGRESS; do
    if [[ -z "${UNPACK_PROGRESS}" ]]; then
      term::step::progress "" >&6

      if [[ "${_arg_ui_mode:-none}" == "kdialog" ]]; then
        busctl --user set-property "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "maximum" i 0 2>/dev/null || true
      fi
      continue
    fi

    local TOTAL_FILES PERCENT CURRENT_FILE_INDEX FILE_NAME

    TOTAL_FILES=$(helper::string::unshift::next_value "${UNPACK_PROGRESS}")
    UNPACK_PROGRESS=$(helper::string::unshift::remainder "${UNPACK_PROGRESS}")

    PERCENT=$(helper::string::unshift::next_value "${UNPACK_PROGRESS}")
    UNPACK_PROGRESS=$(helper::string::unshift::remainder "${UNPACK_PROGRESS}")

    CURRENT_FILE_INDEX=$(helper::string::unshift::next_value "${UNPACK_PROGRESS}")
    UNPACK_PROGRESS=$(helper::string::unshift::remainder "${UNPACK_PROGRESS}")

    FILE_NAME=$(helper::string::unshift::next_value "${UNPACK_PROGRESS}")
    UNPACK_PROGRESS=$(helper::string::unshift::remainder "${UNPACK_PROGRESS}")

    term::step::progress "${CURRENT_FILE_INDEX} of ${TOTAL_FILES} - ${FILE_NAME}" >&6

    local DIALOG_TEXT="Unpacking ${FILE_NAME} (${CURRENT_FILE_INDEX} of ${TOTAL_FILES})"

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

    term::step::failed_with_error "Failed to unpack CABs. Installation aborted."
    return 1
  }

  if [[ "${_arg_ui_mode:-none}" == "kdialog" ]]; then
    busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "close" 2>/dev/null || true
  fi

  rm -rf "${CABS_PATH}" &>/dev/null || {
    term::step::failed_with_error "User does not have permission to remove temporary staging folder for CABs. Aborting installation."
    return 77 #E_PERM
  }

  term::step::complete
}

__step::ut2004_unpack_cabs::run() {
  local CAB_FILE="${1:-}"
  local WRITE_TO_PATH="${2:-}"

  local UNSHIELD_BIN="unshield"

  if [[ "${DOWNLOADS_FILENAME_LIST[unshield]:-}" == "unshield" ]]; then
    UNSHIELD_BIN="${_arg_destination%/}/Installer/unshield"

    if [[ ! -f "${UNSHIELD_BIN}" ]]; then
      term::error "unshield binary not present"
      return 1
    fi

    chmod +x "${UNSHIELD_BIN}"
  fi

  local RAW_TOTAL_FILES_TO_EXTRACT TOTAL_FILES_TO_EXTRACT
  RAW_TOTAL_FILES_TO_EXTRACT=$("${UNSHIELD_BIN}" l "${CAB_FILE}" | tail -n1)

  local LINE_MATCH_REGEX='^\s*([0-9]+)'

  if [[ "${RAW_TOTAL_FILES_TO_EXTRACT}" =~ ${LINE_MATCH_REGEX} ]]; then
    TOTAL_FILES_TO_EXTRACT="${BASH_REMATCH[1]}"
  fi

  local CURRENT_FILE_INDEX=0
  local EXTRACTING_MATCH_REGEX='^\s*extracting:\s+(.+)$'

  "${UNSHIELD_BIN}" -d "${WRITE_TO_PATH}" x "${CAB_FILE}" |
    while IFS= read -r UNPACK_PROGRESS; do
      if [[ "${UNPACK_PROGRESS}" =~ ${EXTRACTING_MATCH_REGEX} ]]; then
        local CURRENT_FILE="${BASH_REMATCH[1]##*/}"

        local PERCENT_PROGRESS="$(((CURRENT_FILE_INDEX * 100) / TOTAL_FILES_TO_EXTRACT))"
        CURRENT_FILE_INDEX=$((CURRENT_FILE_INDEX + 1))

        echo "${TOTAL_FILES_TO_EXTRACT}|${PERCENT_PROGRESS}|${CURRENT_FILE_INDEX}|${CURRENT_FILE}"
      fi
    done
}
