# shellcheck shell=bash

step::ut2004_special_fixes() {
  term::step::new "Apply UT2004 Specific Fixes"

  local SYSTEM_FOLDER="${_arg_destination%/}/System${UE_SYSTEM_FOLDER_SUFFIX}"

  if [[ "${IS_DESTINATION_CASE_SENSITIVE_FS}" == "yes" ]]; then
    # Remove files with different casing than the patch payload
    local WRONG_CASING
    local COMMON_WRONG_CASINGS=(
      "Bonuspack.u"
      "Gui2K4.u"
      "Gameplay.u"
      "Ipdrv.u"
      "Skaarjpack.u"
      "StreamLineFX.u"
      "UT2K4Assault.u"
      "UT2K4AssaultFull.u"
      "XVoting.u"
      "xWebAdmin.u"
    )

    for WRONG_CASING in "${COMMON_WRONG_CASINGS[@]}"; do
      if [[ -f "${SYSTEM_FOLDER}/${WRONG_CASING}" ]]; then
        rm -f "${SYSTEM_FOLDER}/${WRONG_CASING}"
      fi

      if [[ -f "${_arg_destination%/}/System/${WRONG_CASING}" ]]; then
        rm -f "${_arg_destination%/}/System/${WRONG_CASING}"
      fi
    done
  fi

  # Remove provided libopenal if provided by the system
  if [[ -f "${SYSTEM_FOLDER}/libopenal.so.1" ]] && [[ -n "$(step::ut2004_special_fixes::find_library libopenal.so.1)" ]]; then
    rm -f "${SYSTEM_FOLDER}/libopenal.so.1" "${SYSTEM_FOLDER}/libopenal.so.1."*
  fi

  # Remove provided libSDL3 if provided by the system
  if [[ -f "${SYSTEM_FOLDER}/libSDL3.so.0" ]] && [[ -n "$(step::ut2004_special_fixes::find_library libSDL3.so.0)" ]]; then
    rm -f "${SYSTEM_FOLDER}/libSDL3.so.0" "${SYSTEM_FOLDER}/libSDL3.so.0."*
  fi

  # libomp fixes
  local SYSTEM_PROVIDED_LIBOMP_PATH=""
  local LIBOMP_REQUIRES_SYMLINK="no"

  SYSTEM_PROVIDED_LIBOMP_PATH=$(step::ut2004_special_fixes::find_library "libomp.so.5")

  if [[ -z "${SYSTEM_PROVIDED_LIBOMP_PATH}" ]]; then
    SYSTEM_PROVIDED_LIBOMP_PATH=$(step::ut2004_special_fixes::find_library "libomp.so")

    if [[ -n "${SYSTEM_PROVIDED_LIBOMP_PATH}" ]]; then
      LIBOMP_REQUIRES_SYMLINK="yes"
    fi
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

  local LINE_SEPARATOR=""

  while IFS= read -r FILE_LINE; do
    # Ini files may use Windows line endings, preserve them
    local LINE_ENDING=""
    if [[ "${FILE_LINE}" == *$'\r' ]]; then
      LINE_ENDING=$'\r'
    fi

    if [[ "${FILE_LINE%$'\r'}" == "${LINE_TO_REPLACE}" ]]; then
      IS_CONTENT_FOUND="yes"
      FILE_NEW_CONTENTS="${FILE_NEW_CONTENTS}${LINE_SEPARATOR}${REPLACEMENT_LINE}${LINE_ENDING}"
    else
      FILE_NEW_CONTENTS="${FILE_NEW_CONTENTS}${LINE_SEPARATOR}${FILE_LINE}"
    fi

    LINE_SEPARATOR=$'\n'
  done <<<"${FILE_CONTENTS}"

  if [[ "${IS_CONTENT_FOUND}" == "yes" ]]; then
    echo "${FILE_NEW_CONTENTS}" >"${FILENAME}"
  fi
}

step::ut2004_special_fixes::find_library() {
  local LIBRARY_NAME="${1:-}"

  if [[ -z "${LIBRARY_NAME}" ]]; then
    term::step::failed_with_error "ASSERT FAILED. Missing required arg in step::ut2004_special_fixes::find_library"
    return 1
  fi

  # ldconfig usually lives in /sbin or /usr/sbin, which may not be in PATH for regular users
  local LDCONFIG_BIN=""
  if command -v "ldconfig" &>/dev/null; then
    LDCONFIG_BIN="ldconfig"
  elif [[ -x "/sbin/ldconfig" ]]; then
    LDCONFIG_BIN="/sbin/ldconfig"
  elif [[ -x "/usr/sbin/ldconfig" ]]; then
    LDCONFIG_BIN="/usr/sbin/ldconfig"
  fi

  if [[ -n "${LDCONFIG_BIN}" ]]; then
    # On multilib systems, ldconfig lists libraries for every architecture, so only accept
    # the ones matching the architecture we are installing for
    local LDCONFIG_ABI_TAG=""
    case "${DETECTED_ARCHITECTURE}" in
    x86_64 | amd64)
      LDCONFIG_ABI_TAG="x86-64"
      ;;
    aarch64)
      LDCONFIG_ABI_TAG="AArch64"
      ;;
    ppc64le)
      LDCONFIG_ABI_TAG="64bit"
      ;;
    esac

    # Format: <tab>libname.so.1 (libc6,x86-64) => /usr/lib/libname.so.1
    local LDCONFIG_LINE_REGEX='^[[:space:]]*([^[:space:]]+)[[:space:]]+\(([^)]*)\)[[:space:]]+=>[[:space:]]+(.+)$'
    local LDCONFIG_LINE
    while IFS= read -r LDCONFIG_LINE; do
      if [[ ! "${LDCONFIG_LINE}" =~ ${LDCONFIG_LINE_REGEX} ]]; then
        continue
      fi

      if [[ "${BASH_REMATCH[1]}" != "${LIBRARY_NAME}" ]]; then
        continue
      fi

      if [[ -n "${LDCONFIG_ABI_TAG}" ]] && [[ ",${BASH_REMATCH[2]}," != *",${LDCONFIG_ABI_TAG},"* ]]; then
        continue
      fi

      if [[ -f "${BASH_REMATCH[3]}" ]]; then
        echo "${BASH_REMATCH[3]}"
        return 0
      fi
    done < <("${LDCONFIG_BIN}" -p 2>/dev/null || true)

    return 0
  fi

  local SEARCH_PATHS=("/usr/lib/${DETECTED_ARCHITECTURE}-linux-gnu" "/usr/lib64" "/usr/local/lib" "/lib/${DETECTED_ARCHITECTURE}-linux-gnu")
  local CURRENT_PATH
  for CURRENT_PATH in "${SEARCH_PATHS[@]}"; do
    if [[ -f "${CURRENT_PATH}/${LIBRARY_NAME}" ]]; then
      echo "${CURRENT_PATH}/${LIBRARY_NAME}"
      break
    fi
  done
}
