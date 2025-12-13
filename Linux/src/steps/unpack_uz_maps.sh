# shellcheck shell=bash

step::unpack_uz_maps() {
  term::step::new "Unpack Maps"

  exec 6<&0

  local KDIALOG_DBUS_ADDRESS=()

  if [ "${_arg_ui_mode:-none}" == "kdialog" ]; then
    read -ra KDIALOG_DBUS_ADDRESS < <(kdialog --title "${CURRENT_STEP_NAME}" --progressbar "Unpacking maps..." 0 2>/dev/null)
    busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "showCancelButton" b "false" 2>/dev/null || true
  fi

  __downloader::unpack_uz_maps::run | while IFS= read -r UNPACK_PROGRESS; do
    if [ -z "${UNPACK_PROGRESS}" ]; then
      term::step::progress "" >&6

      if [ "${_arg_ui_mode:-none}" == "kdialog" ]; then
        busctl --user set-property "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "maximum" i 0 2>/dev/null || true
      fi
      continue
    fi
 
    local TOTAL_FILES="${UNPACK_PROGRESS%%|*}"
    UNPACK_PROGRESS="${UNPACK_PROGRESS#*|}"

    local PERCENT="${UNPACK_PROGRESS%%|*}"
    UNPACK_PROGRESS="${UNPACK_PROGRESS#*|}"

    local CURRENT_FILE_INDEX="${UNPACK_PROGRESS%%|*}"
    UNPACK_PROGRESS="${UNPACK_PROGRESS#*|}"

    local MAP_NAME="${UNPACK_PROGRESS}"

    term::step::progress "${CURRENT_FILE_INDEX} of ${TOTAL_FILES} - ${MAP_NAME}" >&6

    local DIALOG_TEXT="Unpacking ${MAP_NAME} (${CURRENT_FILE_INDEX} of ${TOTAL_FILES})"

    if [ "${_arg_ui_mode:-none}" == "kdialog" ]; then
      local ESCAPED_DIALOG_TEXT
      ESCAPED_DIALOG_TEXT="$(echo -e "${DIALOG_TEXT}")"
      busctl --user set-property "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "maximum" i "${TOTAL_FILES}" 2>/dev/null || true
      busctl --user set-property "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "value" i "${CURRENT_FILE_INDEX}" 2>/dev/null || true
      busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "setLabelText" s "${ESCAPED_DIALOG_TEXT}" 2>/dev/null || true
    elif [ "${_arg_ui_mode:-none}" == "zenity" ]; then
      echo "${PERCENT}"
      echo "# ${DIALOG_TEXT}"
    fi
  done | { if [ "${_arg_ui_mode:-none}" == "zenity" ]; then
      zenity --progress --percentage=0 --text="Unpacking maps..." --no-cancel --time-remaining --auto-close 2>/dev/null;
    else
      cat - >/dev/null;
    fi
  } || {
    exec 0<&6 6<&-

    if [ "${_arg_ui_mode:-none}" == "kdialog" ]; then
      busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "close" 2>/dev/null || true
    fi

    term::step::failed_with_error "Failed to unpack all maps. Installation aborted."
    return 1
  }

  exec 0<&6 6<&-

  if [ "${_arg_ui_mode:-none}" == "kdialog" ]; then
    busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "close" 2>/dev/null || true
  fi

  term::step::complete
}

__downloader::unpack_uz_maps::run() {
  local LAST_UPDATE=""
  local CURRENT_UPDATE=""

  exec 3< <(__step::unpack_uz_maps::run::raw)
  local PROC_SUB_PID=$!

  trap '[ -n "${PROC_SUB_PID:-}" ] && { kill -- "${PROC_SUB_PID}"; }' EXIT

  local CAN_WRITE="y"
  trap 'CAN_WRITE="n"' SIGPIPE

  while kill -0 "${PROC_SUB_PID}" 2>/dev/null; do
    while IFS= read -r -u 3 -t 0.001 CURRENT_UPDATE; do
      LAST_UPDATE="${CURRENT_UPDATE}"
    done
    
    if [ "${CAN_WRITE}" == "y" ]; then
      echo "${LAST_UPDATE}" 2>/dev/null
      sleep "${DOWNLOADER_PROGRESS_MIN_REFRESH}"
    else
      break
    fi
  done

  trap - SIGPIPE EXIT

  local EXIT_CODE=1

  if [ "${CAN_WRITE}" == "y" ]; then
    # Final drain of remaining data
    while IFS= read -r -u 3 CURRENT_UPDATE; do
      LAST_UPDATE="${CURRENT_UPDATE}"
    done
    echo "${LAST_UPDATE}"
  else
    if kill -0 "${PROC_SUB_PID}" 2>/dev/null; then
      # Explicitly kill if the loop exited due to CAN_WRITE="n"
      kill -TERM -- "${PROC_SUB_PID}"
    fi

    return 1
  fi

  wait "${PROC_SUB_PID}"
  EXIT_CODE=$?

  exec 3<&-
  return "${EXIT_CODE}"
}

__step::unpack_uz_maps::run::raw() {
  local UCC_BIN_PATH="${_arg_destination%/}/System${UE_SYSTEM_FOLDER_SUFFIX:-}/ucc-bin-${ARCHITECTURE_SUFFIX}"

  local MAP_FILES=()
  local MAP_FILE

  for MAP_FILE in "${_arg_destination%/}/Maps"/*.unr.uz
  do
    local MAP_BASENAME="${MAP_FILE##*/}"
    MAP_FILES+=("${MAP_BASENAME}")
  done

  local TOTAL_MAP_FILES="${#MAP_FILES[@]}"
  local MAP_FILES_PROCESSED=0

  for MAP_FILE in "${MAP_FILES[@]}"
  do
    local MAP_BASENAME_UNCOMPRESSED="${MAP_FILE%.uz}"

    local COMPRESSED_FILE="${_arg_destination%/}/Maps/${MAP_FILE}"
    local DECOMPRESS_STAGING="${_arg_destination%/}/System${UE_SYSTEM_FOLDER_SUFFIX:-}/${MAP_BASENAME_UNCOMPRESSED}"
    local DECOMPRESS_TARGET="${_arg_destination%/}/Maps/${MAP_BASENAME_UNCOMPRESSED}"

    local PERCENT_PROGRESS="$(((MAP_FILES_PROCESSED * 100)/TOTAL_MAP_FILES))"
    MAP_FILES_PROCESSED=$((MAP_FILES_PROCESSED+1))

    echo "${TOTAL_MAP_FILES}|${PERCENT_PROGRESS}|${MAP_FILES_PROCESSED}|${MAP_BASENAME_UNCOMPRESSED}"

    if [ -f "${DECOMPRESS_TARGET}" ]; then
      rm -f "${COMPRESSED_FILE}"
    else
      "${UCC_BIN_PATH}" decompress "../Maps/${MAP_FILE}" -nohomedir &>/dev/null || {
        return 1
      }

      if [ -f "${DECOMPRESS_STAGING}" ]; then
        { mv -f "${DECOMPRESS_STAGING}" "${DECOMPRESS_TARGET}" && rm -f "${COMPRESSED_FILE}"; } || {
          return 1
        }
      else
        return 1
      fi
    fi
  done
}
