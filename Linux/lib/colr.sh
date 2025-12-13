#!/bin/bash

# Bash color function to colorize text by name, instead of number.
# Also includes maps from name to escape code for fore, back, and styles.
# -Christopher Welborn 08-27-2015
# https://github.com/welbornprod/colr.sh

# Variables are namespaced to not interfere when sourced.
colr_app_name="Colr"
colr_app_version="0.4.0"
colr_app_path="$(readlink -f "${BASH_SOURCE[0]}")"
colr_app_script="${colr_app_path##*/}"

# This flag can be set with colr_enable or colr_disable.
colr_disabled=0

# Functions to format a color number into an actual escape code.
function codeformat {
    # Basic fore, back, and styles.
    printf "\033[%sm" "$1"
}
function extforeformat {
    # 256 fore color
    printf "\033[38;5;%sm" "$1"
}
function extbackformat {
    # 256 back color
    printf "\033[48;5;%sm" "$1"
}

# Maps from color/style name -> escape code.
declare -A fore back style

function build_maps {
    # Build the fore/back maps.
    # Names and corresponding base code number
    local colornum
    # shellcheck disable=SC2102
    declare -A colornum=(
        [black]=0
        [red]=1
        [green]=2
        [yellow]=3
        [blue]=4
        [magenta]=5
        [cyan]=6
        [white]=7
        )
    local cname
    for cname in "${!colornum[@]}"; do
        fore[$cname]="$(codeformat $((30 + ${colornum[$cname]})))"
        fore[light$cname]="$(codeformat $((90 + ${colornum[$cname]})))"
        back[$cname]="$(codeformat $((40 + ${colornum[$cname]})))"
        back[light$cname]="$(codeformat $((100 + ${colornum[$cname]})))"
    done
    # shellcheck disable=SC2154
    fore[reset]="$(codeformat 39)"
    back[reset]="$(codeformat 49)"

    # 256 colors.
    local cnum
    for cnum in {0..255}; do
        fore[$cnum]="$(extforeformat "$cnum")"
        back[$cnum]="$(extbackformat "$cnum")"
    done

    # Map of base code -> style name
    local stylenum
    # shellcheck disable=SC2102
    declare -A stylenum=(
        [reset]=0
        [bright]=1
        [dim]=2
        [italic]=3
        [underline]=4
        [flash]=5
        [highlight]=7
        [normal]=22
    )
    local sname
    for sname in "${!stylenum[@]}"; do
        style[$sname]="$(codeformat "${stylenum[$sname]}")"
    done
}
build_maps

function colr {
    # Colorize a string.
    local text="$1"
    if ((colr_disabled)); then
        # Color has been globally disabled.
        echo -en "$text"
        return
    fi

    local forecolr="${2:-reset}"
    local backcolr="${3:-reset}"
    local stylename="${4:-normal}"

    declare -a codes resetcodes
    if [[ "$stylename" =~ ^reset ]]; then
        resetcodes=("${style[$stylename]}" "${resetcodes[@]}")
    else
        codes=("${codes[@]}" "${style[$stylename]}")
    fi

    if [[ "$backcolr" =~ reset ]]; then
        resetcodes=("${back[$backcolr]}" "${resetcodes[@]}")
    else
        codes=("${codes[@]}" "${back[$backcolr]}")
    fi

    if [[ "$forecolr" =~ reset ]]; then
        resetcodes=("${fore[$forecolr]}" "${resetcodes[@]}")
    else
        codes=("${codes[@]}" "${fore[$forecolr]}")
    fi

    # Reset codes must come first (style reset can affect colors)
    local rc
    for rc in "${resetcodes[@]}"; do
        echo -en "$rc"
    done
    local c
    for c in "${codes[@]}"; do
        echo -en "$c"
    done
    local closing="\033[m"

    echo -n "$text"
    echo -en "$closing"
}

