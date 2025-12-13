#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR

# Do not execute this script unless bootstrapped from the main install runner
if [ -z "${_SCRIPT_DIR:-}" ]; then
  exit
fi

# Ensure required variables exist
if [ -z "${WGET_BIN:-}" ]; then
  exit 1
fi

installer::download::text() {
  if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
    return 1
  fi

  local FILENAME="${2##*/}"

  if [ -z "${3:-}" ]; then
    echo "- Downloading ${FILENAME}..."
    echo ""
  else 
    echo "- Downloading ${FILENAME} (alternate)..."
    echo ""
  fi

  "${WGET_BIN}" -nv --show-progress "${1}" -O "${2}"
}

installer::download::zenity() {
  if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
    return 1
  fi

  local FILENAME="${2##*/}"

  # wget2 doesn't implement --progress=dot
  if [ "${WGET_BIN}" == "wget2" ]; then
    "${WGET_BIN}" --progress=bar "${1}" -O "${2}" | { trap 'pkill -g 0' HUP; zenity --progress --pulsate --text="Downloading ${FILENAME}..." --auto-close --auto-kill 2>/dev/null; }
    return
  fi

  local TOTAL_SIZE PERCENT CURRENT SPEED

  "${WGET_BIN}" --progress=dot "${1}" -O "${2}" 2>&1 | while IFS= read -r transferProgress; do
    if echo "${transferProgress}" | grep -qE '^Length:'; then
      TOTAL_SIZE=$(echo "${transferProgress}" | sed -E 's/.*\((.*)\).*/\1/' | tr -d '()')
    fi

    if echo "${transferProgress}" | grep -qE '[0-9]+%' && [ -n "${TOTAL_SIZE:-}" ]; then
      PERCENT=$(echo "${transferProgress}" | grep -oE '[0-9]+%' | tr -d '%')
      CURRENT=$(echo "${transferProgress}" | sed -E 's/\s*([0-9]+[BKMG]).*/\1/')
      SPEED=$(echo "${transferProgress}" | sed -E 's/.*%\s+([0-9.]+[BKMG]).*/\1/')

      echo "${PERCENT}"
      # shellcheck disable=SC2028 # Wanted for Zenity
      echo "# Downloading ${FILENAME}\n${CURRENT} of ${TOTAL_SIZE} (${PERCENT}%)\nSpeed : ${SPEED}/s"
    fi
  done | { trap 'pkill -g 0' HUP; zenity --progress --percentage=0 --text="Starting download..." --time-remaining --auto-close --auto-kill 2>/dev/null; }
}
