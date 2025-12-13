# shellcheck shell=bash

local EPIC_TOS_URL="https://legal.epicgames.com/en-US/epicgames/tos"

step::eula() {
  if [ "${_arg_ui_mode:-none}" == "none" ]; then
    __step::eula::text
    return 0
  fi

  term::step::new "Terms of Service"

  local DIALOG_TEXT="The Epic Games Terms of Service apply to the use and distribution of this game,
and they supersede any other end user agreements that may accompany the game.

You may read the Terms of Service at this URL:
  ${EPIC_TOS_URL}"

  local DIALOG_ARGS=()

  if [ "${_arg_ui_mode:-none}" == "kdialog" ]; then
    DIALOG_ARGS=(
      kdialog
      --title
      "Terms of Service"
      --yesno
      "${DIALOG_TEXT}"
    )
  elif [ "${_arg_ui_mode:-none}" == "zenity" ]; then
    DIALOG_ARGS=(
      zenity
      --text-info
      "Terms of Service"
      "--checkbox=I agree to Epic Games Terms of Service"
      --width=450
      --height=400
    )
  fi

  if ! echo "${DIALOG_TEXT}" | "${DIALOG_ARGS[@]}" &>/dev/null; then
    term::step::failed_with_error "Installation Aborted." 1>&2
    return 1
  fi

  term::step::complete
}

__step::eula::text() {
  echo
  echo -e "The $(ansi::styled "Epic Games Terms of Service" "${ansi_stylenum[bright]}") apply to the use and distribution of this game,"
  echo "and they supersede any other end user agreements that may accompany the game."
  echo
  echo "You may read the Terms of Service at this URL:"
  echo "  $(ansi::styled "${EPIC_TOS_URL}" "${ansi_stylenum[underline]}")"
  echo

  if ! term::yesno "Do you agree to the Terms of Service?"; then
    echo
    term::step::new "Terms of Service"
    term::step::failed_with_error "Installation Aborted." 1>&2
    return 1
  fi

  echo
  term::step::new "Terms of Service"
  term::step::complete
}
