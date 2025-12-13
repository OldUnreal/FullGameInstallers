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
   || [ -z "${PRODUCT_SHORTNAME:-}" ] \
   || [ -z "${INSTALL_DIRECTORY:-}" ] \
   || [ -z "${MAIN_BINARY_NAME:-}" ] \
   || [ -z "${INSTALLATION_MODE:-}" ]; then
  exit 1
fi

installer_step::create_desktop_entry() {
  "installer_step::create_desktop_entry::${INSTALLATION_MODE}"
}

installer_step::create_desktop_entry::text() {
  read -p "${style[bright]}${fore[green]}?${style[reset]} Do you want to create an application entry? ${style[bright]}[yN]${style[reset]} " -n 1 -r
  echo
  if [[ ! "$REPLY" =~ ^[Yy]$ ]]
  then
    return
  fi

  installer_step::create_desktop_entry::do_create
}

installer_step::create_desktop_entry::zenity() {
  if zenity --question --text="Do you want to create an application entry?" 2>/dev/null; then
    installer_step::create_desktop_entry::do_create
  fi
}

installer_step::create_desktop_entry::do_create() {
  XDG_APPLICATIONS_FOLDER="${XDG_DATA_HOME:-${HOME}/.local/share}/applications"

  mkdir -p "${XDG_APPLICATIONS_FOLDER}"

  DESKTOP_ENTRY="${XDG_APPLICATIONS_FOLDER}/OldUnreal-${PRODUCT_SHORTNAME}.desktop"

  {
    echo "[Desktop Entry]"
    echo "Name=${PRODUCT_NAME}"
    echo "Exec="'"'"${INSTALL_DIRECTORY}/System${SYSTEM_FOLDER_TAG:-}/${MAIN_BINARY_NAME}-${ARCHITECTURE_TAG}"'"'
    echo "Icon=${INSTALL_DIRECTORY}/${PRODUCT_ICONPATH:-Help/Unreal.ico}"
    echo "Terminal=false"
    echo "Type=Application"
    echo "Categories=Game;"
  } > "${DESKTOP_ENTRY}"
}
