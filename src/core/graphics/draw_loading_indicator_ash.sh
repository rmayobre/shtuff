# Loading indicators (POSIX sh / BusyBox ash implementation). Ash has no arrays, so
# each frame set is a space-separated string and is expanded unquoted when passed on.

# Globals
DEFAULT_MESSAGE="Loading"
DEFAULT_LOADING_COLOR="\033[36m"  # Cyan
RESET_COLOR="\033[0m"
# Indicator characters (space-separated)
SPINNER_FRAMES="⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏"
DOT_FRAMES=". .. ... ...."
BAR_FRAMES="▏ ▎ ▍ ▌ ▋ ▊ ▉ █"
ARROW_FRAMES="← ↖ ↑ ↗ → ↘ ↓ ↙"
CLOCK_FRAMES="🕐 🕑 🕒 🕓 🕔 🕕 🕖 🕗 🕘 🕙 🕚 🕛"
# ASCII fallbacks for locales that cannot display the frames above
ASCII_SPINNER_FRAMES='| / - \'
ASCII_BAR_FRAMES=". o O o"
ASCII_ARROW_FRAMES="< ^ > v"
readonly DEFAULT_MESSAGE DEFAULT_LOADING_COLOR RESET_COLOR

# Function: _draw_is_utf8
# Description: Reports whether the current locale can display the UTF-8 loading frames.
#
# Globals:
#   LC_ALL (read): Locale override, checked first.
#   LC_CTYPE (read): Character type locale, checked second.
#   LANG (read): Default locale, checked last.
#
# Returns:
#   0 - The locale is UTF-8.
#   1 - The locale is not UTF-8 (ASCII frames should be used).
#
# Examples:
#   if _draw_is_utf8; then ...; fi
_draw_is_utf8() {
    case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
        *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) return 0 ;;
        *) return 1 ;;
    esac
}

# Function: draw_loading_indicator
# Description: Displays a continuous loading indicator with a custom frame set until the given process exits.
#              Draws on its own terminal row, which it overwrites on every frame and leaves in place
#              when the process exits (the caller, normally monitor, erases it).
#
# Arguments:
#   $1 - pid (integer, required): Process ID to watch; the indicator stops when this process exits.
#   $2 - message (string, required): Message to display alongside the indicator.
#   $3 - color (string, required): ANSI escape code used to color the indicator and message.
#   $@ - frames (string, required): One or more frames that make up the animation
#        (all arguments after the first three).
#
# Globals:
#   RESET_COLOR (read): ANSI reset sequence applied after each frame to restore default color.
#
# Returns:
#   0 - The watched process exited (indicator loop completed).
#
# Examples:
#   draw_loading_indicator "$pid" "Building" "\033[36m" "⠋" "⠙" "⠹" "⠸"
#   draw_loading_indicator "$pid" "Loading" "\033[33m" "|" "/" "-" "\\"
draw_loading_indicator() {
    _dli_pid="$1"
    _dli_message="$2"
    _dli_color="$3"

    shift 3

    # Advance one line so the indicator has its own display row.
    printf '\n'

    # Loop while the process is still running. "$@" now holds only the frames.
    while kill -0 "$_dli_pid" 2>/dev/null; do
        for _dli_frame in "$@"; do
            kill -0 "$_dli_pid" 2>/dev/null || break
            printf '\033[A\033[2K%b%s %s%b\n' "$_dli_color" "$_dli_frame" "$_dli_message" "$RESET_COLOR"
            # Fractional sleep is optional in BusyBox; fall back to whole seconds.
            sleep 0.1 2>/dev/null || sleep 1
        done
    done
}

# Function: draw_loading_spinner
# Description: Displays a braille-spinner loading indicator alongside a message until the given process exits.
#              Falls back to ASCII frames when the locale is not UTF-8.
#
# Arguments:
#   $1 - pid (integer, required): Process ID to watch; the indicator stops when this process exits.
#   $2 - message (string, optional, default: "Loading"): Message to display alongside the indicator.
#   $3 - color (string, optional, default: cyan): ANSI escape code used to color the indicator and message.
#
# Globals:
#   DEFAULT_MESSAGE (read): Fallback message used when $2 is not provided.
#   DEFAULT_LOADING_COLOR (read): Fallback ANSI color used when $3 is not provided.
#   SPINNER_FRAMES (read): Frames of the animation.
#
# Returns:
#   0 - The watched process exited (indicator loop completed).
#
# Examples:
#   draw_loading_spinner "$pid"
#   draw_loading_spinner "$pid" "Working" "\033[33m"
draw_loading_spinner() {
    if _draw_is_utf8; then
        draw_loading_indicator "$1" "${2:-$DEFAULT_MESSAGE}" "${3:-$DEFAULT_LOADING_COLOR}" $SPINNER_FRAMES
    else
        draw_loading_indicator "$1" "${2:-$DEFAULT_MESSAGE}" "${3:-$DEFAULT_LOADING_COLOR}" $ASCII_SPINNER_FRAMES
    fi
}

