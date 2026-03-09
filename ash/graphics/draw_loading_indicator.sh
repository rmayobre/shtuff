#!/bin/sh

# Globals
readonly DEFAULT_MESSAGE="Loading"
readonly DEFAULT_LOADING_COLOR="\033[36m"  # Cyan
readonly RESET_COLOR="\033[0m"

# Function: draw_loading_indicator
# Description: Displays a continuous loading indicator with a custom frame set until the given process exits.
#
# Arguments:
#   $1 - pid (integer, required): Process ID to monitor; the indicator stops when this process exits.
#   $2 - message (string, required): Message to display alongside the indicator.
#   $3 - color (string, required): ANSI escape code used to color the indicator and message.
#   $@ - frames (string, required): One or more frame characters that make up the animation
#        (all arguments after the first three are treated as the frame list).
#
# Globals:
#   RESET_COLOR (read): ANSI reset sequence applied after each frame to restore default color.
#
# Returns:
#   0 - The monitored process exited (indicator loop completed).
#
# Examples:
#   draw_loading_indicator "$pid" "Building" "\033[36m" "⠋" "⠙" "⠹" "⠸"
#   draw_loading_indicator "$pid" "Loading" "\033[33m" "|" "/" "-" "\\"
draw_loading_indicator() {
    local pid="$1"
    local message="$2"
    local color="$3"

    shift 3

    local _count=$#
    local _i=0

    # Loop while PID is still running.
    while kill -0 "$pid" 2>/dev/null; do
        _i=$(( (_i % _count) + 1 ))
        eval "_frame=\${$_i}"
        printf "\r${color}${_frame} ${message}${RESET_COLOR}"
        sleep 0.1
    done
}

# Function: draw_loading_spinner
# Description: Displays a braille-spinner loading indicator alongside a message until the given process exits.
#
# Arguments:
#   $1 - pid (integer, required): Process ID to monitor; the indicator stops when this process exits.
#   $2 - message (string, optional, default: "Loading"): Message to display alongside the spinner.
#   $3 - color (string, optional, default: cyan): ANSI escape code used to color the indicator and message.
#
# Globals:
#   DEFAULT_MESSAGE (read): Fallback message used when $2 is not provided.
#   DEFAULT_LOADING_COLOR (read): Fallback ANSI color used when $3 is not provided.
#
# Returns:
#   0 - The monitored process exited (indicator loop completed).
#
# Examples:
#   draw_loading_spinner "$pid"
#   draw_loading_spinner "$pid" "Compiling" "\033[33m"
draw_loading_spinner() {
    draw_loading_indicator "$1" \
        "${2:-$DEFAULT_MESSAGE}" \
        "${3:-$DEFAULT_LOADING_COLOR}" \
        "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏"
}

# Function: draw_loading_dots
# Description: Displays a dots-style loading indicator alongside a message until the given process exits.
#
# Arguments:
#   $1 - pid (integer, required): Process ID to monitor; the indicator stops when this process exits.
#   $2 - message (string, optional, default: "Loading"): Message to display alongside the dots.
#   $3 - color (string, optional, default: cyan): ANSI escape code used to color the indicator and message.
#
# Globals:
#   DEFAULT_MESSAGE (read): Fallback message used when $2 is not provided.
#   DEFAULT_LOADING_COLOR (read): Fallback ANSI color used when $3 is not provided.
#
# Returns:
#   0 - The monitored process exited (indicator loop completed).
#
# Examples:
#   draw_loading_dots "$pid"
#   draw_loading_dots "$pid" "Waiting" "\033[35m"
draw_loading_dots() {
    draw_loading_indicator "$1" \
        "${2:-$DEFAULT_MESSAGE}" \
        "${3:-$DEFAULT_LOADING_COLOR}" \
        "." ".." "..." "...."
}

# Function: draw_loading_bars
# Description: Displays a bar-fill loading indicator alongside a message until the given process exits.
#
# Arguments:
#   $1 - pid (integer, required): Process ID to monitor; the indicator stops when this process exits.
#   $2 - message (string, optional, default: "Loading"): Message to display alongside the bars.
#   $3 - color (string, optional, default: cyan): ANSI escape code used to color the indicator and message.
#
# Globals:
#   DEFAULT_MESSAGE (read): Fallback message used when $2 is not provided.
#   DEFAULT_LOADING_COLOR (read): Fallback ANSI color used when $3 is not provided.
#
# Returns:
#   0 - The monitored process exited (indicator loop completed).
#
# Examples:
#   draw_loading_bars "$pid"
#   draw_loading_bars "$pid" "Installing" "\033[32m"
draw_loading_bars() {
    draw_loading_indicator "$1" \
        "${2:-$DEFAULT_MESSAGE}" \
        "${3:-$DEFAULT_LOADING_COLOR}" \
        "▏" "▎" "▍" "▌" "▋" "▊" "▉" "█"
}

# Function: draw_loading_arrows
# Description: Displays a rotating-arrow loading indicator alongside a message until the given process exits.
#
# Arguments:
#   $1 - pid (integer, required): Process ID to monitor; the indicator stops when this process exits.
#   $2 - message (string, optional, default: "Loading"): Message to display alongside the arrows.
#   $3 - color (string, optional, default: cyan): ANSI escape code used to color the indicator and message.
#
# Globals:
#   DEFAULT_MESSAGE (read): Fallback message used when $2 is not provided.
#   DEFAULT_LOADING_COLOR (read): Fallback ANSI color used when $3 is not provided.
#
# Returns:
#   0 - The monitored process exited (indicator loop completed).
#
# Examples:
#   draw_loading_arrows "$pid"
#   draw_loading_arrows "$pid" "Syncing" "\033[34m"
draw_loading_arrows() {
    draw_loading_indicator "$1" \
        "${2:-$DEFAULT_MESSAGE}" \
        "${3:-$DEFAULT_LOADING_COLOR}" \
        "←" "↖" "↑" "↗" "→" "↘" "↓" "↙"
}

# Function: draw_loading_clock
# Description: Displays a clock-emoji loading indicator alongside a message until the given process exits.
#
# Arguments:
#   $1 - pid (integer, required): Process ID to monitor; the indicator stops when this process exits.
#   $2 - message (string, optional, default: "Loading"): Message to display alongside the clock.
#   $3 - color (string, optional, default: cyan): ANSI escape code used to color the indicator and message.
#
# Globals:
#   DEFAULT_MESSAGE (read): Fallback message used when $2 is not provided.
#   DEFAULT_LOADING_COLOR (read): Fallback ANSI color used when $3 is not provided.
#
# Returns:
#   0 - The monitored process exited (indicator loop completed).
#
# Examples:
#   draw_loading_clock "$pid"
#   draw_loading_clock "$pid" "Scheduling" "\033[36m"
draw_loading_clock() {
    draw_loading_indicator "$1" \
        "${2:-$DEFAULT_MESSAGE}" \
        "${3:-$DEFAULT_LOADING_COLOR}" \
        "🕐" "🕑" "🕒" "🕓" "🕔" "🕕" "🕖" "🕗" "🕘" "🕙" "🕚" "🕛"
}
