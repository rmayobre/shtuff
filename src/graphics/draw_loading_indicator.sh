#!/usr/bin/env bash

# Globals
declare -r DEFAULT_MESSAGE="Loading"
declare -r DEFAULT_LOADING_COLOR="\033[36m"  # Cyan
declare -r RESET_COLOR="\033[0m"
# Indicator Characters
declare -r SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
declare -r DOT_FRAMES=("." ".." "..." "....")
declare -r BAR_FRAMES=("▏" "▎" "▍" "▌" "▋" "▊" "▉" "█")
declare -r ARROW_FRAMES=("←" "↖" "↑" "↗" "→" "↘" "↓" "↙")
declare -r CLOCK_FRAMES=("🕐" "🕑" "🕒" "🕓" "🕔" "🕕" "🕖" "🕗" "🕘" "🕙" "🕚" "🕛")

# Function: draw_loading_indicator
# Description: Displays a continuous loading indicator with specified style and message
# Parameters:
#   $1 - message (string, required): Message to display with indicator
#        Default: $LOADING_MESSAGE
#   $2 - color (string, required): ANSI color code or color name
#        Default: $LOADING_COLOR
#   $3 - frames (array, required): An array of characters used as frames for the loading indicator.
# Returns: None
# Note: This function runs in a loop until pid is done.
function draw_loading_indicator {
    local pid="$1"
    local message="$2"
    local color="$3"

    shift 3

    local -a frames=("$@")

    # Loop while PID is still running.
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${color}${frames[$i]} ${message}${RESET_COLOR}"
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.1
    done
}

# Function: draw_loading_spinner
# Description: Displays a spinner style loading indicator and message
# Parameters:
#   $1 - pid (integer, required): Process ID to monitor when to stop the loading indicator.
#   $2 - message (string, optional): Message to display with indicator
#        Default: $LOADING_MESSAGE
#   $3 - color (string, optional): ANSI color code or color name
#        Default: $LOADING_COLOR
# Returns: None (infinite loop until killed)
# Note: This function runs in an infinite loop until killed
function draw_loading_spinner {
    draw_loading_indicator "$1" \
        "${2:-$DEFAULT_MESSAGE}" \
        "${3:-$DEFAULT_LOADING_COLOR}" \
        "${SPINNER_FRAMES[@]}"
}

# Function: draw_loading_dots
# Description: Displays a loading indicator as a series of dots with a message
# Parameters:
#   $1 - pid (integer, required): Process ID to monitor when to stop the loading indicator.
#   $2 - message (string, optional): Message to display with indicator
#        Default: $LOADING_MESSAGE
#   $3 - color (string, optional): ANSI color code or color name
#        Default: $LOADING_COLOR
# Returns: None (infinite loop until killed)
# Note: This function runs in an infinite loop until killed
function draw_loading_dots {
    draw_loading_indicator "$1" \
        "${2:-$DEFAULT_MESSAGE}" \
        "${3:-$DEFAULT_LOADING_COLOR}" \
        "${DOT_FRAMES[@]}"
}

# Function: draw_loading_bars
# Description: Displays a loading indicator as a series of bars with a message
# Parameters:
#   $1 - pid (integer, required): Process ID to monitor when to stop the loading indicator.
#   $2 - message (string, optional): Message to display with indicator
#        Default: $LOADING_MESSAGE
#   $3 - color (string, optional): ANSI color code or color name
#        Default: $LOADING_COLOR
# Returns: None (infinite loop until killed)
# Note: This function runs in an infinite loop until killed
function draw_loading_bars {
    draw_loading_indicator "$1" \
        "${2:-$DEFAULT_MESSAGE}" \
        "${3:-$DEFAULT_LOADING_COLOR}" \
        "${BAR_FRAMES[@]}"
}

# Function: draw_loading_arrows
# Description: Displays a loading indicator styled as spinning arrows with a message
# Parameters:
#   $1 - pid (integer, required): Process ID to monitor when to stop the loading indicator.
#   $2 - message (string, optional): Message to display with indicator
#        Default: $LOADING_MESSAGE
#   $3 - color (string, optional): ANSI color code or color name
#        Default: $LOADING_COLOR
# Returns: None (infinite loop until killed)
# Note: This function runs in an infinite loop until killed
function draw_loading_arrows {
    draw_loading_indicator "$1" \
        "${2:-$DEFAULT_MESSAGE}" \
        "${3:-$DEFAULT_LOADING_COLOR}" \
        "${ARROW_FRAMES[@]}"
}

# Function: draw_loading_clock
# Description: Displays a loading indicator styled as running clock with a message
# Parameters:
#   $1 - pid (integer, required): Process ID to monitor when to stop the loading indicator.
#   $2 - message (string, optional): Message to display with indicator
#        Default: $LOADING_MESSAGE
#   $3 - color (string, optional): ANSI color code or color name
#        Default: $LOADING_COLOR
# Returns: None (infinite loop until killed)
# Note: This function runs in an infinite loop until killed
function draw_loading_clock {
    draw_loading_indicator "$1" \
        "${2:-$DEFAULT_MESSAGE}" \
        "${3:-$DEFAULT_LOADING_COLOR}" \
        "${CLOCK_FRAMES[@]}"
}
