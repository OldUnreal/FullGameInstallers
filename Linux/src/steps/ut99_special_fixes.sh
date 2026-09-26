# shellcheck shell=bash

step::ut99_special_fixes() {
  term::step::new "Apply UT:GOTY Specific Fixes"

  # DM-Cybrosis][ is both a DM and a DOM map
  if [[ -f "${_arg_destination%/}/Maps/DM-Cybrosis][.unr" ]] && [[ ! -f "${_arg_destination%/}/Maps/DOM-Cybrosis][.unr" ]]; then
    cp -f "${_arg_destination%/}/Maps/DM-Cybrosis][.unr" "${_arg_destination%/}/Maps/DOM-Cybrosis][.unr" || {
      term::step::failed_with_error "Failed to copy DM-Cybrosis][.unr to DOM-Cybrosis][.unr. Aborting installation."
      return 77 #E_PERM
    }
  fi

  # Migrate old Architecture Specific Folders from old patches to the regular System folder
  UE_OLD_SYSTEM_SUFFIXES=(64 ARM64)
  for UE_OLD_SYSTEM_SUFFIX in "${UE_OLD_SYSTEM_SUFFIXES[@]}"; do
    if [[ ! -d "${_arg_destination%/}/System${UE_OLD_SYSTEM_SUFFIX}" ]]; then
      continue
    fi

    # Iterate through all files (ignoring subfolders)
    for OLD_SYS_FILE in "${_arg_destination%/}/System${UE_OLD_SYSTEM_SUFFIX}"/*; do
      # If it isn't a regular file, ignore
      if [[ ! -f "${OLD_SYS_FILE}" ]]; then
        continue
      fi

      OLD_SYS_BASENAME="${OLD_SYS_FILE##*/}"

      # If the file already exists in the main System folder, we don't want to overwrite it
      if [[ -f "${_arg_destination%/}/System/${OLD_SYS_BASENAME}" ]]; then
        continue
      fi

      mv -f "${OLD_SYS_FILE}" "${_arg_destination%/}/System/${OLD_SYS_BASENAME}" || {
        term::step::failed_with_error "Failed to move ${OLD_SYS_BASENAME} from System${UE_OLD_SYSTEM_SUFFIX} to System. Aborting installation."
        return 77 #E_PERM
      }
    done

    rm -rf "${_arg_destination%/}/System${UE_OLD_SYSTEM_SUFFIX}" || {
      term::step::failed_with_error "Failed to remove System${UE_OLD_SYSTEM_SUFFIX} folder. Aborting installation."
      return 77 #E_PERM
    }
  done

  term::step::complete
}
