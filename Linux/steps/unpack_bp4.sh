#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR

# Do not execute this script unless bootstrapped from the main install runner
if [ -z "${_SCRIPT_DIR:-}" ]; then
  exit
fi

# Ensure required variables exist
if [ -z "${fore[*]:-}" ] \
   || [ -z "${style[*]:-}" ] \
   || [ -z "${SEVENZIP_BIN:-}" ] \
   || [ -z "${INSTALL_DIRECTORY:-}" ] \
   || [ -z "${DOWNLOADS_FILENAME_LIST:-}" ] \
   || [ -z "${INSTALLATION_MODE:-}" ]; then
  exit 1
fi

installer_step::unpack_bp4() {
  "installer_step::unpack_bp4::${INSTALLATION_MODE}"
}

installer_step::unpack_bp4::text() {
  mkdir -p "${INSTALL_DIRECTORY}/Installer"

  BP4_DOWNLOAD_PATH="${INSTALL_DIRECTORY}/Installer/${DOWNLOADS_FILENAME_LIST[1]}"

  echo "- Unpacking Bonus Pack 4..."
  echo

  SEVENZ_ARGS=("-y" "-o${INSTALL_DIRECTORY}")

  "${SEVENZIP_BIN}" x "${BP4_DOWNLOAD_PATH}" "${SEVENZ_ARGS[@]}"
  echo
}

installer_step::unpack_bp4::zenity() {
  (
    installer_step::unpack_bp4::text >/dev/null
    echo "100"
  ) | { trap 'pkill -g 0' HUP; zenity --progress --pulsate --text="Unpacking files from install media..." --no-cancel --auto-close --auto-kill 2>/dev/null; }
}
