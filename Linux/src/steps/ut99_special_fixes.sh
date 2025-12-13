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

  term::step::complete
}
