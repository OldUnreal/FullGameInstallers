# shellcheck shell=bash

local UNARCHIVER_BIN=""
if command -pv "7z" &>/dev/null; then
  UNARCHIVER_BIN="7z"
elif command -pv "7zz" &>/dev/null; then
  UNARCHIVER_BIN="7zz"
fi

unarchiver::unarchive_file() {
  local ITEM_NAME="${1:-}"
  local ARCHIVE_PATH="${2:-}"
  local TARGET_PATH="${3:-}"
  local IGNORE_PATTERNS_VAR_NAME="${4:-}"
  local IGNORE_PATTERNS_RECURSIVE_VAR_NAME="${5:-}"

  if [ -z "${ARCHIVE_PATH}" ] || [ -z "${TARGET_PATH}" ]; then
    return 1
  fi

  if [ ! -f "${ARCHIVE_PATH}" ]; then
    return 1
  fi

  term::step::new "Extract ${ITEM_NAME}"

  local UNARCHIVE_PROGRESS

  exec 6<&0

  local KDIALOG_DBUS_ADDRESS=()

  if [ "${_arg_ui_mode:-none}" == "kdialog" ]; then
    read -ra KDIALOG_DBUS_ADDRESS < <(kdialog --title "${CURRENT_STEP_NAME}" --progressbar "Extracting ${ITEM_NAME}..." 0 2>/dev/null)
    busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "showCancelButton" b "false" 2>/dev/null || true
  fi

  __unarchiver::unarchive_file_with_progress "${ARCHIVE_PATH}" "${TARGET_PATH}" "${IGNORE_PATTERNS_VAR_NAME}" "${IGNORE_PATTERNS_RECURSIVE_VAR_NAME}" \
   | while IFS= read -r UNARCHIVE_PROGRESS; do
    if [ -z "${UNARCHIVE_PROGRESS}" ]; then
      term::step::progress "" >&6

      if [ "${_arg_ui_mode:-none}" == "kdialog" ]; then
        busctl --user set-property "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "maximum" i 0 2>/dev/null || true
      fi
      continue
    fi

    term::step::progress "${UNARCHIVE_PROGRESS}%" >&6

    local DIALOG_TEXT="Extracting ${ITEM_NAME} (${UNARCHIVE_PROGRESS}%)"

    if [ "${_arg_ui_mode:-none}" == "kdialog" ]; then
      local ESCAPED_DIALOG_TEXT
      ESCAPED_DIALOG_TEXT="$(echo -e "${DIALOG_TEXT}")"
      busctl --user set-property "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "maximum" i 100 2>/dev/null || true
      busctl --user set-property "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "value" i "${UNARCHIVE_PROGRESS}" 2>/dev/null || true
      busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "setLabelText" s "${ESCAPED_DIALOG_TEXT}" 2>/dev/null || true
    elif [ "${_arg_ui_mode:-none}" == "zenity" ]; then
      echo "${UNARCHIVE_PROGRESS}"
      echo "# ${DIALOG_TEXT}"
    fi
  done | { if [ "${_arg_ui_mode:-none}" == "zenity" ]; then
      zenity --progress --percentage=0 --text="Extracting ${ITEM_NAME}..." --no-cancel --time-remaining --auto-close 2>/dev/null;
    else
      cat - >/dev/null;
    fi
  }

  local UNARCHIVE_STATUS="${PIPESTATUS[0]}"

  exec 0<&6 6<&-

  if [ "${UNARCHIVE_STATUS}" -ne 0 ]; then
    if [ "${_arg_ui_mode:-none}" == "kdialog" ]; then
      busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "close" 2>/dev/null || true
    fi

    term::step::failed
    return "${UNARCHIVE_STATUS}"
  fi

  if [ "${_arg_ui_mode:-none}" == "kdialog" ]; then
    busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "close" 2>/dev/null || true
  fi

  term::step::complete
}

