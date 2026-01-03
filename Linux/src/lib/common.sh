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
if [[ -z "${_arg_ui_mode:-}" ]] || [[ "${_arg_ui_mode:-}" == "auto" ]]; then
  if ! { [[ -n "${DISPLAY:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; } ||
    { [[ -n "${SSH_CLIENT:-}" ]] || [[ -n "${SSH_TTY:-}" ]]; }; then
    # If we do not have a display, or we are in a SSH session, fallback to text mode
    _arg_ui_mode="none"
  elif { [[ "${XDG_CURRENT_DESKTOP:-}" == "KDE" ]] && command -v kdialog &>/dev/null && command -v busctl &>/dev/null; }; then
    # If we are on KDE, and kdialog + busctl is available, use kdialog
    _arg_ui_mode="kdialog"
  elif command -v zenity &>/dev/null; then
    # Use Zenity if available
    _arg_ui_mode="zenity"
  elif command -v kdialog &>/dev/null && command -v busctl &>/dev/null; then
    # If kdialog is available, but zenity is not (outside of KDE)
    _arg_ui_mode="kdialog"
  else
    # If nothing is available, only run in text mode
    _arg_ui_mode="none"
  fi
fi

# Set-up fd6 as an alternate STDOUT for when we are doing operations with pipes, but
# still want to output progress
exec 6>&1

local PROGRESS_MIN_REFRESH=0.1

ansi::styled() {
  ALLOW_ESCAPES="off"
  if [[ "${1:-}" == "-e" ]]; then
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

  if [[ "${ALLOW_ESCAPES}" == "on" ]]; then
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

    if [[ -n "${discard:-}" ]]; then
      echo
    fi
  fi

  read -p "$(ansi::styled "?" "${ansi_stylenum[bright]}" "${ansi_colornum[green]}") ${QUESTION} $(ansi::styled "${DEFAULT_PROMPT}" "${ansi_stylenum[bright]}") " -n 1 -r
  echo
  if [[ "${DEFAULT}" =~ ^[Nn]$ ]]; then
    if [[ ! "${REPLY}" =~ ^[Yy]$ ]]; then
      return 1
    fi
  elif [[ "${DEFAULT}" =~ ^[Yy]$ ]]; then
    if [[ "${REPLY}" =~ ^[Nn]$ ]]; then
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

  if [[ -n "${1:-}" ]]; then
    STEP_PROGRESS_TEXT="$(ansi::styled " ($*)" "${ansi_stylenum[dim]}")"
  fi

  echo -en "\r $(ansi::styled "[" "${ansi_stylenum[bright]}") $(ansi::styled "${STEP_PROGRESS_SPINNER_CHARS[$STEP_PROGRESS_SPINNER_CURRENT]}" "${ansi_stylenum[dim]}") $(ansi::styled "]" "${ansi_stylenum[bright]}") ${CURRENT_STEP_NAME}${STEP_PROGRESS_TEXT}\033[K"
  STEP_PROGRESS_SPINNER_CURRENT=$((STEP_PROGRESS_SPINNER_CURRENT + 1))

  if [[ "${STEP_PROGRESS_SPINNER_CURRENT}" -ge "${#STEP_PROGRESS_SPINNER_CHARS[@]}" ]]; then
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

  if [[ -n "${1:-}" ]]; then
    STEP_SKIPPED_REASON="$(ansi::styled " ($*)" "${ansi_stylenum[dim]}")"
  fi

  echo -e "\r\033[K $(ansi::styled "[" "${ansi_stylenum[bright]}") $(ansi::styled "-" "${ansi_stylenum[dim]}") $(ansi::styled "]" "${ansi_stylenum[bright]}") ${CURRENT_STEP_NAME}${STEP_SKIPPED_REASON}"
}

term::step::failed_with_error() {
  term::step::failed
  echo

  local ERROR_TEXT="$*"

  term::error "${ERROR_TEXT}" 1>&2

  if [[ "${_arg_ui_mode:-none}" == "kdialog" ]]; then
    kdialog --title "Error" \
      --error "${ERROR_TEXT}" 2>/dev/null
  elif [[ "${_arg_ui_mode:-none}" == "zenity" ]]; then
    zenity --error --text="${ERROR_TEXT}" --width=350 2>/dev/null
  fi
}

xdgdirs::get_user_dir() {
  local USER_DIR_NAME="${1}"

  if command -v xdg-user-dir &>/dev/null; then
    local USER_DIR_RETURNED
    USER_DIR_RETURNED=$(xdg-user-dir "${USER_DIR_NAME}")

    if [[ -d "${USER_DIR_RETURNED}" ]]; then
      echo "${USER_DIR_RETURNED}"
    fi

    return 0
  fi

  local USER_DIR_VAR_NAME="XDG_${USER_DIR_NAME}_DIR"
  if [[ -n "${!USER_DIR_VAR_NAME:-}" ]] && [[ -d "${!USER_DIR_VAR_NAME}" ]]; then
    echo "${!USER_DIR_VAR_NAME}"
  fi
}

helper::progress::run_with_progress() {
  local LAST_UPDATE=""

  local PROGRESS_MESSAGE="${1}"
  shift

  while IFS= read -r UPDATE; do
    term::step::progress "${PROGRESS_MESSAGE}" >&6
    LAST_UPDATE="${UPDATE}"
  done < <(helper::progress::make_consistant "$@")

  echo "${LAST_UPDATE}"
}

# This function throttles the output to avoid buffering, while also making sure the last update
# is repeated at a set frequency for the throbber to work
helper::progress::make_consistant() {
  local LAST_UPDATE=""
  local CURRENT_UPDATE=""

  exec 3< <(helper::run_as_proc_group "$@")
  local PROC_SUB_PID=$!

  trap '[ -n "${PROC_SUB_PID:-}" ] && { kill -- "${PROC_SUB_PID}"; }' EXIT

  local CAN_WRITE="y"
  trap 'CAN_WRITE="n"' SIGPIPE

  while kill -0 "${PROC_SUB_PID}" 2>/dev/null; do
    while IFS= read -r -u 3 -t 0.001 CURRENT_UPDATE; do
      LAST_UPDATE="${CURRENT_UPDATE}"
    done

    if [[ "${CAN_WRITE}" == "y" ]]; then
      echo "${LAST_UPDATE}" 2>/dev/null
      sleep "${PROGRESS_MIN_REFRESH}"
    else
      break
    fi
  done

  trap - SIGPIPE EXIT

  local EXIT_CODE=1

  if [[ "${CAN_WRITE}" == "y" ]]; then
    # Final drain of remaining data
    while IFS= read -r -u 3 CURRENT_UPDATE; do
      LAST_UPDATE="${CURRENT_UPDATE}"
    done
    echo "${LAST_UPDATE}"
  else
    if kill -0 "${PROC_SUB_PID}" 2>/dev/null; then
      # Explicitly kill if the loop exited due to CAN_WRITE="n"
      kill -TERM -- "${PROC_SUB_PID}"
    fi

    return 1
  fi

  wait "${PROC_SUB_PID}"
  EXIT_CODE=$?

  exec 3<&-
  return "${EXIT_CODE}"
}

helper::run_as_proc_group() {
  set -m
  { "$@"; } &
  set +m
  local PROC_SUB_PID=$!

  trap 'trap - EXIT; [[ -n "${PROC_SUB_PID:-}" ]] && { kill -- -"${PROC_SUB_PID}"; wait "${PROC_SUB_PID}"; return $?; }' EXIT

  wait "${PROC_SUB_PID}"
  local EXIT_CODE=$?
  trap - EXIT
  return $?
}

helper::string::unshift::next_value() {
  __helper::string::unshift "${1:-}" "${2:-}" "v"
}

helper::string::unshift::remainder() {
  __helper::string::unshift "${1:-}" "${2:-}" "r"
}

__helper::string::unshift() {
  local VAR_CURRENT_VALUE="${1:-}"
  local SEPARATOR="${2:-|}"
  local RETURN="${3}"

  local SHIFTED_VALUE
  local REMAINING_VALUE

  if [[ "${VAR_CURRENT_VALUE}" == *"${SEPARATOR}"* ]]; then
    SHIFTED_VALUE="${VAR_CURRENT_VALUE%%"${SEPARATOR}"*}"
    REMAINING_VALUE="${VAR_CURRENT_VALUE#*"${SEPARATOR}"}"
  else
    SHIFTED_VALUE="${VAR_CURRENT_VALUE}"
    REMAINING_VALUE=""
  fi

  if [[ "${RETURN}" == "r" ]]; then
    echo "${REMAINING_VALUE}"
    return 0
  fi

  echo "${SHIFTED_VALUE}"
}
