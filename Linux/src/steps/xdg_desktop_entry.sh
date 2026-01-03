# shellcheck shell=bash

step::xdg_desktop_entry() {
  local STEP_NAME="${1:-}"
  local STEP_PROMPT="${2:-}"
  local DESKTOP_ENTRY_PATH="${3:-}"
  local DESKTOP_ENTRY_PATH_UNREALED="${4:-}"
  local APPLICATION_ENTRY_HANDLING_MODE="${5:-}"
  local SKIP_IF_ENTRY_FOLDER_DOESNT_EXIST="${6:-no}"

  if [[ -z "${STEP_NAME}" ]] ||
    [[ -z "${STEP_PROMPT}" ]] ||
    [[ -z "${DESKTOP_ENTRY_PATH}" ]] ||
    [[ -z "${DESKTOP_ENTRY_PATH_UNREALED}" ]] ||
    [[ -z "${APPLICATION_ENTRY_HANDLING_MODE}" ]]; then
    return 1
  fi

  if [[ "${APPLICATION_ENTRY_HANDLING_MODE:-skip}" == "skip" ]]; then
    term::step::new "${STEP_NAME}"
    term::step::skipped "SKIPPED: User opted out"
    return 0
  fi

  if [[ "${SKIP_IF_ENTRY_FOLDER_DOESNT_EXIST}" == "yes" ]]; then
    local DESKTOP_ENTRY_FOLDER="${DESKTOP_ENTRY_PATH%/*}"

    if [[ ! -d "${DESKTOP_ENTRY_FOLDER}" ]]; then
      term::step::new "${STEP_NAME}"
      term::step::skipped "SKIPPED: Not Available"
      return 0
    fi
  fi

  # Prompt before showing step name in text mode
  if [[ "${_arg_ui_mode:-none}" == "none" ]] && [[ "${APPLICATION_ENTRY_HANDLING_MODE}" == "prompt" ]]; then
    echo
    if ! term::yesno "${STEP_PROMPT}"; then
      echo
      term::step::new "${STEP_NAME}"
      term::step::skipped "SKIPPED: User opted out"
      return 0
    fi
    echo
  fi

  term::step::new "${STEP_NAME}"

  if [[ "${_arg_ui_mode:-none}" != "none" ]] && [[ "${APPLICATION_ENTRY_HANDLING_MODE}" == "prompt" ]]; then
    local DIALOG_ARGS=()

    if [[ "${_arg_ui_mode:-none}" == "kdialog" ]]; then
      DIALOG_ARGS=(
        kdialog
        --yesno
        "${STEP_PROMPT}"
      )
    elif [[ "${_arg_ui_mode:-none}" == "zenity" ]]; then
      DIALOG_ARGS=(
        zenity
        --question
        "--text=${STEP_PROMPT}"
      )
    fi

    if ! "${DIALOG_ARGS[@]}" &>/dev/null; then
      term::step::skipped "SKIPPED: User opted out"
      return 0
    fi
  fi

  __step::xdg_desktop_entry::create "${DESKTOP_ENTRY_PATH}" || {
    term::step::failed_with_error "User does not have permission to create .desktop file."
    return 77 #E_PERM
  }

  if [[ "${_arg_unrealed}" == "on" ]]; then
    __step::xdg_desktop_entry::unrealed::create "${DESKTOP_ENTRY_PATH_UNREALED}" || {
      term::step::failed_with_error "User does not have permission to create .desktop file."
      return 77 #E_PERM
    }
  fi

  term::step::complete
}

