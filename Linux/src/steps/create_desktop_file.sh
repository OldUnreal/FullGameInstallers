# shellcheck shell=bash

step::create_desktop_file() {
  if [ "${_arg_ui_mode:-none}" == "none" ]; then
    __step::create_desktop_file::text
    return $?
  fi

  term::step::new ".desktop File"

  local DIALOG_TEXT="Do you want to create an application menu entry?"
  local DIALOG_ARGS=()

  if [ "${_arg_ui_mode:-none}" == "kdialog" ]; then
    DIALOG_ARGS=(
      kdialog
      --yesno
      "${DIALOG_TEXT}"
    )
  elif [ "${_arg_ui_mode:-none}" == "zenity" ]; then
    DIALOG_ARGS=(
      zenity
      --question
      "--text=${DIALOG_TEXT}"
    )
  fi

  if ! "${DIALOG_ARGS[@]}" &>/dev/null; then
    term::step::skipped "SKIPPED: User opted out"
    return 0
  fi

  __step::create_desktop_file::create_file
  term::step::complete
}

__step::create_desktop_file::text() {
  echo
  if ! term::yesno "Do you want to create an application menu entry?"; then
    echo
    term::step::new ".desktop File"
    term::step::skipped "SKIPPED: User opted out"
    return 0
  fi

  echo
  term::step::new ".desktop File"
  __step::create_desktop_file::create_file

  term::step::complete
}

__step::create_desktop_file::create_file() {
  local XDG_APPLICATIONS_FOLDER="${XDG_DATA_HOME:-${HOME}/.local/share}/applications"

  mkdir -p "${XDG_APPLICATIONS_FOLDER}" 2>/dev/null || { 
    term::step::failed_with_error "User does not have permission to create folder."
    return 77 #E_PERM
  }

  DESKTOP_ENTRY="${XDG_APPLICATIONS_FOLDER}/OldUnreal-${PRODUCT_SHORTNAME}.desktop"

  {
    echo "[Desktop Entry]"
    echo "Name=${PRODUCT_NAME}"
    echo "Exec="'"'"${_arg_destination%/}/System${UE_SYSTEM_FOLDER_SUFFIX:-}/${MAIN_BINARY_NAME}-${ARCHITECTURE_SUFFIX}"'"'
    echo "Icon=${_arg_destination%/}/${PRODUCT_ICONPATH:-Help/Unreal.ico}"
    echo "Terminal=false"
    echo "Type=Application"
    echo "Categories=Game;"
  } > "${DESKTOP_ENTRY}" || { 
    term::step::failed_with_error "User does not have permission to create .desktop file."
    return 77 #E_PERM
  }
}
