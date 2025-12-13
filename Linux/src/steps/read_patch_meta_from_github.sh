# shellcheck shell=bash

local PATCH_FILENAME

step::read_patch_meta_from_github() {
  term::step::new "Fetch Patch Info from GitHub"

  if [ -z "${PATCH_METADATA_URL:-}" ]; then
    term::step::failed_with_error "Implementation error, PATCH_METADATA_URL not set."
    return 1
  fi

  term::step::progress "Downloading Metadata"
  local PATCH_METADATA_JSON
  { PATCH_METADATA_JSON=$(downloader::fetch_json "${PATCH_METADATA_URL}"); } \
    || { term::step::failed_with_error "Failed to read patch metadata from GitHub. Installation aborted."; return 1; }

  if ! type "step::read_patch_meta_from_github::metadata_filter" &>/dev/null; then
    step::read_patch_meta_from_github::metadata_filter() {
      echo "-linux-${ARCHITECTURE_SUFFIX}"
    }
  fi

  local JQ_FILTER
  { JQ_FILTER='.assets[] | select(.browser_download_url | ascii_downcase | contains("'$(step::read_patch_meta_from_github::metadata_filter)'"))'; } \
    || { term::step::failed_with_error "Implementation error, step::read_patch_meta_from_github::metadata_filter runtime error."; return 1; }

  local PATCH_DOWNLOAD_URL
  { PATCH_DOWNLOAD_URL=$(echo "${PATCH_METADATA_JSON}" | jq -r "[ ${JQ_FILTER} ] | .[0].browser_download_url"); } \
    || { term::step::failed_with_error "Implementation error, step::read_patch_meta_from_github::metadata_filter runtime error."; return 1; }

  if [ -z "${PATCH_DOWNLOAD_URL:-}" ]; then
    term::step::failed_with_error "Couldn't determine which patch to download. Installation aborted."
    return 1
  fi

  PATCH_FILENAME="${PATCH_DOWNLOAD_URL##*/}"
  PATCH_FILENAME="${PATCH_FILENAME%%\?*}"

  local PATCH_DOWNLOAD_SIZE
  { PATCH_DOWNLOAD_SIZE=$(echo "${PATCH_METADATA_JSON}" | jq -r "[ ${JQ_FILTER} ] | .[0].size"); } \
    || { term::step::failed_with_error "Couldn't determine patch size. Installation aborted."; return 1; }

  DOWNLOADS_URL_LIST+=("${PATCH_DOWNLOAD_URL}")
  DOWNLOADS_FILENAME_LIST+=("${PATCH_FILENAME}")
  DOWNLOADS_SIZE_LIST+=("${PATCH_DOWNLOAD_SIZE}")

  term::step::complete
}
