# shellcheck shell=bash

step::ut2004_special_fixes() {
  term::step::new "Apply UT2004 Specific Fixes"

  local SYSTEM_FOLDER="${_arg_destination%/}/System${UE_SYSTEM_FOLDER_SUFFIX}"

  # Remove provided libopenal if provided by the system
  if [[ -f "${SYSTEM_FOLDER}/libopenal.so.1" ]] && [[ -f "/usr/lib/libopenal.so.1" ]]; then
    rm -f "${SYSTEM_FOLDER}/libopenal.so.1" "${SYSTEM_FOLDER}/libopenal.so.1."*
  fi

  # Remove provided libSDL3 if provided by the system
  if [[ -f "${SYSTEM_FOLDER}/libSDL3.so.0" ]] && [[ -f "/usr/lib/libSDL3.so.0" ]]; then
    rm -f "${SYSTEM_FOLDER}/libSDL3.so.0" "${SYSTEM_FOLDER}/libSDL3.so.0."*
  fi

  # libomp fixes
  local SYSTEM_PROVIDED_LIBOMP_PATH=""
  local LIBOMP_REQUIRES_SYMLINK="no"

  if [[ -f "/usr/lib/libomp.so.5" ]]; then
    SYSTEM_PROVIDED_LIBOMP_PATH="/usr/lib/libomp.so.5"
  elif [[ -f "/usr/lib/libomp.so" ]]; then
    LIBOMP_REQUIRES_SYMLINK="yes"
    SYSTEM_PROVIDED_LIBOMP_PATH="/usr/lib/libomp.so"
  fi

  # Remove provided libomp.so.5 is one is provided by the system
  if [[ -f "${SYSTEM_FOLDER}/libomp.so.5" ]] && [[ -n "${SYSTEM_PROVIDED_LIBOMP_PATH}" ]]; then
    rm -f "${SYSTEM_FOLDER}/libomp.so.5" "${SYSTEM_FOLDER}/libomp.so.5."*
  fi

  if [[ "${LIBOMP_REQUIRES_SYMLINK}" == "yes" ]]; then
    ln -s "${SYSTEM_PROVIDED_LIBOMP_PATH}" "${SYSTEM_FOLDER}/libomp.so.5"
  fi

  step::ut2004_special_fixes::replace_line_in_file "${HOME}/.ut2004/System/UT2004.ini" "MainMenuClass=GUI2K4.UT2K4MainMenu" "MainMenuClass=GUI2K4.UT2K4MainMenuWS"
  step::ut2004_special_fixes::replace_line_in_file "${SYSTEM_FOLDER}/UT2004.ini" "MainMenuClass=GUI2K4.UT2K4MainMenu" "MainMenuClass=GUI2K4.UT2K4MainMenuWS"

  term::step::complete
}

# To avoid having a dependency on 'sed', this is being done manually
step::ut2004_special_fixes::replace_line_in_file() {
  local FILENAME="${1:-}"
  local LINE_TO_REPLACE="${2:-}"
  local REPLACEMENT_LINE="${3:-}"

  if [[ -z "${FILENAME}" ]] || [[ -z "${LINE_TO_REPLACE}" ]] || [[ -z "${REPLACEMENT_LINE}" ]]; then
    term::step::failed_with_error "ASSERT FAILED. Missing required arg in step::ut2004_special_fixes::replace_line_in_file"
    return 1
  fi

  if [[ ! -f "${FILENAME}" ]]; then
    return 0
  fi

  local FILE_CONTENTS FILE_LINE
  FILE_CONTENTS="$(cat "${FILENAME}")"

  local FILE_NEW_CONTENTS=""

  local IS_CONTENT_FOUND="no"

  while IFS= read -r FILE_LINE; do
    if [[ "${FILE_LINE}" == "${LINE_TO_REPLACE}" ]]; then
      IS_CONTENT_FOUND="yes"
      FILE_NEW_CONTENTS="${FILE_NEW_CONTENTS}"$'\n'"${REPLACEMENT_LINE}"
    else
      FILE_NEW_CONTENTS="${FILE_NEW_CONTENTS}"$'\n'"${FILE_LINE}"
    fi
  done <<<"${FILE_CONTENTS}"

  if [[ "${IS_CONTENT_FOUND}" == "yes" ]]; then
    echo "${FILE_NEW_CONTENTS}" >"${FILENAME}"
  fi
}
