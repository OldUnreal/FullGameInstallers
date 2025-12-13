# shellcheck shell=bash

step::unrealgold_correct_casing() {
  term::step::new "Correct File Casing"

  local FOLDERS_TO_FIX=(
    "HELP|Help"
    "MANUALS|Manuals"
    "MAPS|Maps"
    "MUSIC|Music"
    "SOUNDS|Sounds"
    "SYSTEM|System"
    "TEXTURES|Textures"
  )

  local FOLDER_PAIR

  for FOLDER_PAIR in "${FOLDERS_TO_FIX[@]}"
  do
    local FOLDER_UCASE="${FOLDER_PAIR%|*}"
    local FOLDER_TARGET="${FOLDER_PAIR#*|}"

    term::step::progress "${FOLDER_TARGET}"

    mkdir -p "${_arg_destination%/}/${FOLDER_TARGET}" 2>/dev/null || { 
      term::step::failed_with_error "User does not have permission to create the target folder (${FOLDER_TARGET}). Aborting installation."
      return 77 #E_PERM
    }

    cp -rf "${_arg_destination%/}/Installer/.staging/${FOLDER_UCASE}/"* "${_arg_destination%/}/${FOLDER_TARGET}/" 2>/dev/null || {
      term::step::failed_with_error "Failed to copy file to target folder (${FOLDER_TARGET}). Aborting installation."
      return 77 #E_PERM
    }
  done

  term::step::progress "Removing extra files"
  rm -rf "${_arg_destination%/}/Installer/.staging" || { 
    term::step::failed_with_error "Failed to remove staging files. Aborting installation."
    return 77 #E_PERM
  }

  term::step::complete
}
