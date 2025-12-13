#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR

# Do not execute this script unless bootstrapped from the main install runner
if [ -z "${_SCRIPT_DIR:-}" ]; then
  exit
fi

# Ensure required variables exist
if [ -z "${fore[*]:-}" ] \
   || [ -z "${style[*]:-}" ] \
   || [ -z "${INSTALLATION_MODE:-}" ]; then
  exit 1
fi

EPIC_TOS_URL="https://legal.epicgames.com/en-US/epicgames/tos"

installer_step::eula() {
  "installer_step::eula::${INSTALLATION_MODE}"
}

installer_step::eula::text() {
  echo -e "${style[bright]}The Epic Games Terms of Service apply to the use and distribution of this game,${style[reset]}"
  echo -e "${style[bright]}and they supersede any other end user agreements that may accompany the game.${style[reset]}"
  echo
  echo -e "${style[bright]}You may read the Terms of Service at this URL:${style[reset]}"
  echo -e "  ${style[underline]}${EPIC_TOS_URL}${style[reset]}"
  echo
  read -p "${style[bright]}${fore[green]}?${style[reset]} Do you agree to the Terms of Service? ${style[bright]}[yN]${style[reset]} " -n 1 -r
  echo
  if [[ ! "$REPLY" =~ ^[Yy]$ ]]
  then
    exit 99
  fi
  echo
}

installer_step::eula::zenity() {
  local DIALOG_TEXT="The Epic Games Terms of Service apply to the use and distribution of this game, and they supersede any other end user agreements that may accompany the game.

You may read the Terms of Service at this URL:
${EPIC_TOS_URL}"

  echo "$DIALOG_TEXT" | zenity --text-info \
    --width=450 \
    --height=400 \
    --title="Terms of Service" \
    --checkbox="I agree to Epic Games Terms of Service" 2>/dev/null
}
