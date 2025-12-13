# shellcheck shell=bash

step::welcome_banner() {
  ansi::banner "OldUnreal ${PRODUCT_NAME} Linux Installer"
  echo

  if [ "${_arg_ui_mode:-none}" != "none" ]; then
    echo -e "$(ansi::styled "Installer is running in GUI mode. If no window is displayed," "${ansi_stylenum[dim]}")"
    echo -e "$(ansi::styled "type " "${ansi_stylenum[dim]}")CTRL+C$(ansi::styled " to kill the installer, and start it with the" "${ansi_stylenum[dim]}")"
    echo -e "--ui-mode=none$(ansi::styled " argument." "${ansi_stylenum[dim]}")"
    echo
  fi
}
