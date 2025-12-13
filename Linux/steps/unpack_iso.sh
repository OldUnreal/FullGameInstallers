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
   || [ -z "${DOWNLOADS_FILENAME_LIST:-}" ] \
   || [ -z "${INSTALLATION_MODE:-}" ]; then
  exit 1
fi

installer_step::unpack_iso() {
  "installer_step::unpack_iso::${INSTALLATION_MODE}"
}

installer_step::unpack_iso::text() {
  mkdir -p "${INSTALL_DIRECTORY}/Installer"

  ISO_DOWNLOAD_PATH="${INSTALL_DIRECTORY}/Installer/${DOWNLOADS_FILENAME_LIST[0]}"

  echo "- Unpacking files from install media..."
  echo

  UNPACK_DESTINATION_FOLDER="${INSTALL_DIRECTORY}"

  if [ "${UNPACK_REQUEST_STAGING:-off}" == "on" ]; then
    UNPACK_DESTINATION_FOLDER="${INSTALL_DIRECTORY}/Installer/.staging"
    mkdir -p "${UNPACK_DESTINATION_FOLDER}"
  fi

  SEVENZ_ARGS=("-y" "-o${UNPACK_DESTINATION_FOLDER}")

  if [ -n "${UNPACK_IGNORE_PATTERNS[*]:-}" ]; then
    for i in "${UNPACK_IGNORE_PATTERNS[@]}"
    do
      SEVENZ_ARGS+=("-x!${i}")
    done
  fi

  if [ -n "${UNPACK_IGNORE_RECURSIVE_PATTERNS[*]:-}" ]; then
    for i in "${UNPACK_IGNORE_RECURSIVE_PATTERNS[@]}"
    do
      SEVENZ_ARGS+=("-xr!${i}")
    done
  fi

  7z x "${ISO_DOWNLOAD_PATH}" "${SEVENZ_ARGS[@]}"

  if [ "${UNPACK_REQUEST_STAGING:-off}" == "on" ]; then
    if type installer_step::unpack_iso::post_staging >/dev/null; then
      installer_step::unpack_iso::post_staging "${INSTALL_DIRECTORY}" "${UNPACK_DESTINATION_FOLDER}"
    else
      installer::abort_on_error "Asked for staging to unpacking, but no post_staging step defined."
    fi

    rm -rf "${UNPACK_DESTINATION_FOLDER}"
  fi

  echo
}

installer_step::unpack_iso::zenity() {
  (
    installer_step::unpack_iso::text >/dev/null
    echo "100"
  ) | { trap 'pkill -g 0' HUP; zenity --progress --pulsate --text="Unpacking files from install media..." --no-cancel --auto-close --auto-kill 2>/dev/null; }
}
