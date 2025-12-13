# shellcheck shell=bash

# Downloader
local DOWNLOADER_TIMEOUT=15
local DOWNLOADER_PROGRESS_MIN_REFRESH=0.1
local DOWNLOADER_BIN=""
local DOWNLOADER_TYPE=""
if command -pv "curl" &>/dev/null; then
  DOWNLOADER_BIN="curl"
  DOWNLOADER_TYPE="curl"
elif command -pv "wget" &>/dev/null; then
  DOWNLOADER_BIN="wget"
  DOWNLOADER_TYPE="wget"

  # Check if provided wget version is Wget2... Thanks Fedora :(
  if [[ "$(wget --version)" =~ " Wget2 " ]]; then
    DOWNLOADER_TYPE="wget2"
  fi
elif command -pv "wget2" &>/dev/null; then
  DOWNLOADER_BIN="wget2"
  DOWNLOADER_TYPE="wget2"
fi

downloader::download_file() {
  if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
    return 1
  fi

  local DOWNLOAD_URL="${1%%"||"*}"
  local REMAINING_FALLBACKS="${1#*"||"}"

  if [ "${DOWNLOAD_URL}" == "${REMAINING_FALLBACKS}" ]; then
    REMAINING_FALLBACKS=""
  fi

  local DOWNLOAD_PATH="${2}"
  local IS_RETRY="${3:-no}"

  __downloader::download_file "${DOWNLOAD_URL}" "${DOWNLOAD_PATH}" "${IS_RETRY}" || downloader::download_file "${REMAINING_FALLBACKS}" "${DOWNLOAD_PATH}" "yes"
}

