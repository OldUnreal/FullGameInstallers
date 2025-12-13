#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR

# Do not execute this script unless bootstrapped from the main install runner
if [ -z "${_SCRIPT_DIR:-}" ]; then
  exit
fi

if [ -z "${_arg_directory:-}" ] \
   || [ -z "${INSTALLATION_MODE:-}" ]; then
  exit 1
fi

INSTALL_DIRECTORY=""
INSTALL_DIRECTORY_DISPLAY=""

installer_step::create_install_directory() {
  mkdir -p "${_arg_directory:-}"

  # shellcheck disable=SC2034 # Used in other steps as an output
  INSTALL_DIRECTORY=$(realpath "${_arg_directory}")

  # Create a display version of the install directory
  INSTALL_DIRECTORY_DISPLAY="${INSTALL_DIRECTORY}"
  [[ "${INSTALL_DIRECTORY_DISPLAY}" =~ ^"${HOME}"(/|$) ]] && INSTALL_DIRECTORY_DISPLAY="~${INSTALL_DIRECTORY_DISPLAY#"${HOME}"}"
}
