#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR

# Do not execute this script unless bootstrapped from the main install runner
if [ -z "${_SCRIPT_DIR:-}" ]; then
  exit
fi

# Import colr library
# shellcheck source=SCRIPTDIR/colr.sh
source "${_SCRIPT_DIR}/../lib/colr.sh"

INSTALLATION_MODE="text"

# If Zenity is discoverable on the machine,
# and we have a DISPLAY available
# and we are not in an SSH session
# or we have not manually disabled the UI
#
# Use zenity as the installer mode
if type "zenity" &>/dev/null \
  && { [ -n "${DISPLAY:-}" ] || [ -z "${WAYLAND_DISPLAY:-}" ]; } \
  && ! { [ -n "${SSH_CLIENT:-}" ] || [ -n "${SSH_TTY:-}" ] || [ "${_arg_ui:-}" == "off" ]; }; then
  INSTALLATION_MODE="zenity"
fi

installer::abort_on_error() {
  EXIT_CODE="${2:-1}"

  if [ "${INSTALLATION_MODE}" == "zenity" ]; then
    zenity --error --text "${1}" --width=300 2>/dev/null
  else
    echo -e "${style[bright]}${fore[red]}Error: ${style[reset]}${1}" 1>&2
  fi

  exit "${EXIT_CODE}"
}

installer::run() {
  for i in "${INSTALLATION_STEPS[@]}"
  do
    if [ ! -f "${_SCRIPT_DIR}/../steps/${i}.sh" ]; then
      installer::abort_on_error "Step ${i} could not be found. Installation cannot continue."
    fi

    # shellcheck disable=SC1090
    source "${_SCRIPT_DIR}/../steps/${i}.sh"
    "installer_step::$i"
  done
}

installer::banner() {
  local TOPEDGE BOTTOMEDGE
  TOPEDGE="┏━${1//?/━}━┓"
  BOTTOMEDGE="┗━${1//?/━}━┛"

  echo "${style[bright]}${TOPEDGE}"
  echo "┃ ${1} ┃"
  echo "${BOTTOMEDGE}${style[reset]}"
}

case $(uname -m) in
  x86_64)
    ARCHITECTURE_TAG='amd64'
    SYSTEM_FOLDER_TAG='64'
    ;;
  aarch64)
    ARCHITECTURE_TAG='arm64'
    SYSTEM_FOLDER_TAG='ARM64'
    ;;
  i386)
    ARCHITECTURE_TAG='x86'
    SYSTEM_FOLDER_TAG=''
    ;;
  i686)
    # shellcheck disable=SC2034 # Used in sourced script
    ARCHITECTURE_TAG='x86'
    # shellcheck disable=SC2034 # Used in sourced script
    SYSTEM_FOLDER_TAG=''
    ;;
  *)
    installer::abort_on_error "Unable to determine system architecture"
    ;;
esac
