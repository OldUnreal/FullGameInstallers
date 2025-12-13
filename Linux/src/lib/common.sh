# shellcheck shell=bash
declare -A ansi_colornum=(
  [black]=0
  [red]=1
  [green]=2
  [yellow]=3
  [blue]=4
  [magenta]=5
  [cyan]=6
  [white]=7
)

declare -A ansi_stylenum=(
  [reset]=0
  [bright]=1
  [dim]=2
  [italic]=3
  [underline]=4
  [flash]=5
  [highlight]=7
  [normal]=22
)

# UI Mode auto-detection
if [ -z "${_arg_ui_mode:-}" ] || [ "${_arg_ui_mode:-}" == "auto" ]; then
  if ! { [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; } || \
     { [ -n "${SSH_CLIENT:-}" ] || [ -n "${SSH_TTY:-}" ]; }; then
     # If we do not have a display, or we are in a SSH session, fallback to text mode
    _arg_ui_mode="none"
  elif { [ "${XDG_CURRENT_DESKTOP:-}" == "KDE" ] && command -pv kdialog &>/dev/null && command -pv busctl &>/dev/null; }; then
    # If we are on KDE, and kdialog + busctl is available, use kdialog
    _arg_ui_mode="kdialog"
  elif command -pv zenity &>/dev/null; then
    # Use Zenity if available
    _arg_ui_mode="zenity"
  elif command -pv kdialog &>/dev/null && command -pv busctl &>/dev/null; then
    # If kdialog is available, but zenity is not (outside of KDE)
    _arg_ui_mode="kdialog"
  else
    # If nothing is available, only run in text mode
    _arg_ui_mode="none"
  fi
fi

ansi::styled() {
  ALLOW_ESCAPES="off"
  if [ "${1:-}" == "-e" ]; then
    ALLOW_ESCAPES="on"
    shift
  fi

  local TEXT_TO_PRINT="${1:-}"
  local STYLE="${2:--1}"
  local FORE_COLOR="${3:--1}"
  local BACK_COLOR="${4:--1}"

  declare -a CODES RESETCODES
  if [[ "${STYLE}" -eq 22 ]] || [[ "${STYLE}" -eq -1 ]]; then
      RESETCODES=("$(printf "\033[%sm" "22")" "${RESETCODES[@]}")
  else
      CODES=("${CODES[@]}" "$(printf "\033[%sm" "${STYLE}")")
  fi

  if [[ "${BACK_COLOR}" -eq -1 ]]; then
      RESETCODES=("$(printf "\033[%sm" "49")" "${RESETCODES[@]}")
  else
      CODES=("${CODES[@]}" "$(printf "\033[%sm" "$((BACK_COLOR + 40))")")
  fi

  if [[ "${FORE_COLOR}" -eq -1 ]]; then
      RESETCODES=("$(printf "\033[%sm" "39")" "${RESETCODES[@]}")
  else
      CODES=("${CODES[@]}" "$(printf "\033[%sm" "$((FORE_COLOR + 30))")")
  fi

  local rc
  for rc in "${RESETCODES[@]}"; do
      echo -en "$rc"
  done
  local c
  for c in "${CODES[@]}"; do
      echo -en "$c"
  done

  if [ "${ALLOW_ESCAPES}" == "on" ]; then
    echo -en "${TEXT_TO_PRINT}"
  else
    echo -n "${TEXT_TO_PRINT}"
  fi

  echo -en "\033[m"
}

ansi::banner() {
  local TOPEDGE BOTTOMEDGE
  TOPEDGE="┏━${1//?/━}━┓"
  BOTTOMEDGE="┗━${1//?/━}━┛"

  printf "%s\n" "$(ansi::styled "${TOPEDGE}" "${ansi_stylenum[bright]}")"
  printf "%s\n" "$(ansi::styled "┃ ${1} ┃" "${ansi_stylenum[bright]}")"
  printf "%s\n" "$(ansi::styled "${BOTTOMEDGE}" "${ansi_stylenum[bright]}")"
}

term::error() {
  echo -e "$(ansi::styled "Error:" "${ansi_stylenum[bright]}" "${ansi_colornum[red]}") $*" 1>&2
}

term::yesno() {
  local QUESTION="${1:-}"
  local DEFAULT="${2:-N}"

  local DEFAULT_PROMPT="[yN]"
  if [[ "${DEFAULT}" =~ ^[Yy]$ ]]; then
    DEFAULT_PROMPT="[Yn]"
  fi

  # In case the user was impatient and typed a whole bunch of crap in their terminal while waiting for a download
  # clear the STDIN buffer
  if test -t 0; then
    local discard
    read -r -n 1000000 -t 0.001 discard || true

    if [ -n "${discard:-}" ]; then
      echo
    fi
  fi

  read -p "$(ansi::styled "?" "${ansi_stylenum[bright]}" "${ansi_colornum[green]}") ${QUESTION} $(ansi::styled "${DEFAULT_PROMPT}" "${ansi_stylenum[bright]}") " -n 1 -r
  echo
  if [[ "${DEFAULT}" =~ ^[Nn]$ ]]; then
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]
    then
      return 1
    fi
  elif [[ "${DEFAULT}" =~ ^[Yy]$ ]]; then
    if [[ "$REPLY" =~ ^[Nn]$ ]]
    then
      return 1
    fi
  fi

  return 0
}

local CURRENT_STEP_NAME=""
local STEP_PROGRESS_SPINNER_CHARS=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
local STEP_PROGRESS_SPINNER_CURRENT=0

term::step::new() {
  CURRENT_STEP_NAME="$*"

  echo -en " $(ansi::styled "[   ]" "${ansi_stylenum[bright]}") $*"
}

term::step::replace() {
  CURRENT_STEP_NAME="$*"

  echo -en "\r\033[K $(ansi::styled "[   ]" "${ansi_stylenum[bright]}") $*"
}

term::step::progress() {
  local STEP_PROGRESS_TEXT=""

  if [ -n "${1:-}" ]; then
    STEP_PROGRESS_TEXT="$(ansi::styled " ($*)" "${ansi_stylenum[dim]}")"
  fi

  echo -en "\r $(ansi::styled "[" "${ansi_stylenum[bright]}") $(ansi::styled "${STEP_PROGRESS_SPINNER_CHARS[$STEP_PROGRESS_SPINNER_CURRENT]}" "${ansi_stylenum[dim]}") $(ansi::styled "]" "${ansi_stylenum[bright]}") ${CURRENT_STEP_NAME}${STEP_PROGRESS_TEXT}\033[K"
  STEP_PROGRESS_SPINNER_CURRENT=$((STEP_PROGRESS_SPINNER_CURRENT + 1))
  
  if [ "${STEP_PROGRESS_SPINNER_CURRENT}" -ge "${#STEP_PROGRESS_SPINNER_CHARS[@]}" ]; then
    STEP_PROGRESS_SPINNER_CURRENT=0
  fi
}

term::step::complete() {
  echo -e "\r\033[K $(ansi::styled "[" "${ansi_stylenum[bright]}") $(ansi::styled "✓" "${ansi_stylenum[bright]}" "${ansi_colornum[green]}") $(ansi::styled "]" "${ansi_stylenum[bright]}") ${CURRENT_STEP_NAME}"
}

term::step::failed() {
  echo -e "\r\033[K $(ansi::styled "[" "${ansi_stylenum[bright]}") $(ansi::styled "✗" "${ansi_stylenum[bright]}" "${ansi_colornum[red]}") $(ansi::styled "]" "${ansi_stylenum[bright]}") ${CURRENT_STEP_NAME}"
}

term::step::skipped() {
  local STEP_SKIPPED_REASON=""

   if [ -n "${1:-}" ]; then
    STEP_SKIPPED_REASON="$(ansi::styled " ($*)" "${ansi_stylenum[dim]}")"
  fi

  echo -e "\r\033[K $(ansi::styled "[" "${ansi_stylenum[bright]}") $(ansi::styled "-" "${ansi_stylenum[dim]}") $(ansi::styled "]" "${ansi_stylenum[bright]}") ${CURRENT_STEP_NAME}${STEP_SKIPPED_REASON}"
}

term::step::failed_with_error() {
  term::step::failed
  echo

  local ERROR_TEXT="$*"

  term::error "${ERROR_TEXT}" 1>&2

  if [ "${_arg_ui_mode:-none}" == "kdialog" ]; then
    kdialog --title "Error" \
      --error "${ERROR_TEXT}" 2>/dev/null
  elif [ "${_arg_ui_mode:-none}" == "zenity" ]; then
    zenity --error --text="${ERROR_TEXT}" --width=350 2>/dev/null
  fi
}
