# shellcheck shell=bash

step::notify_install_finished() {
  # Remove installation files
  if [[ "${_arg_keep_installer_files:-off}" != "on" ]] && [[ -d "${_arg_destination%/}/Installer" ]]; then
    rm -rf "${_arg_destination%/}/Installer"
  fi

  echo
  echo -e "$(ansi::styled "${PRODUCT_NAME}" "${ansi_stylenum[bright]}" "${ansi_colornum[green]}") $(ansi::styled "is now installed!" "" "${ansi_colornum[green]}")"
  echo
  echo "You can launch the game by running:"
  echo "  ${DESTINATION_HOMIFIED}/System${UE_SYSTEM_FOLDER_SUFFIX:-}/${MAIN_BINARY_NAME}${ARCHITECTURE_BINARY_SUFFIX}"

  local DIALOG_TEXT="""
${PRODUCT_NAME} is now installed!

You can launch the game by running:

  ${DESTINATION_HOMIFIED}/System${UE_SYSTEM_FOLDER_SUFFIX:-}/${MAIN_BINARY_NAME}${ARCHITECTURE_BINARY_SUFFIX}
"""

  if [[ "${_arg_ui_mode:-none}" == "none" ]]; then
    return 0
  elif [[ "${_arg_ui_mode:-none}" == "kdialog" ]]; then
    DIALOG_ARGS=(
      kdialog
      --msgbox
      "${DIALOG_TEXT}"
    )
  elif [[ "${_arg_ui_mode:-none}" == "zenity" ]]; then
    DIALOG_ARGS=(
      zenity
      --info
      --width=400
      "--text=${DIALOG_TEXT}"
    )
  fi

  "${DIALOG_ARGS[@]}" &>/dev/null || true
}