step::xdg_desktop_entry::xdg_dir() {
  local STEP_NAME="${1:-}"
  local STEP_PROMPT="${2:-}"
  local XDG_DIR_NAME="${3:-}"
  local DESKTOP_ENTRY_PATH="${4:-}"
  local DESKTOP_ENTRY_PATH_UNREALED="${5:-}"
  local APPLICATION_ENTRY_HANDLING_MODE="${6:-}"

  if [[ -z "${STEP_NAME}" ]] ||
    [[ -z "${STEP_PROMPT}" ]] ||
    [[ -z "${XDG_DIR_NAME}" ]] ||
    [[ -z "${DESKTOP_ENTRY_PATH}" ]] ||
    [[ -z "${DESKTOP_ENTRY_PATH_UNREALED}" ]] ||
    [[ -z "${APPLICATION_ENTRY_HANDLING_MODE}" ]]; then
    return 1
  fi

  local XDG_DIR_PATH
  XDG_DIR_PATH=$(xdgdirs::get_user_dir "${XDG_DIR_NAME}")

  if [[ -z "${XDG_DIR_PATH}" ]]; then
    term::step::new "${STEP_NAME}"
    term::step::skipped "SKIPPED: Not Available"
    return 0
  fi

  step::xdg_desktop_entry \
    "${STEP_NAME}" \
    "${STEP_PROMPT}" \
    "${XDG_DIR_PATH}/${DESKTOP_ENTRY_PATH}" \
    "${XDG_DIR_PATH}/${DESKTOP_ENTRY_PATH_UNREALED}" \
    "${APPLICATION_ENTRY_HANDLING_MODE}" \
    "yes"
}

__step::xdg_desktop_entry::create() {
  local DESKTOP_ENTRY_PATH="${1:-}"

  if [[ -z "${DESKTOP_ENTRY_PATH}" ]]; then
    return 1
  fi

  local DESKTOP_ENTRY_FOLDER="${DESKTOP_ENTRY_PATH%/*}"

  local SOURCE_ICON="${_arg_destination%/}/${PRODUCT_ICONPATH:-Help/Unreal.ico}"
  local ICON_NAME
  ICON_NAME=$(__step::xdg_desktop_entry::get_icon_name "${SOURCE_ICON}" "OldUnreal_${PRODUCT_SHORTNAME}" || echo "${SOURCE_ICON}")

  # Create destination folder if it doesn't exist
  if [[ ! -d "${DESKTOP_ENTRY_FOLDER}" ]]; then
    mkdir -p "${DESKTOP_ENTRY_FOLDER}" 2>/dev/null
  fi

  {
    echo "[Desktop Entry]"
    echo "Name=${PRODUCT_NAME}"

    if [[ -n "${PRODUCT_KEYWORDS[*]:-}" ]]; then
      echo -n "Keywords="

      local KEYWORD
      for KEYWORD in "${PRODUCT_KEYWORDS[@]}"; do
        echo -n "${KEYWORD};"
      done
      echo
    fi

    if [[ -n "${PRODUCT_URLSCHEME:-}" ]]; then
      echo "Exec="'"'"${_arg_destination%/}/System${UE_SYSTEM_FOLDER_SUFFIX:-}/${MAIN_BINARY_NAME}${ARCHITECTURE_BINARY_SUFFIX}"'"' %u
      echo "MimeType=x-scheme-handler/${PRODUCT_URLSCHEME};"
    else
      echo "Exec="'"'"${_arg_destination%/}/System${UE_SYSTEM_FOLDER_SUFFIX:-}/${MAIN_BINARY_NAME}${ARCHITECTURE_BINARY_SUFFIX}"'"'
    fi

    echo "Icon=${ICON_NAME}"
    echo "Terminal=false"
    echo "Type=Application"
    echo "Categories=Game;"
  } >"${DESKTOP_ENTRY_PATH}"
}

__step::xdg_desktop_entry::unrealed::create() {
  local DESKTOP_ENTRY_PATH="${1:-}"

  if [[ -z "${DESKTOP_ENTRY_PATH}" ]]; then
    return 1
  fi

  local DESKTOP_ENTRY_FOLDER="${DESKTOP_ENTRY_PATH%/*}"

  local SOURCE_ICON="${_arg_destination%/}/${PRODUCT_ICONPATH:-Help/UnrealEd.ico}"
  local ICON_NAME
  ICON_NAME=$(__step::xdg_desktop_entry::get_icon_name "${SOURCE_ICON}" "OldUnreal_${PRODUCT_SHORTNAME}_UnrealEd" || echo "${SOURCE_ICON}")

  # Create destination folder if it doesn't exist
  if [[ ! -d "${DESKTOP_ENTRY_FOLDER}" ]]; then
    mkdir -p "${DESKTOP_ENTRY_FOLDER}" 2>/dev/null
  fi

  {
    echo "[Desktop Entry]"
    echo "Name=UnrealEd for ${PRODUCT_NAME}"

    echo "Exec="'"'"${_arg_destination%/}/System${UEED_SYSTEM_FOLDER_SUFFIX:-}/UnrealEd-launch-linux.sh"'"'

    echo "Icon=${ICON_NAME}"
    echo "Terminal=false"
    echo "Type=Application"
    echo "Categories=Game;"
  } >"${DESKTOP_ENTRY_PATH}"
}