__unarchiver::unarchive_file_with_progress() {
  local ARCHIVE_PATH="${1:-}"
  local TARGET_PATH="${2:-}"
  local IGNORE_PATTERNS_VAR_NAME="${3:-}"
  local IGNORE_PATTERNS_RECURSIVE_VAR_NAME="${4:-}"

  if [ -z "${ARCHIVE_PATH}" ] || [ -z "${TARGET_PATH}" ]; then
    return 1
  fi

  local LAST_UPDATE=""
  local CURRENT_UPDATE=""

  exec 3< <(__unarchiver::unarchive_file_with_progress::raw "${ARCHIVE_PATH}" "${TARGET_PATH}" "${IGNORE_PATTERNS_VAR_NAME}" "${IGNORE_PATTERNS_RECURSIVE_VAR_NAME}")
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

__unarchiver::unarchive_file_with_progress::raw() {
  local ARCHIVE_PATH="${1:-}"
  local TARGET_PATH="${2:-}"
  local IGNORE_PATTERNS_VAR_NAME="${3:-}"
  local IGNORE_PATTERNS_RECURSIVE_VAR_NAME="${4:-}"

  if [ -z "${ARCHIVE_PATH}" ] || [ -z "${TARGET_PATH}" ]; then
    return 1
  fi

  local UNARCHIVE_PROGRESS=""
  set -m
  {
    local SEVENZ_REGEX='^\s*([0-9]+)%'

    __unarchiver::unarchive_file::call_7z \
      "${ARCHIVE_PATH}" "${TARGET_PATH}" \
      "${IGNORE_PATTERNS_VAR_NAME}" "${IGNORE_PATTERNS_RECURSIVE_VAR_NAME}" \
        | stdbuf -oL -- tr $'\b\r' $'\n\n' \
        | while IFS= read -r UNARCHIVE_PROGRESS; do
          if [[ "${UNARCHIVE_PROGRESS}" =~ ${SEVENZ_REGEX} ]]; then
            echo "${BASH_REMATCH[1]}"
          fi
        done
    return "${PIPESTATUS[0]}"
  } &
  set +m
  local PROC_SUB_PID=$!

  trap 'trap - EXIT; [ -n "${PROC_SUB_PID:-}" ] && { kill -- -"${PROC_SUB_PID}"; wait "${PROC_SUB_PID}"; return $?; }' EXIT

  wait "${PROC_SUB_PID}"
  local EXIT_CODE=$?
  trap - EXIT;
  return $?
}

__unarchiver::unarchive_file::call_7z() {
  local ARCHIVE_PATH="${1:-}"
  local TARGET_PATH="${2:-}"

  if [ -z "${ARCHIVE_PATH}" ] || [ -z "${TARGET_PATH}" ]; then
    return 1
  fi

  local ARCHIVE_FILENAME="${ARCHIVE_PATH##*/}"

  local IGNORE_PATTERNS=()
  local IGNORE_PATTERNS_VAR_NAME="${3:-}"
  if [ -n "${IGNORE_PATTERNS_VAR_NAME}" ]; then
    local IGNORE_PATTERN_VAR_REF="${IGNORE_PATTERNS_VAR_NAME}[@]"
    IGNORE_PATTERNS=("${!IGNORE_PATTERN_VAR_REF}")
  fi

  local IGNORE_PATTERNS_RECURSIVE=()
  local IGNORE_PATTERNS_RECURSIVE_VAR_NAME="${4:-}"
  if [ -n "${IGNORE_PATTERNS_RECURSIVE_VAR_NAME}" ]; then
    local IGNORE_PATTERN_RECURSIVE_VAR_REF="${IGNORE_PATTERNS_RECURSIVE_VAR_NAME}[@]"
    IGNORE_PATTERNS_RECURSIVE=("${!IGNORE_PATTERN_RECURSIVE_VAR_REF}")
  fi

  local IS_TARBALL="n"

  case "${ARCHIVE_FILENAME}" in
    *.tar.gz|*.tgz)
      IS_TARBALL="y"
      ;;
    *.tar.bz2|*.tbz)
      IS_TARBALL="y"
      ;;
    *.tar.xz|*.txz)
      IS_TARBALL="y"
      ;;
    *.tar.zst|*.tar.zstd)
      IS_TARBALL="y"
      ;;
  esac

  local SEZENZ_ARGS=()
  local SEZENZ_OUTER_ARGS=()

  if [ "${IS_TARBALL}" == "y" ]; then
    SEZENZ_OUTER_ARGS=("x" "${ARCHIVE_PATH}" "-y" "-bsp0" "-bso0" "-bse2" "-so")
    SEZENZ_ARGS=("x" "-si" "-ttar" "-y" "-bsp1" "-bso0" "-bse0" "-o${TARGET_PATH}")
  else
    SEZENZ_ARGS=("x" "${ARCHIVE_PATH}" "-y" "-bsp1" "-bso0" "-bse0" "-o${TARGET_PATH}")
  fi

  local IGNORE
  for IGNORE in "${IGNORE_PATTERNS[@]}"
  do
    SEZENZ_ARGS+=("-x!${IGNORE}")
  done

  for IGNORE in "${IGNORE_PATTERNS_RECURSIVE[@]}"
  do
    SEZENZ_ARGS+=("-xr!${IGNORE}")
  done

  if [ "${IS_TARBALL}" == "y" ]; then
    "${UNARCHIVER_BIN}" "${SEZENZ_OUTER_ARGS[@]}" | "${UNARCHIVER_BIN}" "${SEZENZ_ARGS[@]}"
  else
    "${UNARCHIVER_BIN}" "${SEZENZ_ARGS[@]}"
  fi
}
