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
   || [ -z "${INSTALLATION_MODE:-}" ]; then
  exit 1
fi

installer_step::welcome_banner() {
  installer::banner "OldUnreal ${PRODUCT_NAME} Linux Installer"
  echo

  if [ "${INSTALLATION_MODE}" == "zenity" ]; then
    echo "Installer is running in GUI mode. If no window is displayed,"
    echo "type CTRL+C to kill the installer, and start it with the --no-ui"
    echo "argument."
    echo
  fi
}
