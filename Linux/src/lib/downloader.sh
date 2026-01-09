# shellcheck shell=bash

# Downloader
local DOWNLOADER_TIMEOUT=15
local DOWNLOADER_API_BIN=""
local DOWNLOADER_API_TYPE=""

local DOWNLOADER_DL_BIN=""
local DOWNLOADER_DL_TYPE=""

local DOWNLOADER_USER_AGENT="OldUnreal-${PRODUCT_SHORTNAME}-Linux-Installer/1.2"

# For archive.org links, aria2c will be instructed to open multiple connections at the same time
local ARIA2C_ARCHIVEORG_CONNECTIONS="${OLDUNREAL_ARCHIVEORG_ARIA2C_CONNECTIONS:-4}"

# Check which command should be used for API calls
if command -v "curl" &>/dev/null; then
  DOWNLOADER_API_BIN="curl"
  DOWNLOADER_API_TYPE="curl"
elif command -v "wget" &>/dev/null; then
  DOWNLOADER_API_BIN="wget"
  DOWNLOADER_API_TYPE="wget"

  # Check if provided wget version is Wget2... Thanks Fedora :(
  if [[ "$(wget --version)" =~ " Wget2 " ]]; then
    DOWNLOADER_API_TYPE="wget2"
  fi
elif command -v "wget2" &>/dev/null; then
  DOWNLOADER_API_BIN="wget2"
  DOWNLOADER_API_TYPE="wget2"
fi

# Check which command should be used for downloads
if command -v "aria2c" &>/dev/null; then
  DOWNLOADER_DL_BIN="aria2c"
  DOWNLOADER_DL_TYPE="aria2c"
else
  DOWNLOADER_DL_BIN="${DOWNLOADER_API_BIN}"
  DOWNLOADER_DL_TYPE="${DOWNLOADER_API_TYPE}"
fi

downloader::download_file() {
  if [[ -z "${1:-}" ]] || [[ -z "${2:-}" ]]; then
    return 1
  fi

  local CURRENT_DOWNLOAD_URL_SET REMAINING_DOWNLOAD_URL_SETS
  CURRENT_DOWNLOAD_URL_SET=$(helper::string::unshift::next_value "${1}" ";;")
  REMAINING_DOWNLOAD_URL_SETS=$(helper::string::unshift::remainder "${1}" ";;")

  local DOWNLOAD_PATH="${2}"
  local IS_RETRY="${3:-no}"

  __downloader::download_file "${CURRENT_DOWNLOAD_URL_SET}" "${DOWNLOAD_PATH}" "${IS_RETRY}" || downloader::download_file "${REMAINING_DOWNLOAD_URL_SETS}" "${DOWNLOAD_PATH}" "yes"
}

downloader::fetch_json() {
  local ENDPOINT_URL="${1:-}"

  if [[ -z "${ENDPOINT_URL}" ]]; then
    return 1
  fi

  local IS_SPECIAL_URL
  IS_SPECIAL_URL=$(__downloader::identify_special_host "${ENDPOINT_URL}")

  local RESOLVED_GITHUB_TOKEN=""

  if [[ "${IS_SPECIAL_URL}" == "github.com" ]]; then
    RESOLVED_GITHUB_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
  fi

  if [[ "${DOWNLOADER_API_TYPE}" == "curl" ]]; then
    local ADDITIONAL_ARGS=()

    if [[ "${IS_SPECIAL_URL}" == "github.com" ]] && [[ -n "${RESOLVED_GITHUB_TOKEN}" ]]; then
      ADDITIONAL_ARGS+=("--header" "Authorization: Bearer ${RESOLVED_GITHUB_TOKEN}")
    fi

    "${DOWNLOADER_API_BIN}" -Ls "${ADDITIONAL_ARGS[@]}" \
      --compressed --connect-timeout "${DOWNLOADER_TIMEOUT}" \
      --user-agent "${DOWNLOADER_USER_AGENT}" \
      "${ENDPOINT_URL}" 2>/dev/null
  elif [[ "${DOWNLOADER_API_TYPE}" == "wget" ]] || [[ "${DOWNLOADER_API_TYPE}" == "wget2" ]]; then
    local ADDITIONAL_ARGS=()

    if [[ "${IS_SPECIAL_URL}" == "github.com" ]] && [[ -n "${RESOLVED_GITHUB_TOKEN}" ]]; then
      ADDITIONAL_ARGS+=("--header=Authorization: Bearer ${RESOLVED_GITHUB_TOKEN}")
    fi

    "${DOWNLOADER_API_BIN}" -q "${ADDITIONAL_ARGS[@]}" \
      --timeout="${DOWNLOADER_TIMEOUT}" \
      --user-agent="${DOWNLOADER_USER_AGENT}" \
      "${ENDPOINT_URL}" -O - -o /dev/null 2>/dev/null
  fi
}

