# shellcheck shell=bash

local PATCH_METADATA_JSON

step::read_patch_meta_from_github() {
  local PATCH_FOR_OS="${1:-linux}"
  local PATCH_FOR_REASON="${2:-}"

  local STEP_NAME="Fetch Patch Info from GitHub"

  if [[ -n "${PATCH_FOR_REASON}" ]]; then
    STEP_NAME="${STEP_NAME} (${PATCH_FOR_REASON})"
  fi

  term::step::new "${STEP_NAME}"

  if [[ -z "${PATCH_METADATA_URL:-}" ]]; then
    term::step::failed_with_error "Implementation error, PATCH_METADATA_URL not set."
    return 1
  fi

  if [[ -z "${PATCH_METADATA_JSON:-}" ]]; then
    term::step::progress "Downloading Metadata"
    { PATCH_METADATA_JSON=$(downloader::fetch_json "${PATCH_METADATA_URL}"); } ||
      {
        term::step::failed_with_error "Failed to read patch metadata from GitHub. Installation aborted."
        return 1
      }
  fi

  if ! type "step::read_patch_meta_from_github::metadata_filter" &>/dev/null; then
    step::read_patch_meta_from_github::metadata_filter() {
      local PATCH_OS_NAME="${1:-}"
      # shellcheck disable=SC2034 # present by convention
      local PATCH_TARGET_ARCHITECTURE="${2:-}"

      if [[ "${PATCH_OS_NAME}" == "windows" ]]; then
        echo "-${PATCH_OS_NAME}(-.+)?.zip"
        return 0
      fi

      echo "-${PATCH_OS_NAME}"
    }
  fi

  local IS_GITHUB_RELEASES_ARRAY="no"
  { IS_GITHUB_RELEASES_ARRAY=$(echo "${PATCH_METADATA_JSON}" | jq -r 'if (. | type) == "array" then "yes" else "no" end'); } || {
    term::step::failed_with_error "Couldn't determine if we received a single release, or an array of releases. Installation aborted."
    return 1
  }

  local JQ_FILTER=".assets[]"
  if [[ "${IS_GITHUB_RELEASES_ARRAY}" == "yes" ]]; then
    JQ_FILTER=".[0].assets[]"
  fi

  local METADATA_FILTER
  METADATA_FILTER=$(step::read_patch_meta_from_github::metadata_filter "${PATCH_FOR_OS}" "${ARCHITECTURE_SUFFIX}")
  local JQ_FILTER

  { JQ_FILTER+=' | select(.browser_download_url | ascii_downcase | test("'"${METADATA_FILTER}"'"))'; } ||
    {
      term::step::failed_with_error "Implementation error, step::read_patch_meta_from_github::metadata_filter runtime error."
      return 1
    }

  local PATCH_DOWNLOAD_URL
  { PATCH_DOWNLOAD_URL=$(echo "${PATCH_METADATA_JSON}" | jq -r "[ ${JQ_FILTER} ] | .[0].browser_download_url"); } ||
    {
      term::step::failed_with_error "Implementation error, step::read_patch_meta_from_github::metadata_filter runtime error."
      return 1
    }

  if [[ -z "${PATCH_DOWNLOAD_URL:-}" ]]; then
    term::step::failed_with_error "Couldn't determine which patch to download. Installation aborted."
    return 1
  fi

  PATCH_FILENAME="${PATCH_DOWNLOAD_URL##*/}"
  PATCH_FILENAME="${PATCH_FILENAME%%\?*}"

  local PATCH_DOWNLOAD_SIZE
  { PATCH_DOWNLOAD_SIZE=$(echo "${PATCH_METADATA_JSON}" | jq -r "[ ${JQ_FILTER} ] | .[0].size"); } ||
    {
      term::step::failed_with_error "Couldn't determine patch size. Installation aborted."
      return 1
    }

  DOWNLOADS_SOURCE_LIST[patch_${PATCH_FOR_OS}]="${PATCH_DOWNLOAD_URL}|${PATCH_DOWNLOAD_SIZE}|"
  DOWNLOADS_FILENAME_LIST[patch_${PATCH_FOR_OS}]="${PATCH_FILENAME}"

  term::step::complete
}
