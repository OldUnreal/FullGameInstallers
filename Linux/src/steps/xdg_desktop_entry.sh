# shellcheck shell=bash

step::xdg_desktop_entry() {
  local STEP_NAME="${1:-}"
  local STEP_PROMPT="${2:-}"
  local DESKTOP_ENTRY_PATH="${3:-}"
  local APPLICATION_ENTRY_HANDLING_MODE="${4:-}"
  local SKIP_IF_ENTRY_FOLDER_DOESNT_EXIST="${5:-no}"

  if [[ -z "${STEP_NAME}" ]] || [[ -z "${STEP_PROMPT}" ]] || [[ -z "${DESKTOP_ENTRY_PATH}" ]] || [[ -z "${APPLICATION_ENTRY_HANDLING_MODE}" ]]; then
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
  term::step::complete
}

__step::xdg_desktop_entry::create() {
  local DESKTOP_ENTRY_PATH="${1:-}"

  if [[ -z "${DESKTOP_ENTRY_PATH}" ]]; then
    return 1
  fi

  local DESKTOP_ENTRY_FOLDER="${DESKTOP_ENTRY_PATH%/*}"

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

    echo "Exec="'"'"${_arg_destination%/}/System${UE_SYSTEM_FOLDER_SUFFIX:-}/${MAIN_BINARY_NAME}${ARCHITECTURE_BINARY_SUFFIX}"'"'
    echo "Icon=${_arg_destination%/}/${PRODUCT_ICONPATH:-Help/Unreal.ico}"
    echo "Terminal=false"
    echo "Type=Application"
    echo "Categories=Game;"
  } >"${DESKTOP_ENTRY_PATH}"
}
