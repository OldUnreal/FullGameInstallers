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
   || [ -z "${ARCHITECTURE_TAG:-}" ] \
   || [ -z "${INSTALLATION_MODE:-}" ]; then
  exit 1
fi

installer_step::unpack_uz_maps() {
  "installer_step::unpack_uz_maps::${INSTALLATION_MODE}"
}

installer_step::unpack_uz_maps::text() {
  SHOW_PROGRESS="${1:-off}"

  UCC_BIN_PATH="${INSTALL_DIRECTORY}/System${SYSTEM_FOLDER_TAG:-}/ucc-bin-${ARCHITECTURE_TAG}"

  MAP_FILES=()

  for MAP_FILE in "${INSTALL_DIRECTORY}"/Maps/*.unr.uz
  do
    MAP_BASENAME="${MAP_FILE##*/}"
    MAP_FILES+=("${MAP_BASENAME}")
  done

  TOTAL_MAP_FILES="${#MAP_FILES[@]}"
  MAP_FILES_PROCESSED=0

  for MAP_FILE in "${MAP_FILES[@]}"
  do
    MAP_BASENAME_UNCOMPRESSED="${MAP_FILE%.uz}"

    COMPRESSED_FILE="${INSTALL_DIRECTORY}/Maps/${MAP_FILE}"
    DECOMPRESS_STAGING="${INSTALL_DIRECTORY}/System${SYSTEM_FOLDER_TAG:-}/${MAP_BASENAME_UNCOMPRESSED}"
    DECOMPRESS_TARGET="${INSTALL_DIRECTORY}/Maps/${MAP_BASENAME_UNCOMPRESSED}"

    if [ "${SHOW_PROGRESS}" == "on" ]; then
      echo "$(((MAP_FILES_PROCESSED * 100)/TOTAL_MAP_FILES))"
      echo "#Decompressing ${MAP_FILE}..."
    else
      echo "- Decompressing ${MAP_FILE} (${MAP_FILES_PROCESSED}/${TOTAL_MAP_FILES})"
    fi

    "${UCC_BIN_PATH}" decompress "../Maps/${MAP_FILE}" -nohomedir &>/dev/null

    if [ -f "${DECOMPRESS_STAGING}" ]; then
      mv -f "${DECOMPRESS_STAGING}" "${DECOMPRESS_TARGET}"
      rm -f "${COMPRESSED_FILE}"
    else
      installer::abort_on_error "Unable to decompress ${MAP_BASENAME}.uz. Cannot continue"
    fi

    MAP_FILES_PROCESSED=$((MAP_FILES_PROCESSED+1))
  done

  if [ "${SHOW_PROGRESS}" == "on" ]; then
    echo "100"
  fi
}

installer_step::unpack_uz_maps::zenity() {
  (
    installer_step::unpack_uz_maps::text on
  ) | { trap 'pkill -g 0' HUP; zenity --progress --text="Unpacking compressed maps..." --no-cancel --auto-close 2>/dev/null; }
}
