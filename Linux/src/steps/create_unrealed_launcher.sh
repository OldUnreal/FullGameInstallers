# shellcheck shell=bash

step::create_unrealed_launcher() {
  term::step::new "Create UnrealEd Launch Script"

  local UNREALED_WINE_PREFIX_PATH="${_arg_destination%/}/.wine-unrealed"
  local UNREALED_LAUNCH_SCRIPT_PATH="${_arg_destination%/}/System${UEED_SYSTEM_FOLDER_SUFFIX:-}/UnrealEd-launch-linux.sh"

  mkdir -p "${UNREALED_WINE_PREFIX_PATH}"

  step::create_unrealed_launcher::write "${UNREALED_LAUNCH_SCRIPT_PATH}" || {
    term::step::failed_with_error "Failed to create UnrealEd launch script. Installation aborted."
    return 1
  }
  chmod +x "${UNREALED_LAUNCH_SCRIPT_PATH}" || {
    term::step::failed_with_error "Failed to set UnrealEd launch script as executable. Installation aborted."
    return 1
  }

  term::step::complete
}

step::create_unrealed_launcher::write() {
  local FILEPATH="${1:-}"

  {
    cat <<"EOFLAUNCHER"
# @include inc/unrealed-launch-linux.sh
EOFLAUNCHER
  } >"${FILEPATH}"
}