# Function: draw_loading_dots
# Description: Displays a dots-style loading indicator alongside a message until the given process exits.
#              Falls back to ASCII frames when the locale is not UTF-8.
#
# Arguments:
#   $1 - pid (integer, required): Process ID to watch; the indicator stops when this process exits.
#   $2 - message (string, optional, default: "Loading"): Message to display alongside the indicator.
#   $3 - color (string, optional, default: cyan): ANSI escape code used to color the indicator and message.
#
# Globals:
#   DEFAULT_MESSAGE (read): Fallback message used when $2 is not provided.
#   DEFAULT_LOADING_COLOR (read): Fallback ANSI color used when $3 is not provided.
#   DOT_FRAMES (read): Frames of the animation.
#
# Returns:
#   0 - The watched process exited (indicator loop completed).
#
# Examples:
#   draw_loading_dots "$pid"
#   draw_loading_dots "$pid" "Working" "\033[33m"
draw_loading_dots() {
    if _draw_is_utf8; then
        draw_loading_indicator "$1" "${2:-$DEFAULT_MESSAGE}" "${3:-$DEFAULT_LOADING_COLOR}" $DOT_FRAMES
    else
        draw_loading_indicator "$1" "${2:-$DEFAULT_MESSAGE}" "${3:-$DEFAULT_LOADING_COLOR}" $DOT_FRAMES
    fi
}

# Function: draw_loading_bars
# Description: Displays a bar-fill loading indicator alongside a message until the given process exits.
#              Falls back to ASCII frames when the locale is not UTF-8.
#
# Arguments:
#   $1 - pid (integer, required): Process ID to watch; the indicator stops when this process exits.
#   $2 - message (string, optional, default: "Loading"): Message to display alongside the indicator.
#   $3 - color (string, optional, default: cyan): ANSI escape code used to color the indicator and message.
#
# Globals:
#   DEFAULT_MESSAGE (read): Fallback message used when $2 is not provided.
#   DEFAULT_LOADING_COLOR (read): Fallback ANSI color used when $3 is not provided.
#   BAR_FRAMES (read): Frames of the animation.
#
# Returns:
#   0 - The watched process exited (indicator loop completed).
#
# Examples:
#   draw_loading_bars "$pid"
#   draw_loading_bars "$pid" "Working" "\033[33m"
draw_loading_bars() {
    if _draw_is_utf8; then
        draw_loading_indicator "$1" "${2:-$DEFAULT_MESSAGE}" "${3:-$DEFAULT_LOADING_COLOR}" $BAR_FRAMES
    else
        draw_loading_indicator "$1" "${2:-$DEFAULT_MESSAGE}" "${3:-$DEFAULT_LOADING_COLOR}" $ASCII_BAR_FRAMES
    fi
}

# Function: draw_loading_arrows
# Description: Displays a rotating-arrow loading indicator alongside a message until the given process exits.
#              Falls back to ASCII frames when the locale is not UTF-8.
#
# Arguments:
#   $1 - pid (integer, required): Process ID to watch; the indicator stops when this process exits.
#   $2 - message (string, optional, default: "Loading"): Message to display alongside the indicator.
#   $3 - color (string, optional, default: cyan): ANSI escape code used to color the indicator and message.
#
# Globals:
#   DEFAULT_MESSAGE (read): Fallback message used when $2 is not provided.
#   DEFAULT_LOADING_COLOR (read): Fallback ANSI color used when $3 is not provided.
#   ARROW_FRAMES (read): Frames of the animation.
#
# Returns:
#   0 - The watched process exited (indicator loop completed).
#
# Examples:
#   draw_loading_arrows "$pid"
#   draw_loading_arrows "$pid" "Working" "\033[33m"
draw_loading_arrows() {
    if _draw_is_utf8; then
        draw_loading_indicator "$1" "${2:-$DEFAULT_MESSAGE}" "${3:-$DEFAULT_LOADING_COLOR}" $ARROW_FRAMES
    else
        draw_loading_indicator "$1" "${2:-$DEFAULT_MESSAGE}" "${3:-$DEFAULT_LOADING_COLOR}" $ASCII_ARROW_FRAMES
    fi
}

# Function: draw_loading_clock
# Description: Displays a clock-emoji loading indicator alongside a message until the given process exits.
#              Falls back to ASCII frames when the locale is not UTF-8.
#
# Arguments:
#   $1 - pid (integer, required): Process ID to watch; the indicator stops when this process exits.
#   $2 - message (string, optional, default: "Loading"): Message to display alongside the indicator.
#   $3 - color (string, optional, default: cyan): ANSI escape code used to color the indicator and message.
#
# Globals:
#   DEFAULT_MESSAGE (read): Fallback message used when $2 is not provided.
#   DEFAULT_LOADING_COLOR (read): Fallback ANSI color used when $3 is not provided.
#   CLOCK_FRAMES (read): Frames of the animation.
#
# Returns:
#   0 - The watched process exited (indicator loop completed).
#
# Examples:
#   draw_loading_clock "$pid"
#   draw_loading_clock "$pid" "Working" "\033[33m"
draw_loading_clock() {
    if _draw_is_utf8; then
        draw_loading_indicator "$1" "${2:-$DEFAULT_MESSAGE}" "${3:-$DEFAULT_LOADING_COLOR}" $CLOCK_FRAMES
    else
        draw_loading_indicator "$1" "${2:-$DEFAULT_MESSAGE}" "${3:-$DEFAULT_LOADING_COLOR}" $ASCII_SPINNER_FRAMES
    fi
}
