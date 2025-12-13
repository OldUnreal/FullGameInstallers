# shellcheck shell=bash

# This step is mostly provided in case a user installs on top of an existing install (from Steam for example)
step::remove_extra_i18n_files() {
  local I18N_IDENTIFIERS=(
    "ctt"
    "det"
    "elt"
    "est"
    "frt"
    "kot"
    "int"
    "itt"
    "nlt"
    "ptt"
    "rut"
    "smt"
    "tmt"
  )

  local SYS_LOCALIZED_PATH="${_arg_destination%/}/SystemLocalized"
  local SYS_PATH="${_arg_destination%/}/System"

  if [[ ! -d "${SYS_LOCALIZED_PATH}" ]]; then
    return 0
  fi

  term::step::new "Remove extra localization files"

  {
    local I18N_IDENTIFIER
    for I18N_IDENTIFIER in "${I18N_IDENTIFIERS[@]}"; do
      local LOC_FILES=()
      local LOC_FILE

      if [[ -d "${SYS_LOCALIZED_PATH}/${I18N_IDENTIFIER}" ]]; then
        for LOC_FILE in "${SYS_LOCALIZED_PATH}/${I18N_IDENTIFIER}/"*".${I18N_IDENTIFIER}"; do
          if [[ ! -f "${LOC_FILE}" ]]; then
            continue
          fi

          LOC_FILES+=("${LOC_FILE##*/}")
        done
      fi

      for LOC_FILE in "${SYS_LOCALIZED_PATH}/"*".${I18N_IDENTIFIER}"; do
        if [[ ! -f "${LOC_FILE}" ]]; then
          continue
        fi

        LOC_FILES+=("${LOC_FILE##*/}")
      done

      for LOC_FILE in "${LOC_FILES[@]}"; do
        if [[ -f "${SYS_PATH}/${LOC_FILE}" ]]; then
          rm -f "${SYS_PATH}/${LOC_FILE}"
        fi
      done
    done
    term::step::complete
  } || {
    term::step::failed_with_error "Unable to remove extra localization files"
    return 1
  }
}
