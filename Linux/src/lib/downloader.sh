# shellcheck shell=bash

# Downloader
local DOWNLOADER_TIMEOUT=15
local DOWNLOADER_API_BIN=""
local DOWNLOADER_API_TYPE=""

local DOWNLOADER_DL_BIN=""
local DOWNLOADER_DL_TYPE=""

local DOWNLOADER_USER_AGENT="OldUnreal-${PRODUCT_SHORTNAME}-Linux-Installer/1.3.1"

# For archive.org links, aria2c will be instructed to open multiple connections at the same time
local ARIA2C_ARCHIVEORG_CONNECTIONS="${OLDUNREAL_ARCHIVEORG_ARIA2C_CONNECTIONS:-4}"

# Connections without data for DOWNLOADER_READ_TIMEOUT seconds, or slower than DOWNLOADER_LOWEST_SPEED bytes/s
# for DOWNLOADER_STALL_TIMEOUT seconds are considered stalled
local DOWNLOADER_READ_TIMEOUT=30
local DOWNLOADER_LOWEST_SPEED=1024
local DOWNLOADER_STALL_TIMEOUT=60

# Each source is attempted multiple times (resuming the partial download) before moving to the next one
local DOWNLOADER_MAX_ATTEMPTS="${OLDUNREAL_DOWNLOAD_ATTEMPTS:-3}"
local DOWNLOADER_RETRY_DELAY=5

local DOWNLOADER_CANCELLED_STATUS=130

# Check which command should be used for API calls (preferably curl, then wget, then wget2)
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

# Check which command should be used for downloads (preferably aria2c, then wget, then wget2, then curl)
if command -v "aria2c" &>/dev/null; then
  DOWNLOADER_DL_BIN="aria2c"
  DOWNLOADER_DL_TYPE="aria2c"
elif command -v "wget" &>/dev/null; then
  DOWNLOADER_DL_BIN="wget"
  DOWNLOADER_DL_TYPE="wget"

  # Check if provided wget version is Wget2... Thanks Fedora :(
  if [[ "$(wget --version)" =~ " Wget2 " ]]; then
    DOWNLOADER_DL_TYPE="wget2"
  fi
elif command -v "wget2" &>/dev/null; then
  DOWNLOADER_DL_BIN="wget2"
  DOWNLOADER_DL_TYPE="wget2"
elif command -v "curl" &>/dev/null; then
  # curl is to be used as last resort, as it doesn't provide a way to resume downloads on retries
  # https://curl.se/docs/todo.html#--retry-should-resume
  DOWNLOADER_DL_BIN="curl"
  DOWNLOADER_DL_TYPE="curl"
fi

