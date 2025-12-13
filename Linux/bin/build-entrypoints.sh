#!/usr/bin/env bash

# Enable Bash Strict Mode
set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || { echo "Couldn't determine the script's running directory, which probably matters, bailing out" >&2; exit 2; }
_SRC_ROOT="$(realpath "${_SCRIPT_DIR}/../src")"

while IFS= read -r -d '' ENTRYPOINT_FILE_PATH; do
  ENTRYPOINT_BASENAME=${ENTRYPOINT_FILE_PATH##*/}
  DESTINATION_FILE="${_SCRIPT_DIR}/../${ENTRYPOINT_BASENAME}"
  DESTINATION_SWAP="${_SCRIPT_DIR}/../${ENTRYPOINT_BASENAME}.swap"

  cp -f "${ENTRYPOINT_FILE_PATH}" "${DESTINATION_FILE}"
  
  while grep -Eq "^\s*#\s*include\s+" "${DESTINATION_FILE}"; do
      # Process the file and save to a swap file
      sed -Ee '/^\s*#\s*include/ {
          s|^\s*#\s*include\s+(.*)|cat "'"${_SRC_ROOT}"'/\1"|
          e
      }' "${DESTINATION_FILE}" > "${DESTINATION_SWAP}"
      
      # Move the expanded version back to the temp file for the next pass
      mv -f "${DESTINATION_SWAP}" "${DESTINATION_FILE}"
      break
  done

  if command -v shfmt >/dev/null; then 
    shfmt --indent 2 --write "${DESTINATION_FILE}"
  else
    echo "WARNING: file ${ENTRYPOINT_BASENAME} not reformatted since shfmt is unavailable" 1>&2
  fi

  chmod +x "${DESTINATION_FILE}"
done < <(find "${_SRC_ROOT}/entrypoints" -maxdepth 1 -name "*.sh" -print0)
