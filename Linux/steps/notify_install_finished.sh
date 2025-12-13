#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR

# Do not execute this script unless bootstrapped from the main install runner
if [ -z "${_SCRIPT_DIR:-}" ]; then
  exit
fi

# Ensure required variables exist
if [ -z "${fore[*]:-}" ] \
   || [ -z "${style[*]:-}" ] \
   || [ -z "${PRODUCT_NAME:-}" ] \
   || [ -z "${MAIN_BINARY_NAME:-}" ] \
   || [ -z "${INSTALL_DIRECTORY:-}" ] \
   || [ -z "${INSTALL_DIRECTORY_DISPLAY:-}" ] \
   || [ -z "${ARCHITECTURE_TAG:-}" ] \
   || [ -z "${INSTALLATION_MODE:-}" ]; then
  exit 1
fi

installer_step::notify_install_finished() {
  if [ "${_arg_keep_installer_files:-off}" != "on" ] && [ -d "${INSTALL_DIRECTORY}/Installer" ]; then
    rm -rf "${INSTALL_DIRECTORY}/Installer"
  fi

  installer::banner "OldUnreal ${PRODUCT_NAME} Linux Installer"
  echo
  echo "${PRODUCT_NAME} is now installed!"
  echo
  echo "You can launch the game by running:"
  echo "  ${INSTALL_DIRECTORY_DISPLAY}/System${SYSTEM_FOLDER_TAG:-}/${MAIN_BINARY_NAME}-${ARCHITECTURE_TAG}"

  if [ "${INSTALLATION_MODE}" == "zenity" ]; then
    local DIALOG_TEXT="""
${PRODUCT_NAME} is now installed!

You can launch the game by running:

  ${INSTALL_DIRECTORY_DISPLAY}/System${SYSTEM_FOLDER_TAG:-}/${MAIN_BINARY_NAME}-${ARCHITECTURE_TAG}
"""
    zenity --info --width=400 "--text=${DIALOG_TEXT}" 2>/dev/null
  else
    echo
  fi
}