downloader::download_file() {
  if [[ -z "${1:-}" ]] || [[ -z "${2:-}" ]]; then
    return 1
  fi

  local DOWNLOAD_URL_SETS="${1}"
  local DOWNLOAD_PATH="${2}"
  local IS_RETRY="${3:-no}"

  # Try each source in order until one succeeds
  local SET_INDEX=1
  local CURRENT_DOWNLOAD_URL_SET
  while true; do
    CURRENT_DOWNLOAD_URL_SET=$(helper::string::field "${DOWNLOAD_URL_SETS}" "${SET_INDEX}" ";;")

    if [[ -z "${CURRENT_DOWNLOAD_URL_SET}" ]]; then
      return 1
    fi

    local SOURCE_STATUS=0
    __downloader::download_source "${CURRENT_DOWNLOAD_URL_SET}" "${DOWNLOAD_PATH}" "${IS_RETRY}" || SOURCE_STATUS=$?

    if [[ "${SOURCE_STATUS}" -eq 0 ]] || [[ "${SOURCE_STATUS}" -eq "${DOWNLOADER_CANCELLED_STATUS}" ]]; then
      return "${SOURCE_STATUS}"
    fi

    IS_RETRY="yes"
    SET_INDEX=$((SET_INDEX + 1))
  done
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

    "${DOWNLOADER_API_BIN}" -Ls --fail "${ADDITIONAL_ARGS[@]}" \
      --retry 3 --retry-delay 2 \
      --compressed --connect-timeout "${DOWNLOADER_TIMEOUT}" \
      --user-agent "${DOWNLOADER_USER_AGENT}" \
      "${ENDPOINT_URL}" 2>/dev/null
  elif [[ "${DOWNLOADER_API_TYPE}" == "wget" ]] || [[ "${DOWNLOADER_API_TYPE}" == "wget2" ]]; then
    local ADDITIONAL_ARGS=()

    if [[ "${IS_SPECIAL_URL}" == "github.com" ]] && [[ -n "${RESOLVED_GITHUB_TOKEN}" ]]; then
      ADDITIONAL_ARGS+=("--header=Authorization: Bearer ${RESOLVED_GITHUB_TOKEN}")
    fi

    "${DOWNLOADER_API_BIN}" -q "${ADDITIONAL_ARGS[@]}" \
      --tries=3 --timeout="${DOWNLOADER_TIMEOUT}" \
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

__downloader::download_source() {
  local CURRENT_DOWNLOAD_URL_SET="${1:-}"
  local DOWNLOAD_PATH="${2:-}"
  local IS_RETRY="${3:-no}"

  if [[ -z "${CURRENT_DOWNLOAD_URL_SET}" ]] || [[ -z "${DOWNLOAD_PATH}" ]]; then
    return 1
  fi

  local ARCHIVE_MEMBER
  ARCHIVE_MEMBER=$(helper::string::field "${CURRENT_DOWNLOAD_URL_SET}" 4)

  if [[ -z "${ARCHIVE_MEMBER}" ]]; then
    __downloader::download_file "${CURRENT_DOWNLOAD_URL_SET}" "${DOWNLOAD_PATH}" "${IS_RETRY}"
    return
  fi

  # The source is an archive: download it under its own name, then extract the member to DOWNLOAD_PATH
  local DOWNLOAD_FILE="${DOWNLOAD_PATH##*/}"
  local DOWNLOAD_DIRECTORY="${DOWNLOAD_PATH%/*}"

  local ARCHIVE_FILENAME
  ARCHIVE_FILENAME=$(helper::string::field "${CURRENT_DOWNLOAD_URL_SET}" 1)
  ARCHIVE_FILENAME="${ARCHIVE_FILENAME##*/}"
  ARCHIVE_FILENAME="${ARCHIVE_FILENAME%%\?*}"
  ARCHIVE_FILENAME=$(printf '%b' "${ARCHIVE_FILENAME//%/\\x}")

  if [[ -z "${ARCHIVE_FILENAME}" ]] || [[ "${ARCHIVE_FILENAME}" == */* ]] || [[ "${ARCHIVE_FILENAME}" == "." ]] || [[ "${ARCHIVE_FILENAME}" == ".." ]]; then
    return 1
  fi

  local ARCHIVE_PATH="${DOWNLOAD_DIRECTORY}/${ARCHIVE_FILENAME}"
  local STAGING_PATH="${DOWNLOAD_DIRECTORY}/.archive-staging"

  local ARCHIVE_EXPECTED_SIZE ARCHIVE_EXPECTED_HASH
  ARCHIVE_EXPECTED_SIZE=$(helper::string::field "${CURRENT_DOWNLOAD_URL_SET}" 2)
  ARCHIVE_EXPECTED_HASH=$(helper::string::field "${CURRENT_DOWNLOAD_URL_SET}" 3)

  # Open the step here, as the existing archive check below reports its progress on it
  local DOWNLOAD_DISPLAY_NAME="${DOWNLOAD_FILE}"
  if [[ "${IS_RETRY}" == "yes" ]]; then
    DOWNLOAD_DISPLAY_NAME="${DOWNLOAD_FILE} (retry)"
  fi

  if [[ "${CURRENT_STEP_NAME}" != "Download ${DOWNLOAD_DISPLAY_NAME}" ]]; then
    term::step::new "Download ${DOWNLOAD_DISPLAY_NAME}"
  fi

  # Reuse a previously completed archive download (e.g. if a prior extraction was interrupted)
  if [[ -f "${ARCHIVE_PATH}" ]] && [[ ! -f "${ARCHIVE_PATH}.aria2" ]] &&
    __downloader::verify_file "${ARCHIVE_PATH}" "${ARCHIVE_EXPECTED_SIZE}" "${ARCHIVE_EXPECTED_HASH}"; then
    term::step::skipped "SKIPPED: Archive already downloaded"
  else
    __downloader::download_file "${CURRENT_DOWNLOAD_URL_SET}" "${ARCHIVE_PATH}" "no" "${DOWNLOAD_DISPLAY_NAME}" || return
  fi

  rm -rf "${STAGING_PATH}"
  unarchiver::unarchive_file "${DOWNLOAD_FILE}" "${ARCHIVE_PATH}" "${STAGING_PATH}" || return 1

  term::step::new "Verify ${DOWNLOAD_FILE}"

  __downloader::discard_partial_download "${DOWNLOAD_PATH}"
  mv -f "${STAGING_PATH}/${ARCHIVE_MEMBER}" "${DOWNLOAD_PATH}" || {
    term::step::failed
    return 1
  }

  rm -rf "${STAGING_PATH}"
  if [[ "${_arg_keep_installer_files:-off}" != "on" ]]; then
    rm -f "${ARCHIVE_PATH}"
  fi

  __downloader::verify_file "${DOWNLOAD_PATH}" "$(helper::string::field "${CURRENT_DOWNLOAD_URL_SET}" 5)" "$(helper::string::field "${CURRENT_DOWNLOAD_URL_SET}" 6)" || {
    term::step::failed
    return 1
  }

  term::step::complete
}

__downloader::verify_file() {
  local FILE_PATH="${1:-}"
  local EXPECTED_SIZE="${2:-}"
  local EXPECTED_HASH="${3:-}"

  if [[ -n "${EXPECTED_SIZE}" ]]; then
    local FILE_SIZE
    FILE_SIZE=$(stat --format=%s "${FILE_PATH}") || return 1

    if [[ "${FILE_SIZE}" -ne "${EXPECTED_SIZE}" ]]; then
      return 1
    fi
  fi

  if [[ -n "${EXPECTED_HASH}" ]]; then
    local FILE_HASH
    FILE_HASH=$(helper::progress::run_with_progress "Verifying file" downloader::compute_sha256sum "${FILE_PATH}")

    if [[ -n "${FILE_HASH}" ]] && [[ "${FILE_HASH}" != "${EXPECTED_HASH}" ]]; then
      return 1
    fi
  fi
}

__downloader::download_file() {
  local CURRENT_DOWNLOAD_URL_SET="${1:-}"
  local DOWNLOAD_PATH="${2:-}"
  local IS_RETRY="${3:-no}"
  local DOWNLOAD_DISPLAY_NAME="${4:-}"

  if [[ -z "${CURRENT_DOWNLOAD_URL_SET}" ]] || [[ -z "${DOWNLOAD_PATH}" ]]; then
    return 1
  fi

  local DOWNLOAD_URL DOWNLOAD_EXPECTED_SIZE DOWNLOAD_EXPECTED_HASH

  DOWNLOAD_URL=$(helper::string::field "${CURRENT_DOWNLOAD_URL_SET}" 1)
  DOWNLOAD_EXPECTED_SIZE=$(helper::string::field "${CURRENT_DOWNLOAD_URL_SET}" 2)
  DOWNLOAD_EXPECTED_HASH=$(helper::string::field "${CURRENT_DOWNLOAD_URL_SET}" 3)

  local DOWNLOAD_FILE="${DOWNLOAD_DISPLAY_NAME:-${DOWNLOAD_PATH##*/}}"

  local TARGET_STEP_NAME="Download ${DOWNLOAD_FILE}"
  local RETRY_STEP_NAME="${TARGET_STEP_NAME% (retry)} (retry)"

  if [[ "${IS_RETRY}" == "no" ]]; then
    if [[ "${CURRENT_STEP_NAME}" != "${TARGET_STEP_NAME}" ]]; then
      term::step::new "${TARGET_STEP_NAME}"
    fi
    term::step::progress "Starting..."
  else
    term::step::new "${RETRY_STEP_NAME}"
  fi

  # Identifies the expected content, so a partial download is only ever resumed into the same file.
  # Without a hash, the URL is the best identity available.
  local DOWNLOAD_IDENTITY="${DOWNLOAD_EXPECTED_SIZE}|${DOWNLOAD_EXPECTED_HASH}"
  if [[ -z "${DOWNLOAD_EXPECTED_HASH}" ]]; then
    DOWNLOAD_IDENTITY="${DOWNLOAD_URL}|${DOWNLOAD_EXPECTED_SIZE}"
  fi

  local ATTEMPT=1
  local HAS_RESTARTED_FROM_SCRATCH="no"
  while true; do
    __downloader::prepare_partial_download "${DOWNLOAD_PATH}" "${DOWNLOAD_IDENTITY}" || {
      term::step::failed
      return 1
    }

    local TRANSFER_STATUS=0
    __downloader::transfer_file "${DOWNLOAD_URL}" "${DOWNLOAD_PATH}" "${DOWNLOAD_FILE}" || TRANSFER_STATUS=$?

    if [[ "${TRANSFER_STATUS}" -eq "${DOWNLOADER_CANCELLED_STATUS}" ]]; then
      term::step::failed
      return "${DOWNLOADER_CANCELLED_STATUS}"
    fi

    if [[ "${TRANSFER_STATUS}" -eq 0 ]]; then
      if __downloader::verify_file "${DOWNLOAD_PATH}" "${DOWNLOAD_EXPECTED_SIZE:-}" "${DOWNLOAD_EXPECTED_HASH:-}"; then
        rm -f "${DOWNLOAD_PATH}.source"
        term::step::complete
        return 0
      fi

      # The completed file doesn't match, so it can't be resumed: start over once, then give up on this source
      __downloader::discard_partial_download "${DOWNLOAD_PATH}"

      if [[ "${HAS_RESTARTED_FROM_SCRATCH}" == "yes" ]]; then
        term::step::failed
        return 1
      fi

      HAS_RESTARTED_FROM_SCRATCH="yes"
    elif { [[ "${DOWNLOADER_DL_TYPE}" == "curl" ]] && [[ "${TRANSFER_STATUS}" -eq 33 ]]; } ||
      { [[ "${DOWNLOADER_DL_TYPE}" == "aria2c" ]] && [[ "${TRANSFER_STATUS}" -eq 8 ]]; }; then
      # The server can't resume the partial download (curl: CURLE_RANGE_ERROR, aria2c: resume not supported)
      __downloader::discard_partial_download "${DOWNLOAD_PATH}"
    fi

    term::step::failed

    ATTEMPT=$((ATTEMPT + 1))
    if [[ "${ATTEMPT}" -gt "${DOWNLOADER_MAX_ATTEMPTS}" ]]; then
      return 1
    fi

    local RETRY_DELAY=$((DOWNLOADER_RETRY_DELAY * (ATTEMPT - 1)))
    term::step::new "${RETRY_STEP_NAME}"
    term::step::progress "Waiting ${RETRY_DELAY}s"
    sleep "${RETRY_DELAY}"
  done
}

# Partial downloads are tagged with the identity of their expected content in a .source file, and
# discarded when it doesn't match (e.g. a patch re-released under the same file name)
__downloader::prepare_partial_download() {
  local DOWNLOAD_PATH="${1:-}"
  local DOWNLOAD_IDENTITY="${2:-}"
  local IDENTITY_PATH="${DOWNLOAD_PATH}.source"

  # Never download through a symbolic link (e.g. left from reusing a file next to the script, which was
  # since moved), as the data would be written wherever it points to. Only the link itself is removed.
  if [[ -L "${DOWNLOAD_PATH}" ]]; then
    rm -f "${DOWNLOAD_PATH}"
  fi

  if [[ -f "${DOWNLOAD_PATH}" ]] || [[ -f "${DOWNLOAD_PATH}.aria2" ]]; then
    if [[ ! -f "${IDENTITY_PATH}" ]] || [[ "$(<"${IDENTITY_PATH}")" != "${DOWNLOAD_IDENTITY}" ]]; then
      __downloader::discard_partial_download "${DOWNLOAD_PATH}"
    fi
  fi

  echo "${DOWNLOAD_IDENTITY}" >"${IDENTITY_PATH}"
}

__downloader::discard_partial_download() {
  local DOWNLOAD_PATH="${1:-}"

  rm -f "${DOWNLOAD_PATH}" "${DOWNLOAD_PATH}.aria2" "${DOWNLOAD_PATH}.source"
}

__downloader::transfer_file() {
  local DOWNLOAD_URL="${1:-}"
  local DOWNLOAD_PATH="${2:-}"
  local DOWNLOAD_FILE="${3:-}"

  local DOWNLOAD_PROGRESS

  local KDIALOG_DBUS_ADDRESS=()

  # With kdialog, the progress dialog no longer being reachable on D-Bus means the user closed it,
  # which is handled the same way as cancelling it
  if [[ "${_arg_ui_mode:-none}" == "kdialog" ]]; then
    read -ra KDIALOG_DBUS_ADDRESS < <(kdialog --title "${CURRENT_STEP_NAME}" --progressbar "Starting download..." 0 2>/dev/null)
  fi

  helper::progress::make_consistant __downloader::download_file_with_progress "${DOWNLOAD_URL}" "${DOWNLOAD_PATH}" | while IFS= read -r DOWNLOAD_PROGRESS; do
    if [[ -z "${DOWNLOAD_PROGRESS}" ]]; then
      term::step::progress "Starting..." >&6

      if [[ "${_arg_ui_mode:-none}" == "kdialog" ]]; then
        busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "setLabelText" s "Starting Download..." 2>/dev/null || exit "${DOWNLOADER_CANCELLED_STATUS}"
        busctl --user set-property "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "maximum" i 0 2>/dev/null || exit "${DOWNLOADER_CANCELLED_STATUS}"
      fi
      continue
    fi

    local TOTAL_SIZE CURRENT_PROGRESS RECEIVED SPEED

    TOTAL_SIZE=$(helper::string::field "${DOWNLOAD_PROGRESS}" 2)
    CURRENT_PROGRESS=$(helper::string::field "${DOWNLOAD_PROGRESS}" 3)
    RECEIVED=$(helper::string::field "${DOWNLOAD_PROGRESS}" 4)
    SPEED=$(helper::string::field "${DOWNLOAD_PROGRESS}" 5)

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
      busctl --user set-property "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "maximum" i 100 2>/dev/null || exit "${DOWNLOADER_CANCELLED_STATUS}"
      busctl --user set-property "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "value" i "${CURRENT_PROGRESS}" 2>/dev/null || exit "${DOWNLOADER_CANCELLED_STATUS}"
      busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "setLabelText" s "${ESCAPED_DIALOG_TEXT}" 2>/dev/null || exit "${DOWNLOADER_CANCELLED_STATUS}"

      # Check for cancellation
      local WAS_CANCELLED
      WAS_CANCELLED="$(busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "wasCancelled" 2>/dev/null || echo "b true")"

      if [[ "${WAS_CANCELLED}" == "b true" ]]; then
        exit "${DOWNLOADER_CANCELLED_STATUS}"
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

  local PIPE_STATUSES=("${PIPESTATUS[@]}")
  local TRANSFER_STATUS="${PIPE_STATUSES[0]}"

  if [[ "${_arg_ui_mode:-none}" == "kdialog" ]]; then
    busctl --user call "${KDIALOG_DBUS_ADDRESS[@]}" "org.kde.kdialog.ProgressDialog" "close" 2>/dev/null || true
  fi

  # The transfer was interrupted by the user cancelling the kdialog or zenity progress dialog
  if [[ "${TRANSFER_STATUS}" -ne 0 ]] &&
    { [[ "${PIPE_STATUSES[1]}" -eq "${DOWNLOADER_CANCELLED_STATUS}" ]] || [[ "${PIPE_STATUSES[2]}" -ne 0 ]]; }; then
    return "${DOWNLOADER_CANCELLED_STATUS}"
  fi

  return "${TRANSFER_STATUS}"
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
    local ADDITIONAL_ARGS=()

    if [[ "${IS_SPECIAL_URL}" == "github.com" ]] && [[ -n "${RESOLVED_GITHUB_TOKEN}" ]]; then
      ADDITIONAL_ARGS+=("--header=Authorization: Bearer ${RESOLVED_GITHUB_TOKEN}")
    elif [[ "${IS_SPECIAL_URL}" == "archive.org" ]]; then
      ADDITIONAL_ARGS+=("-x" "${ARIA2C_ARCHIVEORG_CONNECTIONS}")
    fi

    stdbuf -o0 -- "${DOWNLOADER_DL_BIN}" --no-conf=true --continue=true --allow-overwrite=true --auto-file-renaming=false \
      --daemon=false --enable-color=false --stop-with-process="$$" \
      --truncate-console-readout=false --console-log-level=warn --summary-interval=0 \
      --connect-timeout="${DOWNLOADER_TIMEOUT}" --timeout="${DOWNLOADER_READ_TIMEOUT}" \
      --lowest-speed-limit="${DOWNLOADER_LOWEST_SPEED}" --max-tries=5 --retry-wait=5 \
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
    return "${PIPESTATUS[0]}"
  elif [[ "${DOWNLOADER_DL_TYPE}" == "curl" ]]; then
    #                                  %                   Total          %            Received         %            Xfered        AvgSpdDown          AvgSpdUp  Time Total  Time Spent  Time Left   Current Speed
    local CURL_CAPTURE_REGEX='^\s*[0-9]+\s+([1-9][0-9.]*[kKMGT]?)\s+([0-9]+)\s+([0-9.]+[kKMGT]?)\s+[0-9]+\s+[0-9.]+[kKMGT]?\s+[0-9.]+[kKMGT]?\s+[0-9.]+[kKMGT]?\s+[-0-9:]+\s+[-0-9:]+\s+[-0-9:]+\s+([0-9.]+[kKMGT]?)\s*$'
    local ADDITIONAL_ARGS=()

    if [[ "${IS_SPECIAL_URL}" == "github.com" ]] && [[ -n "${RESOLVED_GITHUB_TOKEN}" ]]; then
      ADDITIONAL_ARGS+=("--header" "Authorization: Bearer ${RESOLVED_GITHUB_TOKEN}")
    fi

    "${DOWNLOADER_DL_BIN}" -LN --fail --progress-meter -C - "${ADDITIONAL_ARGS[@]}" \
      --connect-timeout "${DOWNLOADER_TIMEOUT}" \
      --speed-limit "${DOWNLOADER_LOWEST_SPEED}" --speed-time "${DOWNLOADER_STALL_TIMEOUT}" \
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
    local TOTAL_SIZE=""
    local ADDITIONAL_ARGS=()

    if [[ "${IS_SPECIAL_URL}" == "github.com" ]] && [[ -n "${RESOLVED_GITHUB_TOKEN}" ]]; then
      ADDITIONAL_ARGS+=("--header=Authorization: Bearer ${RESOLVED_GITHUB_TOKEN}")
    fi

    "${DOWNLOADER_DL_BIN}" --progress=dot -c "${ADDITIONAL_ARGS[@]}" \
      --timeout="${DOWNLOADER_TIMEOUT}" --read-timeout="${DOWNLOADER_READ_TIMEOUT}" \
      --tries=5 --waitretry=5 --retry-connrefused \
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

    "${DOWNLOADER_DL_BIN}" --progress=bar --force-progress -c "${ADDITIONAL_ARGS[@]}" \
      --timeout="${DOWNLOADER_TIMEOUT}" --read-timeout="${DOWNLOADER_READ_TIMEOUT}" \
      --tries=5 --waitretry=5 --retry-connrefused \
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

  if [[ "${URL}" =~ ^https://(github\.com|[^/]+\.github\.com|[^/]+\.githubusercontent\.com)/ ]]; then
    echo "github.com"
  elif [[ "${URL}" =~ ^https://(archive\.org|[^/]+\.archive\.org)/ ]]; then
    echo "archive.org"
  fi
}
