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
  local UE_OLD_SYSTEM_SUFFIXES=(64 ARM64)
  local UE_OLD_SYSTEM_SUFFIX OLD_SYS_FILE OLD_SYS_BASENAME
  for UE_OLD_SYSTEM_SUFFIX in "${UE_OLD_SYSTEM_SUFFIXES[@]}"; do
    if [[ ! -d "${_arg_destination%/}/System${UE_OLD_SYSTEM_SUFFIX}" ]]; then
      continue
    fi

    # An old folder that is the main one (a symbolic link, in either direction) has nothing to migrate, and
    # its files must not be treated as leftovers. Only the link itself is removed.
    if [[ "$(realpath -m "${_arg_destination%/}/System${UE_OLD_SYSTEM_SUFFIX}")" == "$(realpath -m "${_arg_destination%/}/System")" ]]; then
      if [[ -L "${_arg_destination%/}/System${UE_OLD_SYSTEM_SUFFIX}" ]]; then
        rm -f "${_arg_destination%/}/System${UE_OLD_SYSTEM_SUFFIX}"
      fi
      continue
    fi

    # Move everything that isn't already in the main System folder. When the old folder is a symbolic link, the
    # folder it points to isn't ours and other installations may use it: its content is copied, not taken out.
    for OLD_SYS_FILE in "${_arg_destination%/}/System${UE_OLD_SYSTEM_SUFFIX}"/*; do
      # The glob is returned as is when the folder is empty
      if [[ ! -e "${OLD_SYS_FILE}" ]] && [[ ! -L "${OLD_SYS_FILE}" ]]; then
        continue
      fi

      OLD_SYS_BASENAME="${OLD_SYS_FILE##*/}"

      if [[ -e "${_arg_destination%/}/System/${OLD_SYS_BASENAME}" ]]; then
        # Files already present in the main System folder win, the old copy is a leftover. This is not done
        # through a symbolic link, the folder it points to isn't ours.
        if [[ -f "${OLD_SYS_FILE}" ]] && [[ ! -L "${_arg_destination%/}/System${UE_OLD_SYSTEM_SUFFIX}" ]]; then
          rm -f "${OLD_SYS_FILE}"
        fi
        continue
      fi

      if [[ -L "${_arg_destination%/}/System${UE_OLD_SYSTEM_SUFFIX}" ]]; then
        cp -a -- "${OLD_SYS_FILE}" "${_arg_destination%/}/System/${OLD_SYS_BASENAME}" || {
          term::step::failed_with_error "Failed to copy ${OLD_SYS_BASENAME} from System${UE_OLD_SYSTEM_SUFFIX} to System. Aborting installation."
          return 77 #E_PERM
        }
      else
        mv -f "${OLD_SYS_FILE}" "${_arg_destination%/}/System/${OLD_SYS_BASENAME}" || {
          term::step::failed_with_error "Failed to move ${OLD_SYS_BASENAME} from System${UE_OLD_SYSTEM_SUFFIX} to System. Aborting installation."
          return 77 #E_PERM
        }
      fi
    done

    # Only remove the old folder once it is empty, folders present in both locations are left alone.
    # A symbolic link to another folder is removed without touching what it points to.
    if [[ -L "${_arg_destination%/}/System${UE_OLD_SYSTEM_SUFFIX}" ]]; then
      rm -f "${_arg_destination%/}/System${UE_OLD_SYSTEM_SUFFIX}"
    else
      rmdir "${_arg_destination%/}/System${UE_OLD_SYSTEM_SUFFIX}" 2>/dev/null || true
    fi
  done

  term::step::complete
}
