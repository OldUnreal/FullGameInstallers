#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR

# Do not execute this script unless bootstrapped from the main install runner
if [ -z "${_SCRIPT_DIR:-}" ]; then
  exit
fi

# Ensure required variables exist
if [ -z "${fore[*]:-}" ] \
   || [ -z "${style[*]:-}" ] \
   || [ -z "${INSTALLATION_MODE:-}" ]; then
  exit 1
fi

installer_step::check_dependencies() {
  MISSING_DEPENDENCIES=()

  if ! type 7z &>/dev/null; then
    MISSING_DEPENDENCIES+=("p7zip-full or p7zip (depends on distro)")
  fi

  if ! type jq &>/dev/null; then
    MISSING_DEPENDENCIES+=("jq")
  fi

  if ! type tar &>/dev/null; then
    MISSING_DEPENDENCIES+=("tar")
  fi

  if ! type wget &>/dev/null; then
    MISSING_DEPENDENCIES+=("wget")
  fi

  if ! type unzip &>/dev/null; then
    MISSING_DEPENDENCIES+=("unzip")
  fi

  if [ "${#MISSING_DEPENDENCIES[@]}" -gt 0 ]; then
    DIALOG_TEXT="Missing required dependencies.\n\nPlease install the following required packages:\n"

    echo -e "${style[bright]}${fore[red]}Error: ${style[reset]}Missing required dependencies." 1>&2
    echo 
    echo "Please install the following required packages:" 1>&2

    for i in "${MISSING_DEPENDENCIES[@]}"
    do
      echo "  - ${i}"
      DIALOG_TEXT="${DIALOG_TEXT}\n  - ${i}"
    done

    if [ "${INSTALLATION_MODE}" == "zenity" ]; then
      echo -e "${DIALOG_TEXT}" | zenity --text-info --width=400 --height=350 2>/dev/null
    fi

    exit 2
  fi
}
