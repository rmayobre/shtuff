#!/usr/bin/env bash

declare -r SPINNER_LOADING_STYLE="spinner"
declare -r DOTS_LOADING_STYLE="dots"
declare -r BARS_LOADING_STYLE="bars"
declare -r ARROWS_LOADING_STYLE="arrows"
declare -r CLOCK_LOADING_STYLE="clock"

# The default loading style picked if not defined in the "monitor functionn.
DEFAULT_LOADING_STYLE=$SPINNER_LOADING_STYLE

# Function: monitor_process
# Description: Monitors a running process by PID and displays loading indicator
# Parameters:
#   $1 - pid (integer, required): Process ID to monitor
#   $2 - style (string, optional): Loading indicator style
#        Valid: spinner, dots, bars, arrows, clock
#        Default: "spinner"
#   $3 - message (string, optional): Message to display during monitoring
#        Default: "Processing"
#   $4 - success_msg (string, optional): Success message to display
#        Default: "Process completed"
#   $5 - error_msg (string, optional): Error message to display
#        Default: "Process failed"
# Returns: Exit code of the monitored process
# Note: Process must exist and be accessible to current user
function monitor {
    local pid=$1

    shift

    if [[ -z "$pid" ]]; then
        echo "Error: No PID provided"
        return 1
    fi

    local style="$DEFAULT_LOADING_STYLE"
    local message="Processing"
    local success_msg="Process completed"
    local error_msg="Process failed"

    while (( "$#" )); do
        case "$1" in
            -m|--message)
                message="$2"
                shift 2
                ;;
            -s|--style)
                style="$2"
                shift 2
                ;;
            -sm|--success_msg)
                success_msg="$2"
                shift 2
                ;;
            -e|--error_msg)
                error_msg="$2"
                shift 2
                ;;
            *)
                break
                ;;
        esac
    done

    # Check if process exists
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "Error: Process $pid does not exist"
        return 1
    fi

    # Dislay loading indicator
    case "$style" in
        "$SPINNER_LOADING_STYLE")
            # Hide cursor
            tput civis

            draw_loading_spinner "$pid" "$message"
            ;;
        "$DOTS_LOADING_STYLE")
            # Hide cursor
            tput civis

            draw_loading_dots "$pid" "$message"
            ;;
        "$BARS_LOADING_STYLE")
            # Hide cursor
            tput civis

            draw_loading_bars "$pid" "$message"
            ;;
        "$ARROWS_LOADING_STYLE")
            # Hide cursor
            tput civis

            draw_loading_arrows "$pid" "$message"
            ;;
        "$CLOCK_LOADING_STYLE")
            # Hide cursor
            tput civis

            draw_loading_clock "$pid" "$message"
            ;;
        *)
            echo "Unknown loading style: $style"
            exit 1
            ;;
    esac

    local exit_code=0

    # Collect error code from pid
    wait "$pid" 2>/dev/null || exit_code=$?

    # Clear the line
    printf "\r\033[K"

    # Show cursor
    tput cnorm

    # Show completion message
    if [[ $exit_code -eq 0 && -n "$success_msg" ]]; then
        echo -e "\033[32m✓ $success_msg${RESET_COLOR}"
    elif [[ $exit_code -ne 0 && -n "$error_msg" ]]; then
        echo -e "\033[31m✗ $error_msg${RESET_COLOR}"
    fi

    return $exit_code
}