downloader::fetch_json() {
  local ENDPOINT_URL="${1:-}"

  if [ -z "${ENDPOINT_URL}" ]; then
    return 1
  fi

  local IS_GITHUB_URL="no"
  local RESOLVED_GITHUB_TOKEN=""

  if [[ "${ENDPOINT_URL}" =~ ^https://(github\.com|.+\.github\.com|.+\.githubusercontent\.com)/ ]]; then
    IS_GITHUB_URL="yes"
    RESOLVED_GITHUB_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
  fi

  if [ "${DOWNLOADER_TYPE}" == "curl" ]; then
    local ADDITIONAL_ARGS=()

    if [ "${IS_GITHUB_URL}" == "yes" ] && [ -n "${RESOLVED_GITHUB_TOKEN}" ]; then
      ADDITIONAL_ARGS+=("--header" "Authorization: Bearer ${RESOLVED_GITHUB_TOKEN}")
    fi

    "${DOWNLOADER_BIN}" -Ls "${ADDITIONAL_ARGS[@]}" --connect-timeout "${DOWNLOADER_TIMEOUT}" "${ENDPOINT_URL}" 2>/dev/null
  elif [ "${DOWNLOADER_TYPE}" == "wget" ]; then
    local ADDITIONAL_ARGS=()

    if [ "${IS_GITHUB_URL}" == "yes" ] && [ -n "${RESOLVED_GITHUB_TOKEN}" ]; then
      ADDITIONAL_ARGS+=("--header=Authorization: Bearer ${RESOLVED_GITHUB_TOKEN}")
    fi

    "${DOWNLOADER_BIN}" -q "${ADDITIONAL_ARGS[@]}" --timeout="${DOWNLOADER_TIMEOUT}" "${ENDPOINT_URL}" -O - -o /dev/null 2>/dev/null
  elif [ "${DOWNLOADER_TYPE}" == "wget2" ]; then
    local ADDITIONAL_ARGS=()

    if [ "${IS_GITHUB_URL}" == "yes" ] && [ -n "${RESOLVED_GITHUB_TOKEN}" ]; then
      ADDITIONAL_ARGS+=("--header=Authorization: Bearer ${RESOLVED_GITHUB_TOKEN}")
    fi

    "${DOWNLOADER_BIN}" -q "${ADDITIONAL_ARGS[@]}" --timeout="${DOWNLOADER_TIMEOUT}" "${ENDPOINT_URL}" -O - -o /dev/null 2>/dev/null
  fi
}

__downloader::download_file() {
  local DOWNLOAD_URL="${1:-}"
  local DOWNLOAD_PATH="${2:-}"
  local IS_RETRY="${3:-no}"

  if [ -z "${DOWNLOAD_URL}" ] || [ -z "${DOWNLOAD_PATH}" ]; then
    return 1
  fi

  local DOWNLOAD_FILE="${DOWNLOAD_PATH##*/}"

  if [ "${IS_RETRY}" == "no" ]; then
    term::step::new "Download ${DOWNLOAD_FILE}"
    term::step::progress "Starting..."
  else
    term::step::new "Download ${DOWNLOAD_FILE} (retry)"
  fi

  local DOWNLOAD_PROGRESS

  exec 6<&0

  local KDIALOG_DBUS_ADDRESS=()

  if [ "${_arg_ui_mode:-none}" == "kdialog" ]; then
    read -ra KDIALOG_DBUS_ADDRESS < <(kdialog --title "${CURRENT_STEP_NAME}" --progressbar "Starting download..." 0 2>/dev/null)
  fi

  __downloader::download_file_with_progress "${DOWNLOAD_URL}" "${DOWNLOAD_PATH}" | while IFS= read -r DOWNLOAD_PROGRESS; do
    if [ -z "${DOWNLOAD_PROGRESS}" ]; then
      term::step::progress "Starting..." >&6

      if [ "${_arg_ui_mode:-none}" == "kdialog" ]; then
        busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "setLabelText" s "Starting Download..." 2>/dev/null  || break
        busctl --user set-property "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "maximum" i 0 2>/dev/null || break
      fi
      continue
    fi
 
    DOWNLOAD_PROGRESS="${DOWNLOAD_PROGRESS#*|}"

    local TOTAL_SIZE="${DOWNLOAD_PROGRESS%%|*}"
    DOWNLOAD_PROGRESS="${DOWNLOAD_PROGRESS#*|}"

    local CURRENT_PROGRESS="${DOWNLOAD_PROGRESS%%|*}"
    DOWNLOAD_PROGRESS="${DOWNLOAD_PROGRESS#*|}"

    local RECEIVED="${DOWNLOAD_PROGRESS%%|*}"
    DOWNLOAD_PROGRESS="${DOWNLOAD_PROGRESS#*|}"

    local SPEED="${DOWNLOAD_PROGRESS%%|*}"

    term::step::progress "${CURRENT_PROGRESS}% @ ${SPEED}/s" >&6

    local DIALOG_TEXT="Downloading ${DOWNLOAD_FILE}\n${RECEIVED}"

    if [ -n "${TOTAL_SIZE:-}" ]; then
      DIALOG_TEXT="${DIALOG_TEXT} of ${TOTAL_SIZE} (${CURRENT_PROGRESS}%)"
    else
      DIALOG_TEXT="${DIALOG_TEXT} downloaded (${CURRENT_PROGRESS}%)"
    fi

    DIALOG_TEXT="${DIALOG_TEXT}\nSpeed : ${SPEED}/s"

    if [ "${_arg_ui_mode:-none}" == "kdialog" ]; then
      local ESCAPED_DIALOG_TEXT
      ESCAPED_DIALOG_TEXT="$(echo -e "${DIALOG_TEXT}")"
      busctl --user set-property "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "maximum" i 100 2>/dev/null || break
      busctl --user set-property "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "value" i "${CURRENT_PROGRESS}" 2>/dev/null || break
      busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "setLabelText" s "${ESCAPED_DIALOG_TEXT}" 2>/dev/null || break

      # Check for cancellation
      local WAS_CANCELLED
      WAS_CANCELLED="$(busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "wasCancelled" 2>/dev/null || echo "b true")"

      if [ "${WAS_CANCELLED}" == "b true" ]; then
        break;
      fi
    elif [ "${_arg_ui_mode:-none}" == "zenity" ]; then
      echo "${CURRENT_PROGRESS}"
      echo "# ${DIALOG_TEXT}"
    fi
  done | { if [ "${_arg_ui_mode:-none}" == "zenity" ]; then
      zenity --progress --percentage=0 --text="Starting download..." --time-remaining --auto-close 2>/dev/null;
    else
      cat - >/dev/null;
    fi
  }

  local DOWNLOAD_STATUS="${PIPESTATUS[0]}"

  exec 0<&6 6<&-

  if [ "${DOWNLOAD_STATUS}" -ne 0 ]; then
    if [ "${_arg_ui_mode:-none}" == "kdialog" ]; then
      busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "close" 2>/dev/null || true
    fi

    term::step::failed
    return "${DOWNLOAD_STATUS}"
  fi

  if [ "${_arg_ui_mode:-none}" == "kdialog" ]; then
    busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "close" 2>/dev/null || true
  fi

  term::step::complete
}

# This function throttles the output to avoid buffering, while also making sure the last update
# is repeated at a set frequency for the throbber to work
__downloader::download_file_with_progress() {
  local DOWNLOAD_URL="${1:-}"
  local DOWNLOAD_PATH="${2:-}"

  if [ -z "${DOWNLOAD_URL}" ] || [ -z "${DOWNLOAD_PATH}" ]; then
    return 1
  fi

  local LAST_UPDATE=""
  local CURRENT_UPDATE=""

  exec 3< <(__downloader::download_file_with_progress::raw "${DOWNLOAD_URL}" "${DOWNLOAD_PATH}")
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

# This function parses the output of the various downloaders to report status information
__downloader::download_file_with_progress::raw() {
  local DOWNLOAD_URL="${1:-}"
  local DOWNLOAD_PATH="${2:-}"

  if [ -z "${DOWNLOAD_URL}" ] || [ -z "${DOWNLOAD_PATH}" ]; then
    return 1
  fi

  local DOWNLOAD_FILE="${DOWNLOAD_PATH##*/}"

  local TRANSFER_PROGRESS=""

  local IS_GITHUB_URL="no"
  local RESOLVED_GITHUB_TOKEN=""

  if [[ "${DOWNLOAD_URL}" =~ ^https://(github\.com|.+\.github\.com|.+\.githubusercontent\.com)/ ]]; then
    IS_GITHUB_URL="yes"
    RESOLVED_GITHUB_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
  fi

  set -m
  {
    if [ "${DOWNLOADER_TYPE}" == "curl" ]; then
      #                                  %                   Total          %            Received         %            Xfered        AvgSpdDown          AvgSpdUp  Time Total  Time Spent  Time Left   Current Speed
      local CURL_CAPTURE_REGEX='^\s*[0-9]+\s+([1-9][0-9.]*[kKMGT]?)\s+([0-9]+)\s+([0-9.]+[kKMGT]?)\s+[0-9]+\s+[0-9.]+[kKMGT]?\s+[0-9.]+[kKMGT]?\s+[0-9.]+[kKMGT]?\s+[-0-9:]+\s+[-0-9:]+\s+[-0-9:]+\s+([0-9.]+[kKMGT]?)\s*$'
      local ADDITIONAL_ARGS=()

      if [ "${IS_GITHUB_URL}" == "yes" ] && [ -n "${RESOLVED_GITHUB_TOKEN}" ]; then
        ADDITIONAL_ARGS+=("--header" "Authorization: Bearer ${RESOLVED_GITHUB_TOKEN}")
      fi

      "${DOWNLOADER_BIN}" -LN --progress-meter "${ADDITIONAL_ARGS[@]}" --connect-timeout "${DOWNLOADER_TIMEOUT}" "${DOWNLOAD_URL}" -o "${DOWNLOAD_PATH}" 2>&1 \
        | stdbuf -oL -- tr '\r' '\n' \
        | while IFS= read -r TRANSFER_PROGRESS; do
          if [[ "${TRANSFER_PROGRESS}" =~ ${CURL_CAPTURE_REGEX} ]]; then
            echo "${DOWNLOAD_FILE}|${BASH_REMATCH[1]}|${BASH_REMATCH[2]}|${BASH_REMATCH[3]}|${BASH_REMATCH[4]}"
          fi
        done
      return "${PIPESTATUS[0]}"
    elif [ "${DOWNLOADER_TYPE}" == "wget" ]; then
      local WGET_LENGTH_CAPTURE_REGEX='^Length:\s+[0-9]+\s+\((.*)\).*$'
      local WGET_CAPTURE_REGEX='^\s*([0-9.]+[BKMG])\s+[. ]+\s+([0-9]+)%\s+([0-9.]+[BKMG])\s+.*$'
      local TOTAL_SIZE
      local ADDITIONAL_ARGS=()

      if [ "${IS_GITHUB_URL}" == "yes" ] && [ -n "${RESOLVED_GITHUB_TOKEN}" ]; then
        ADDITIONAL_ARGS+=("--header=Authorization: Bearer ${RESOLVED_GITHUB_TOKEN}")
      fi

      "${DOWNLOADER_BIN}" --progress=dot "${ADDITIONAL_ARGS[@]}" --timeout="${DOWNLOADER_TIMEOUT}" "${DOWNLOAD_URL}" -O "${DOWNLOAD_PATH}" -o - 2>&1 \
        | while IFS= read -r TRANSFER_PROGRESS; do
          if [[ "${TRANSFER_PROGRESS}" =~ ${WGET_LENGTH_CAPTURE_REGEX} ]]; then
            TOTAL_SIZE="${BASH_REMATCH[1]}"
          elif [[ "${TRANSFER_PROGRESS}" =~ ${WGET_CAPTURE_REGEX} ]]; then
            echo "${DOWNLOAD_FILE}|${TOTAL_SIZE}|${BASH_REMATCH[2]}|${BASH_REMATCH[1]}|${BASH_REMATCH[3]}"
          fi
        done
      return "${PIPESTATUS[0]}"
    elif [ "${DOWNLOADER_TYPE}" == "wget2" ]; then
      local WGET2_CAPTURE_REGEX='^\[1G.+\s+([0-9]+)%\s+\[.+\]\s+([0-9.]+[BKMG])\s+([0-9.]+[BKMG])(B?/s)?\s*$'
      local ADDITIONAL_ARGS=()

      if [ "${IS_GITHUB_URL}" == "yes" ] && [ -n "${RESOLVED_GITHUB_TOKEN}" ]; then
        ADDITIONAL_ARGS+=("--header=Authorization: Bearer ${RESOLVED_GITHUB_TOKEN}")
      fi

      "${DOWNLOADER_BIN}" --progress=bar --force-progress "${ADDITIONAL_ARGS[@]}" --timeout="${DOWNLOADER_TIMEOUT}" "${DOWNLOAD_URL}" -O "${DOWNLOAD_PATH}" 2>&1 \
        | stdbuf -oL -- tr '\r\033' '\n\n' \
        | while IFS= read -r TRANSFER_PROGRESS; do
          if [[ "${TRANSFER_PROGRESS}" =~ ${WGET2_CAPTURE_REGEX} ]]; then
            echo "${DOWNLOAD_FILE}||${BASH_REMATCH[1]}|${BASH_REMATCH[2]}|${BASH_REMATCH[3]}"
          fi
        done
      return "${PIPESTATUS[0]}"
    fi
  } &
  set +m
  local PROC_SUB_PID=$!

  trap 'trap - EXIT; [ -n "${PROC_SUB_PID:-}" ] && { kill -- -"${PROC_SUB_PID}"; wait "${PROC_SUB_PID}"; return $?; }' EXIT

  wait "${PROC_SUB_PID}"
  local EXIT_CODE=$?
  trap - EXIT;
  return $?
}
