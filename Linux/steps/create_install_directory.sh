#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR

# Do not execute this script unless bootstrapped from the main install runner
if [ -z "${_SCRIPT_DIR:-}" ]; then
  exit
fi

if [ -z "${_arg_directory:-}" ] \
   || [ -z "${PRODUCT_SHORTNAME:-}" ] \
   || [ -z "${INSTALLATION_MODE:-}" ]; then
  exit 1
fi

INSTALL_DIRECTORY=""
INSTALL_DIRECTORY_DISPLAY=""

installer_step::create_install_directory() {
  # Check if current directory is _SCRIPTDIR
  if [ "${_SCRIPT_DIR}" == "$(pwd)" ] && [[ "${_arg_directory}" == ./* ]]; then
    if [ "${INSTALLATION_MODE}" == "zenity" ]; then
      _arg_directory=$(zenity --file-selection --directory --save --title="Choose installation directory" 2>/dev/null)

      _arg_directory="${_arg_directory}/${PRODUCT_SHORTNAME}"

      if ! zenity --width=450 \
          --question \
          --text="Do you want to install this product at the following path?\n  ${_arg_directory}" 2>/dev/null; then
        return 1
      fi
    else
      installer::abort_on_error "You may not install in the bin/ directory of the installer, please specify --directory or change current directory."
    fi
  fi

  mkdir -p "${_arg_directory}"

  # shellcheck disable=SC2034 # Used in other steps as an output
  INSTALL_DIRECTORY=$(realpath "${_arg_directory}")

  # Create a display version of the install directory
  INSTALL_DIRECTORY_DISPLAY="${INSTALL_DIRECTORY}"
  ([[ "${INSTALL_DIRECTORY_DISPLAY}" =~ ^"${HOME}"(/|$) ]] && INSTALL_DIRECTORY_DISPLAY="~${INSTALL_DIRECTORY_DISPLAY#"${HOME}"}") || true
}
