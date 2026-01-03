# shellcheck shell=bash

step::ut2004_install_files() {
  term::step::new "Install Files"

  local STAGING_DATA_FOLDER="${_arg_destination%/}/Installer/.staging/Data"

  local FOLDERS_AND_TARGETS=(
    'All_Animations|Animations'
    'All_Benchmark|Benchmark'
    'All_ForceFeedback|ForceFeedback'
    'All_Help|Help'
    'All_KarmaData|KarmaData'
    'All_Maps|Maps'
    'All_Music|Music'
    'All_StaticMeshes|StaticMeshes'
    'All_Textures|Textures'
    'All_Web|Web'
    'All_UT2004.EXE|System'
    'English_Manual|Manual'
    'English_Sounds_Speech_System_Help|'
  )

  # Backup file doesn't have US_License file group
  if [[ -d "${STAGING_DATA_FOLDER}/US_License.int" ]]; then
    FOLDERS_AND_TARGETS+=('US_License.int|System')
  fi

  # Let's first remove any files which are not required due to us targeting Linux
  rm -f "${STAGING_DATA_FOLDER}/All_UT2004.EXE/"*.exe 2>/dev/null || true
  rm -f "${STAGING_DATA_FOLDER}/English_Sounds_Speech_System_Help/System/"*.bat 2>/dev/null || true
  rm -f "${STAGING_DATA_FOLDER}/English_Sounds_Speech_System_Help/System/"*.dll 2>/dev/null || true
  rm -f "${STAGING_DATA_FOLDER}/English_Sounds_Speech_System_Help/System/"*.exe 2>/dev/null || true

  # Check if we are istalling on top of a Steam install of UT2004, and rename the lower-case Maps folder is that's the case
  if [[ -d "${_arg_destination%/}/maps" ]] && [[ ! -d "${_arg_destination%/}/Maps" ]]; then
    mv "${_arg_destination%/}/maps" "${_arg_destination%/}/Maps"
  fi

  local FOLDER_PAIR

  for FOLDER_PAIR in "${FOLDERS_AND_TARGETS[@]}"; do
    local FOLDER_SOURCE="${FOLDER_PAIR%|*}"
    local FOLDER_TARGET="${FOLDER_PAIR#*|}"
    local RESOLVED_TARGET="${_arg_destination}"

    term::step::progress "${FOLDER_SOURCE}"

    if [[ -n "${FOLDER_TARGET}" ]]; then
      mkdir -p "${_arg_destination%/}/${FOLDER_TARGET}" 2>/dev/null || {
        term::step::failed_with_error "User does not have permission to create the target folder (${FOLDER_TARGET}). Aborting installation."
        return 77 #E_PERM
      }
      RESOLVED_TARGET="${_arg_destination%/}/${FOLDER_TARGET}"
    fi

    cp -rf "${STAGING_DATA_FOLDER}/${FOLDER_SOURCE}/"* "${RESOLVED_TARGET}/" || {
      term::step::failed_with_error "Failed to copy files to target folder (${FOLDER_TARGET}). Aborting installation."
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
