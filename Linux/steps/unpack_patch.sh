#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR

# Do not execute this script unless bootstrapped from the main install runner
if [ -z "${_SCRIPT_DIR:-}" ]; then
  exit
fi

# Ensure required variables exist
if [ -z "${fore[*]:-}" ] \
   || [ -z "${style[*]:-}" ] \
   || [ -z "${INSTALL_DIRECTORY:-}" ] \
   || [ -z "${PATCH_DOWNLOAD_PATH:-}" ] \
   || [ -z "${INSTALLATION_MODE:-}" ]; then
  exit 1
fi

installer_step::unpack_patch() {
  "installer_step::unpack_patch::${INSTALLATION_MODE}"
}

installer_step::unpack_patch::text() {
  echo "- Installing patch..."
  echo

  tar -xf "${PATCH_DOWNLOAD_PATH}" -C "${INSTALL_DIRECTORY}/" --overwrite
}

installer_step::unpack_patch::zenity() {
  (
    installer_step::unpack_patch::text >/dev/null
    echo "100"
  ) | { trap 'pkill -g 0' HUP; zenity --progress --pulsate --text="Installing patch..." --no-cancel --auto-close --auto-kill 2>/dev/null; }
}