downloader::build_download_source_definition() {
  local SEPARATOR=";;"
  local SOURCE_DEF=""

  if [[ $# -eq 0 ]]; then
    return 1
  fi

  while [[ $# -gt 0 ]]; do
    local SOURCES_GROUP_VAR_NAME="${1}"
    shift

    if [[ -z "${SOURCES_GROUP_VAR_NAME}" ]]; then
      return 1
    fi

    local SOURCES_GROUP=()
    local SOURCES_GROUP_VAR_REF="${SOURCES_GROUP_VAR_NAME}[@]"
    SOURCES_GROUP=("${!SOURCES_GROUP_VAR_REF}")

    if [[ "${#SOURCES_GROUP[@]}" -gt 0 ]]; then
      while IFS= read -r SHUFFLED_ITEM; do
        if [[ -n "${SOURCE_DEF}" ]]; then
          SOURCE_DEF="${SOURCE_DEF}${SEPARATOR}"
        fi

        SOURCE_DEF="${SOURCE_DEF}${SHUFFLED_ITEM}"
      done < <(shuf -e "${SOURCES_GROUP[@]}")
    fi
  done

  echo "${SOURCE_DEF}"
}

downloader::compute_sha256sum() {
  local FILEPATH="${1:-}"

  if [[ -z "${FILEPATH}" ]] || [[ ! -f "${FILEPATH}" ]]; then
    return 1
  fi

  if command -v sha256sum &>/dev/null; then
    sha256sum "${FILEPATH}" | cut -f1 -d' '
  elif command -v shasum &>/dev/null; then
    shasum -a 256 "${FILEPATH}" | cut -f1 -d' '
  fi
}

__downloader::download_file() {
  local CURRENT_DOWNLOAD_URL_SET="${1:-}"
  local DOWNLOAD_PATH="${2:-}"
  local IS_RETRY="${3:-no}"

  if [[ -z "${CURRENT_DOWNLOAD_URL_SET}" ]] || [[ -z "${DOWNLOAD_PATH}" ]]; then
    return 1
  fi

  local DOWNLOAD_URL DOWNLOAD_EXPECTED_SIZE DOWNLOAD_EXPECTED_HASH

  DOWNLOAD_URL=$(helper::string::unshift::next_value "${CURRENT_DOWNLOAD_URL_SET}")
  CURRENT_DOWNLOAD_URL_SET=$(helper::string::unshift::remainder "${CURRENT_DOWNLOAD_URL_SET}")

  DOWNLOAD_EXPECTED_SIZE=$(helper::string::unshift::next_value "${CURRENT_DOWNLOAD_URL_SET}")
  CURRENT_DOWNLOAD_URL_SET=$(helper::string::unshift::remainder "${CURRENT_DOWNLOAD_URL_SET}")

  DOWNLOAD_EXPECTED_HASH=$(helper::string::unshift::next_value "${CURRENT_DOWNLOAD_URL_SET}")

  local DOWNLOAD_FILE="${DOWNLOAD_PATH##*/}"

  local TARGET_STEP_NAME="Download ${DOWNLOAD_FILE}"

  if [[ "${IS_RETRY}" == "no" ]]; then
    if [[ "${CURRENT_STEP_NAME}" != "${TARGET_STEP_NAME}" ]]; then
      term::step::new "${TARGET_STEP_NAME}"
    fi
    term::step::progress "Starting..."
  else
    term::step::new "${TARGET_STEP_NAME} (retry)"
  fi

  local DOWNLOAD_PROGRESS

  local KDIALOG_DBUS_ADDRESS=()

  if [[ "${_arg_ui_mode:-none}" == "kdialog" ]]; then
    read -ra KDIALOG_DBUS_ADDRESS < <(kdialog --title "${CURRENT_STEP_NAME}" --progressbar "Starting download..." 0 2>/dev/null)
  fi

  helper::progress::make_consistant __downloader::download_file_with_progress "${DOWNLOAD_URL}" "${DOWNLOAD_PATH}" | while IFS= read -r DOWNLOAD_PROGRESS; do
    if [[ -z "${DOWNLOAD_PROGRESS}" ]]; then
      term::step::progress "Starting..." >&6

      if [[ "${_arg_ui_mode:-none}" == "kdialog" ]]; then
        busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "setLabelText" s "Starting Download..." 2>/dev/null || break
        busctl --user set-property "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "maximum" i 0 2>/dev/null || break
      fi
      continue
    fi

    local TOTAL_SIZE CURRENT_PROGRESS RECEIVED SPEED
    DOWNLOAD_PROGRESS=$(helper::string::unshift::remainder "${DOWNLOAD_PROGRESS}")

    TOTAL_SIZE=$(helper::string::unshift::next_value "${DOWNLOAD_PROGRESS}")
    DOWNLOAD_PROGRESS=$(helper::string::unshift::remainder "${DOWNLOAD_PROGRESS}")

    CURRENT_PROGRESS=$(helper::string::unshift::next_value "${DOWNLOAD_PROGRESS}")
    DOWNLOAD_PROGRESS=$(helper::string::unshift::remainder "${DOWNLOAD_PROGRESS}")

    RECEIVED=$(helper::string::unshift::next_value "${DOWNLOAD_PROGRESS}")
    DOWNLOAD_PROGRESS=$(helper::string::unshift::remainder "${DOWNLOAD_PROGRESS}")

    SPEED=$(helper::string::unshift::next_value "${DOWNLOAD_PROGRESS}")

    term::step::progress "${CURRENT_PROGRESS}% @ ${SPEED}/s" >&6

    local DIALOG_TEXT="Downloading ${DOWNLOAD_FILE}\n${RECEIVED}"

    if [[ -n "${TOTAL_SIZE:-}" ]]; then
      DIALOG_TEXT="${DIALOG_TEXT} of ${TOTAL_SIZE} (${CURRENT_PROGRESS}%)"
    else
      DIALOG_TEXT="${DIALOG_TEXT} downloaded (${CURRENT_PROGRESS}%)"
    fi

    DIALOG_TEXT="${DIALOG_TEXT}\nSpeed : ${SPEED}/s"

    if [[ "${_arg_ui_mode:-none}" == "kdialog" ]]; then
      local ESCAPED_DIALOG_TEXT
      ESCAPED_DIALOG_TEXT="$(echo -e "${DIALOG_TEXT}")"
      busctl --user set-property "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "maximum" i 100 2>/dev/null || break
      busctl --user set-property "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "value" i "${CURRENT_PROGRESS}" 2>/dev/null || break
      busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "setLabelText" s "${ESCAPED_DIALOG_TEXT}" 2>/dev/null || break

      # Check for cancellation
      local WAS_CANCELLED
      WAS_CANCELLED="$(busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "wasCancelled" 2>/dev/null || echo "b true")"

      if [[ "${WAS_CANCELLED}" == "b true" ]]; then
        break
      fi
    elif [[ "${_arg_ui_mode:-none}" == "zenity" ]]; then
      echo "${CURRENT_PROGRESS}"
      echo "# ${DIALOG_TEXT}"
    fi
  done | {
    if [[ "${_arg_ui_mode:-none}" == "zenity" ]]; then
      zenity --progress --percentage=0 --text="Starting download..." --time-remaining --auto-close 2>/dev/null
    else
      cat - >/dev/null
    fi
  }

  local DOWNLOAD_STATUS="${PIPESTATUS[0]}"

  if [[ "${DOWNLOAD_STATUS}" -ne 0 ]]; then
    if [[ "${_arg_ui_mode:-none}" == "kdialog" ]]; then
      busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "close" 2>/dev/null || true
    fi

    term::step::failed
    return "${DOWNLOAD_STATUS}"
  fi

  if [[ "${_arg_ui_mode:-none}" == "kdialog" ]]; then
    busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "close" 2>/dev/null || true
  fi

  local DL_RESULT_FILESIZE DL_RESULT_HASH

  if [[ -n "${DOWNLOAD_EXPECTED_SIZE:-}" ]]; then
    DL_RESULT_FILESIZE=$(stat --format=%s "${DOWNLOAD_PATH}") || {
      term::step::failed
      return 1
    }

    if [[ "${DL_RESULT_FILESIZE}" -ne "${DOWNLOAD_EXPECTED_SIZE}" ]]; then
      term::step::failed
      return 1
    fi
  fi

  if [[ -n "${DOWNLOAD_EXPECTED_HASH:-}" ]]; then
    DL_RESULT_HASH=$(helper::progress::run_with_progress "Verifying file" downloader::compute_sha256sum "${DOWNLOAD_PATH}")

    if [[ -n "${DL_RESULT_HASH}" ]] && [[ "${DL_RESULT_HASH}" != "${DOWNLOAD_EXPECTED_HASH}" ]]; then
      term::step::failed
      return 1
    fi
  fi

  term::step::complete
}

# This function parses the output of the various downloaders to report status information
__downloader::download_file_with_progress() {
  local DOWNLOAD_URL="${1:-}"
  local DOWNLOAD_PATH="${2:-}"

  if [[ -z "${DOWNLOAD_URL}" ]] || [[ -z "${DOWNLOAD_PATH}" ]]; then
    return 1
  fi

  local DOWNLOAD_FILE="${DOWNLOAD_PATH##*/}"

  local TRANSFER_PROGRESS=""

  local IS_SPECIAL_URL
  IS_SPECIAL_URL=$(__downloader::identify_special_host "${DOWNLOAD_URL}")

  local RESOLVED_GITHUB_TOKEN=""

  if [[ "${IS_SPECIAL_URL}" == "github.com" ]]; then
    RESOLVED_GITHUB_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
  fi

  if [[ "${DOWNLOADER_DL_TYPE}" == "aria2c" ]]; then
    local ARIA2C_CAPTURE_REGEX='^\[#[a-z0-9]+\s+([1-9][0-9.]*(B|KiB|MiB|GiB|TiB))/([1-9][0-9.]*(B|KiB|MiB|GiB|TiB))\(([0-9]+)%\)\s+CN:[0-9]+\s+DL:([1-9][0-9.]*(B|KiB|MiB|GiB|TiB))\s+ETA:.+\]$'

    local ARIA2C_DOWNLOAD_DIRECTORY="${DOWNLOAD_PATH%/*}"
    local ARIA2C_DOWNLOAD_FILE="${DOWNLOAD_PATH##*/}"

    if [[ "${IS_SPECIAL_URL}" == "github.com" ]] && [[ -n "${RESOLVED_GITHUB_TOKEN}" ]]; then
      ADDITIONAL_ARGS+=("--header=Authorization: Bearer ${RESOLVED_GITHUB_TOKEN}")
    elif [[ "${IS_SPECIAL_URL}" == "archive.org" ]]; then
      ADDITIONAL_ARGS+=("-x" "${ARIA2C_ARCHIVEORG_CONNECTIONS}")
    fi

    stdbuf -o0 -- "${DOWNLOADER_DL_BIN}" --no-conf=true --allow-overwrite=true --remove-control-file=true \
      --daemon=false --enable-color=false --stop-with-process="$$" \
      --truncate-console-readout=false --console-log-level=warn --summary-interval=0 \
      --connect-timeout="${DOWNLOADER_TIMEOUT}" \
      --user-agent="${DOWNLOADER_USER_AGENT}" \
      --dir="${ARIA2C_DOWNLOAD_DIRECTORY}" --out="${ARIA2C_DOWNLOAD_FILE}" \
      "${ADDITIONAL_ARGS[@]}" \
      "${DOWNLOAD_URL}" |
      stdbuf -oL -- tr $'\r' $'\n' |
      while IFS= read -r TRANSFER_PROGRESS; do
        if [[ "${TRANSFER_PROGRESS}" =~ ${ARIA2C_CAPTURE_REGEX} ]]; then
          echo "${DOWNLOAD_FILE}|${BASH_REMATCH[3]}|${BASH_REMATCH[5]}|${BASH_REMATCH[1]}|${BASH_REMATCH[6]}"
        fi
      done
  elif [[ "${DOWNLOADER_DL_TYPE}" == "curl" ]]; then
    #                                  %                   Total          %            Received         %            Xfered        AvgSpdDown          AvgSpdUp  Time Total  Time Spent  Time Left   Current Speed
    local CURL_CAPTURE_REGEX='^\s*[0-9]+\s+([1-9][0-9.]*[kKMGT]?)\s+([0-9]+)\s+([0-9.]+[kKMGT]?)\s+[0-9]+\s+[0-9.]+[kKMGT]?\s+[0-9.]+[kKMGT]?\s+[0-9.]+[kKMGT]?\s+[-0-9:]+\s+[-0-9:]+\s+[-0-9:]+\s+([0-9.]+[kKMGT]?)\s*$'
    local ADDITIONAL_ARGS=()

    if [[ "${IS_SPECIAL_URL}" == "github.com" ]] && [[ -n "${RESOLVED_GITHUB_TOKEN}" ]]; then
      ADDITIONAL_ARGS+=("--header" "Authorization: Bearer ${RESOLVED_GITHUB_TOKEN}")
    fi

    "${DOWNLOADER_DL_BIN}" -LN --progress-meter "${ADDITIONAL_ARGS[@]}" \
      --connect-timeout "${DOWNLOADER_TIMEOUT}" \
      --user-agent "${DOWNLOADER_USER_AGENT}" \
      "${DOWNLOAD_URL}" -o "${DOWNLOAD_PATH}" 2>&1 |
      stdbuf -oL -- tr $'\r' $'\n' |
      while IFS= read -r TRANSFER_PROGRESS; do
        if [[ "${TRANSFER_PROGRESS}" =~ ${CURL_CAPTURE_REGEX} ]]; then
          echo "${DOWNLOAD_FILE}|${BASH_REMATCH[1]}|${BASH_REMATCH[2]}|${BASH_REMATCH[3]}|${BASH_REMATCH[4]}"
        fi
      done
    return "${PIPESTATUS[0]}"
  elif [[ "${DOWNLOADER_DL_TYPE}" == "wget" ]]; then
    local WGET_LENGTH_CAPTURE_REGEX='^Length:\s+[0-9]+\s+\((.*)\).*$'
    local WGET_CAPTURE_REGEX='^\s*([0-9.]+[BKMG])\s+[. ]+\s+([0-9]+)%\s+([0-9.]+[BKMG])\s+.*$'
    local TOTAL_SIZE
    local ADDITIONAL_ARGS=()

    if [[ "${IS_SPECIAL_URL}" == "github.com" ]] && [[ -n "${RESOLVED_GITHUB_TOKEN}" ]]; then
      ADDITIONAL_ARGS+=("--header=Authorization: Bearer ${RESOLVED_GITHUB_TOKEN}")
    fi

    "${DOWNLOADER_DL_BIN}" --progress=dot "${ADDITIONAL_ARGS[@]}" \
      --timeout="${DOWNLOADER_TIMEOUT}" \
      --user-agent="${DOWNLOADER_USER_AGENT}" \
      "${DOWNLOAD_URL}" -O "${DOWNLOAD_PATH}" -o - 2>&1 |
      while IFS= read -r TRANSFER_PROGRESS; do
        if [[ "${TRANSFER_PROGRESS}" =~ ${WGET_LENGTH_CAPTURE_REGEX} ]]; then
          TOTAL_SIZE="${BASH_REMATCH[1]}"
        elif [[ "${TRANSFER_PROGRESS}" =~ ${WGET_CAPTURE_REGEX} ]]; then
          echo "${DOWNLOAD_FILE}|${TOTAL_SIZE}|${BASH_REMATCH[2]}|${BASH_REMATCH[1]}|${BASH_REMATCH[3]}"
        fi
      done
    return "${PIPESTATUS[0]}"
  elif [[ "${DOWNLOADER_DL_TYPE}" == "wget2" ]]; then
    local WGET2_CAPTURE_REGEX='^\[1G.+\s+([0-9]+)%\s+\[.+\]\s+([0-9.]+[BKMG])\s+([0-9.]+[BKMG])(B?/s)?\s*$'
    local ADDITIONAL_ARGS=()

    if [[ "${IS_SPECIAL_URL}" == "github.com" ]] && [[ -n "${RESOLVED_GITHUB_TOKEN}" ]]; then
      ADDITIONAL_ARGS+=("--header=Authorization: Bearer ${RESOLVED_GITHUB_TOKEN}")
    fi

    "${DOWNLOADER_DL_BIN}" --progress=bar --force-progress "${ADDITIONAL_ARGS[@]}" \
      --timeout="${DOWNLOADER_TIMEOUT}" \
      --user-agent="${DOWNLOADER_USER_AGENT}" \
      "${DOWNLOAD_URL}" -O "${DOWNLOAD_PATH}" 2>&1 |
      stdbuf -oL -- tr $'\r\033' $'\n\n' |
      while IFS= read -r TRANSFER_PROGRESS; do
        if [[ "${TRANSFER_PROGRESS}" =~ ${WGET2_CAPTURE_REGEX} ]]; then
          echo "${DOWNLOAD_FILE}||${BASH_REMATCH[1]}|${BASH_REMATCH[2]}|${BASH_REMATCH[3]}"
        fi
      done
    return "${PIPESTATUS[0]}"
  fi
}

__downloader::identify_special_host() {
  local URL="${1:-}"

  if [[ "${URL}" =~ ^https://(github\.com|.+\.github\.com|.+\.githubusercontent\.com)/ ]]; then
    echo "github.com"
  elif [[ "${URL}" =~ ^https://(archive\.org|.+\.archive\.org)/ ]]; then
    echo "archive.org"
  fi
}
