# shellcheck shell=bash

step::check_dependencies() {
  term::step::new "Checking Dependencies"

  if [[ "${ARCHITECTURE_SUFFIX}" == 'NOT_SUPPORTED' ]]; then
    term::step::failed_with_error "CPU Architecture ${DETECTED_ARCHITECTURE} is not currently supported."
    return 1
  fi

  local MISSING_DEPS=()
  local MISSING_DEPS_RHEL=()
  local MISSING_DEPS_DEB=()
  local MISSING_DEPS_ARCH=()
  local MISSING_DEPS_OPENSUSE=()
  local MISSING_DEPS_BREW=()

  local UI_MODE_DEPS_MET="yes"

  # Check UI Mode Dependencies
  if [[ "${_arg_ui_mode:-none}" == "kdialog" ]]; then
    term::step::progress "kdialog"
    if ! command -v "kdialog" &>/dev/null; then
      MISSING_DEPS+=("kdialog")
      MISSING_DEPS_RHEL+=("kdialog")
      MISSING_DEPS_DEB+=("kdialog")
      MISSING_DEPS_ARCH+=("kdialog")
      MISSING_DEPS_OPENSUSE+=("kdialog")

      UI_MODE_DEPS_MET="no"
    fi

    term::step::progress "busctl"
    if ! command -v "busctl" &>/dev/null; then
      MISSING_DEPS+=("systemd")
      MISSING_DEPS_RHEL+=("systemd")
      MISSING_DEPS_DEB+=("systemd")
      MISSING_DEPS_ARCH+=("systemd")
      MISSING_DEPS_OPENSUSE+=("systemd")

      UI_MODE_DEPS_MET="no"
    fi
  elif [[ "${_arg_ui_mode:-none}" == "zenity" ]]; then
    term::step::progress "zenity"
    if ! command -v "zenity" &>/dev/null; then
      MISSING_DEPS+=("zenity")
      MISSING_DEPS_RHEL+=("zenity")
      MISSING_DEPS_DEB+=("zenity")
      MISSING_DEPS_ARCH+=("zenity")
      MISSING_DEPS_OPENSUSE+=("zenity")
      MISSING_DEPS_BREW+=("zenity")

      UI_MODE_DEPS_MET="no"
    fi
  fi

  # Check Downloaders
  term::step::progress "curl"
  if ! command -v "curl" &>/dev/null &&
    ! command -v "wget" &>/dev/null &&
    ! command -v "wget2" &>/dev/null; then
    MISSING_DEPS+=("curl (or wget)")
    MISSING_DEPS_RHEL+=("curl")
    MISSING_DEPS_DEB+=("curl")
    MISSING_DEPS_ARCH+=("curl")
    MISSING_DEPS_OPENSUSE+=("curl")
    MISSING_DEPS_BREW+=("curl")
  fi

  # Check Archivers
  term::step::progress "tar"
  if ! command -v "tar" &>/dev/null; then
    MISSING_DEPS+=("tar")
    MISSING_DEPS_RHEL+=("tar")
    MISSING_DEPS_DEB+=("tar")
    MISSING_DEPS_ARCH+=("tar")
    MISSING_DEPS_OPENSUSE+=("tar")
  fi

  term::step::progress "7zip"
  if ! command -v "7z" &>/dev/null &&
    ! command -v "7zz" &>/dev/null; then
    MISSING_DEPS+=("7zip, 7zip [Debian > bookworm], p7zip-full [Debian <= bookworm], or 7zip-standalone-all [Fedora/RHEL]")
    MISSING_DEPS_RHEL+=("7zip-standalone-all")
    MISSING_DEPS_DEB+=("p7zip-full")
    MISSING_DEPS_ARCH+=("7zip")
    MISSING_DEPS_OPENSUSE+=("7zip")
    MISSING_DEPS_BREW+=("7zip")
  fi

  # Check jq
  term::step::progress "jq"
  if ! command -v "jq" &>/dev/null; then
    MISSING_DEPS+=("jq")
    MISSING_DEPS_RHEL+=("jq")
    MISSING_DEPS_DEB+=("jq")
    MISSING_DEPS_ARCH+=("jq")
    MISSING_DEPS_OPENSUSE+=("jq")
    MISSING_DEPS_BREW+=("jq")
  fi

  if [[ "${PRODUCT_SHORTNAME}" == "UT2004" ]]; then
    # Check unshield
    term::step::progress "unshield"
    if ! command -v "unshield" &>/dev/null; then
      # Can it be downloaded?
      case "${ARCHITECTURE_SUFFIX}" in
      amd64 | arm64)
        # shellcheck disable=SC2034 # May not be used in all installers
        DOWNLOADS_SOURCE_LIST[unshield]="https://raw.githubusercontent.com/OldUnreal/FullGameInstallers/master/Linux/deps/unshield-${ARCHITECTURE_SUFFIX}||"
        DOWNLOADS_FILENAME_LIST[unshield]="unshield"
        ;;
      *)
        MISSING_DEPS+=("unshield")
        MISSING_DEPS_RHEL+=("unshield")
        MISSING_DEPS_DEB+=("unshield")
        MISSING_DEPS_ARCH+=("unshield")
        MISSING_DEPS_OPENSUSE+=("unshield")
        MISSING_DEPS_BREW+=("unshield")
        ;;
      esac
    fi
  fi

  if [[ "${UI_MODE_DEPS_MET}" == "no" ]]; then
    _arg_ui_mode="none"
  fi

  if [[ "${#MISSING_DEPS[@]}" -gt 0 ]]; then
    local DISTRO_DERIVATIVE=""
    local DISTRO_PKG_INSTALL_CMD=""

    if command -v "pacman" &>/dev/null; then
      DISTRO_DERIVATIVE="Arch"
      DISTRO_PKG_INSTALL_CMD="sudo pacman -S ${MISSING_DEPS_ARCH[*]}"
    elif command -v "dnf" &>/dev/null; then
      DISTRO_DERIVATIVE="Fedora/RHEL"
      DISTRO_PKG_INSTALL_CMD="sudo dnf install ${MISSING_DEPS_RHEL[*]}"
    elif command -v "apt" &>/dev/null; then
      DISTRO_DERIVATIVE="Debian"
      DISTRO_PKG_INSTALL_CMD="sudo apt install ${MISSING_DEPS_DEB[*]}"
    elif command -v "zypper" &>/dev/null; then
      DISTRO_DERIVATIVE="OpenSUSE"
      DISTRO_PKG_INSTALL_CMD="sudo zypper install ${MISSING_DEPS_OPENSUSE[*]}"
    fi

    local ERROR_TEXT="Missing required dependencies.\n\nYour system is missing dependencies that are required by this installer.\nPlease install the following required packages:"

    local PKG
    for PKG in "${MISSING_DEPS[@]}"; do
      ERROR_TEXT="${ERROR_TEXT}\n  - ${PKG}"
    done

    if [[ -n "${DISTRO_DERIVATIVE}" ]]; then
      ERROR_TEXT="${ERROR_TEXT}\n\nOn ${DISTRO_DERIVATIVE} or derivatives, you should be able to install"
      ERROR_TEXT="${ERROR_TEXT}\nthe required package(s) using the following command:\n"
      ERROR_TEXT="${ERROR_TEXT}\n  ${DISTRO_PKG_INSTALL_CMD}"
    fi

    if command -v "brew" &>/dev/null && [[ "${#MISSING_DEPS_BREW[@]}" -gt 0 ]]; then
      local BREW_INSTALL_CMD="brew install"

      for PKG in "${MISSING_DEPS_BREW[@]}"; do
        BREW_INSTALL_CMD="${BREW_INSTALL_CMD} ${PKG}"
      done

      ERROR_TEXT="${ERROR_TEXT}\n\nYou appear to have brew installed. Some of the required packages are available\n"
      ERROR_TEXT="${ERROR_TEXT}\non brew. You can install them using the following command:\n"
      ERROR_TEXT="${ERROR_TEXT}\n  ${BREW_INSTALL_CMD}"
    fi

    term::step::failed_with_error "${ERROR_TEXT}"

    if [[ "${UI_MODE_DEPS_MET}" == "no" ]]; then
      echo 1>&2
      echo "You do not have the required dependencies for the selected UI mode." 1>&2
      echo -e "Please relaunch using the $(ansi::styled "--ui-mode=none" "${ansi_stylenum[bright]}") argument," 1>&2
      echo "or install the required dependencies." 1>&2
    fi

    return 1
  else
    term::step::complete
  fi
}