# Automatically create png files from .ico for DEs that don't support Windows icons
declare -A STEP_XDG_DESKTOP_ENTRY_ICONS=()
__step::xdg_desktop_entry::get_icon_name() {
  local ICON_PATH="${1:-}"
  local TARGET_ICON_NAME="${2:-}"

  if [[ -n "${STEP_XDG_DESKTOP_ENTRY_ICONS[${ICON_PATH}]:-}" ]]; then
    echo "${STEP_XDG_DESKTOP_ENTRY_ICONS[${ICON_PATH}]}"
    return 0
  fi

  if [[ ! -f "${ICON_PATH}" ]]; then
    return 1
  fi

  if ! command -v magick &>/dev/null; then
    STEP_XDG_DESKTOP_ENTRY_ICONS[${ICON_PATH}]="${ICON_PATH}"
    echo "${ICON_PATH}"
    return 0
  fi

  local XDG_UNREAL_ICONS_PATH="${XDG_DATA_HOME:-${HOME}/.local/share}/icons/hicolor"

  local IS_48PX_FOUND="no"
  local IS_32PX_FOUND="no"
  local INDIVIDUAL_ICON_INFO
  local REGEX_ICON_INFO='^([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+)$'

  local ICON_INFORMATION
  ICON_INFORMATION=$(magick identify -format "%p %h %z %k\n" "${ICON_PATH}" | sort -k3nr -k2nr -k4nr)

  while IFS= read -r INDIVIDUAL_ICON_INFO; do
    if [[ "${INDIVIDUAL_ICON_INFO}" =~ ${REGEX_ICON_INFO} ]]; then
      local ICON_INDEX="${BASH_REMATCH[1]}"
      local ICON_SIZE="${BASH_REMATCH[2]}"

      case "${ICON_SIZE}" in
      48)
        if [[ "${IS_48PX_FOUND}" == "yes" ]]; then
          continue
        fi
        IS_48PX_FOUND="yes"

        mkdir -p "${XDG_UNREAL_ICONS_PATH}/48x48/apps"
        magick -quiet "${ICON_PATH}[${ICON_INDEX}]" "${XDG_UNREAL_ICONS_PATH}/48x48/apps/${TARGET_ICON_NAME}.png" >/dev/null

        STEP_XDG_DESKTOP_ENTRY_ICONS[${ICON_PATH}]="${TARGET_ICON_NAME}"
        ;;
      32)
        if [[ "${IS_32PX_FOUND}" == "yes" ]]; then
          continue
        fi
        IS_32PX_FOUND="yes"

        mkdir -p "${XDG_UNREAL_ICONS_PATH}/32x32/apps"
        magick -quiet "${ICON_PATH}[${ICON_INDEX}]" "${XDG_UNREAL_ICONS_PATH}/32x32/apps/${TARGET_ICON_NAME}.png" >/dev/null

        STEP_XDG_DESKTOP_ENTRY_ICONS[${ICON_PATH}]="${TARGET_ICON_NAME}"
        ;;
      esac
    fi
  done <<<"${ICON_INFORMATION}"

  if [[ -n "${STEP_XDG_DESKTOP_ENTRY_ICONS[${ICON_PATH}]:-}" ]]; then
    echo "${STEP_XDG_DESKTOP_ENTRY_ICONS[${ICON_PATH}]}"
  else
    STEP_XDG_DESKTOP_ENTRY_ICONS[${ICON_PATH}]="${ICON_PATH}"
    echo "${ICON_PATH}"
  fi
}