function colr_auto_disable {
    # Auto disable colors if stdout is not a tty,
    # or if the user supplied file descriptors are not ttys.
    # Arguments:
    #  $@ : One or more TTY numbers to check.
    #       Default: 1

    if (($# == 0)); then
        # Just check stdout by default.
        if [[ ! -t 1 ]] || [[ -p 1 ]]; then
            colr_disabled=1
        fi
        return
    fi
    # Make sure all user's tty args are ttys.
    local ttynum
    for ttynum in "$@"; do
        if [[ ! -t "$ttynum" ]] || [[ -p "$ttynum" ]]; then
            colr_disabled=1
            break
        fi
    done
}

function colr_enable {
    # Re-enable colors after colr_disable has been called.
    colr_disabled=0
}

function colr_disable {
    # Disable colors for the `colr` function.
    colr_disabled=1
}

function colr_is_disabled {
    # Returns success code if colr_disabled is non-zero.
    ((colr_disabled)) && return 0
    return 1
}

function colr_is_enabled {
    # Returns success code if colr_disabled is zero.
    ((colr_disabled)) && return 1
    return 0
}

function echo_err {
    # Print to stderr.
    printf "%s " "$@" 1>&2
    printf "\n" 1>&2
}

function escape_code_repr {
    # Print the representation of an escape code,
    # without escaping (without setting a color, style, etc.)
    # This will replace all escape codes in a string with their
    # representation.
    # Arguments:
    #   $@ : The escape codes or strings to show.
    (($#)) || {
        echo_err "No arguments passed to escape_code_repr."
        return 1
    }
    local escapecode
    for escapecode; do
        printf "%s" "${escapecode//$'\033'/$'\\033'}"
    done
}

function print_usage {
    # Show usage reason if first arg is available.
    [[ -n "$1" ]] && echo -e "\n$1\n"
    local b="${fore[blue]}" B="${style[bright]}" R="${style[reset]}"
    local g="${fore[green]}" y="${fore[yellow]}"
    local name=$colr_app_name script=$colr_app_script ver=$colr_app_version
    echo "${b}${B}\
${name} v. ${ver}${R}

    Usage:${b}
        $script ${y}-h | -l | -L | -v
        ${b}$script ${y}TEXT FORE [BACK] [STYLE]
        ${b}$script ${y}-r TEXT
    ${R}
    Options:$g
        BACK             ${R}:${g} Name of back color for the text.
        FORE             ${R}:${g} Name of fore color for the text.
        STYLE            ${R}:${g} Name of style for the text.
        TEXT             ${R}:${g} Text to colorize.
        -h,--help        ${R}:${g} Show this message.
        -L,--listcodes   ${R}:${g} List all colors and escape codes exported
                           by this script.
        -l,--liststyles  ${R}:${g} List all colors exported by this script.
        -r,--repr        ${R}:${g} Show a representation of escape codes found
                           in a string.
                           This may also be used on stdin data.
        -v,--version     ${R}:${g} Show ${b}${B}${name}${R}${g} version and exit.
    ${R}"
}


export colr
export fore
export back
export style

if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
    declare -a userargs
    do_forced=0
    do_list=0
    do_listcodes=0
    for arg; do
        case "$arg" in
            "-f"|"--force" )
                do_forced=1
                ;;
            "-h"|"--help" )
                print_usage ""
                exit 0
                ;;
            "-L"|"--listcodes" )
                do_listcodes=1
                do_list=1
                ;;
            "-l"|"--liststyles" )
                do_list=1
                ;;
            "-r"|"--repr" )
                do_repr=1
                ;;
            "-v"|"--version" )
                echo -e "$colr_app_name v. $colr_app_version\n"
                exit 0
                ;;
            -*)
                print_usage "Unknown flag argument: $arg"
                exit 1
                ;;
            *)
                userargs=("${userargs[@]}" "$arg")
        esac
    done

    # Script was executed.
    # Automatically disable colors if stdout is not a tty, unless forced.
    ((do_forced)) || colr_auto_disable 1
    maxwidth=7
    maxwidthstyle=4
    namefmt="%s "
    ((do_listcodes)) && {
        maxwidth=3
        maxwidthstyle=3
        namefmt="%s: "
    }
    if ((do_list)); then
        printf "Fore/Back"
        ((do_listcodes)) && printf " (fore code shown, use 48;5; for back colors)"
        printf ":\n"
        cnt=1
        declare -a sortednames=($(printf "%s\n" "${!fore[@]}" | sort -n))
        for name in "${sortednames[@]}"; do
            # shellcheck disable=SC2059
            # I am using a variable format on purpose shellcheck.
            printf "$namefmt" "$(colr "$(printf "%12s" "$name")" "$name")"
            ((do_listcodes)) && colr "$(printf "%-16s" "$(escape_code_repr "${fore[$name]}")")" "$name"
            ((cnt == maxwidth)) && { printf "\n"; cnt=0; }
            let cnt+=1
        done
        printf "\nStyles:\n"
        cnt=1
        sortednames=($(printf "%s\n" "${!style[@]}" | sort))
        for name in "${sortednames[@]}"; do
            # shellcheck disable=SC2059
            printf "$namefmt" "$(colr "$(printf "%12s" "$name")" "reset" "reset" "$name")"
            ((do_listcodes)) && colr "$(printf "%-16s" "$(escape_code_repr "${style[$name]}")")" "reset" "reset" "$name"
            ((cnt == maxwidthstyle)) && { printf "\n"; cnt=0; }
            let cnt+=1
        done
        printf "\n"
    elif ((do_repr)); then
        ((${#userargs[@]})) || {
            # Read lines from stdin.
            [[ -t 0 ]] && echo -e "\nReading from stdin until EOF (Ctrl + D)...\n"
            nl=$'\n'
            while IFS= read -r line; do
                # Split on spaces.
                userargs+=("${line}${nl}")
            done
        }
        ((${#userargs[@]})) || {
            echo -e "\nNo text to work with for --repr.\n" 1>&2
            exit 1
        }
        printf "%s\n" "$(escape_code_repr "${userargs[@]}")"
    else
        colr "${userargs[@]}"
    fi
fi