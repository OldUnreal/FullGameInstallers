# shellcheck shell=bash

local DESTINATION_HOMIFIED=""

# shellcheck disable=SC2034 # Used in some installers
local IS_DESTINATION_CASE_SENSITIVE_FS=""

step::check_destination() {
  term::step::new "Checking Destination Folder"

  if [[ -z "${_arg_destination:-}" ]]; then
    term::step::failed_with_error "No destination folder set. Aborting installation."
    return 78
  fi

  if [[ -d "${_arg_destination}" ]] && [[ ! -w "${_arg_destination}" ]]; then
    term::step::failed_with_error "Destination folder not writable by user. Aborting installation."
    return 77 #E_PERM
  elif [[ ! -d "${_arg_destination}" ]]; then
    # Create folder if it doesn't exist
    mkdir -p "${_arg_destination}" &>/dev/null || {
      term::step::failed_with_error "User does not have permission to create destination folder. Aborting installation."
      return 77 #E_PERM
    }
  fi

  _arg_destination="$(realpath "${_arg_destination}")"

  if [[ ! -d "${_arg_destination%/}/Installer" ]]; then
    # Create the installation folder
    mkdir -p "${_arg_destination%/}/Installer" &>/dev/null || {
      term::step::failed_with_error "User does not have permission to create destination folder. Aborting installation."
      return 77 #E_PERM
    }
  fi

  if [[ ! -w "${_arg_destination%/}/Installer" ]]; then
    term::step::failed_with_error "The ./Installer subfolder of the destination cannot be written by this user."
    return 77 #E_PERM
  fi

  # Check Case-Sensitivity
  {
    if [[ -f "${_arg_destination%/}/Installer/.check_casesensitive" ]]; then
      rm -f "${_arg_destination%/}/Installer/.check_casesensitive"
    fi

    if [[ ! -f "${_arg_destination%/}/Installer/.Check_caseSensitive" ]]; then
      touch "${_arg_destination%/}/Installer/.Check_caseSensitive"
    fi

    if [[ -f "${_arg_destination%/}/Installer/.check_casesensitive" ]]; then
      # shellcheck disable=SC2034 # Used in some installers
      IS_DESTINATION_CASE_SENSITIVE_FS="no"
    else
      # shellcheck disable=SC2034 # Used in some installers
      IS_DESTINATION_CASE_SENSITIVE_FS="yes"
    fi

    rm -f "${_arg_destination%/}/Installer/.Check_caseSensitive"
  } || {
    term::step::failed_with_error "Unable to determine case sensitivity. Aborting installation."
    return 77 #E_PERM
  }

  DESTINATION_HOMIFIED="${_arg_destination}"
  { [[ "${DESTINATION_HOMIFIED}" =~ ^"${HOME}"(/|$) ]] && DESTINATION_HOMIFIED="~${_arg_destination#"${HOME}"}"; } || true

  term::step::complete
}
