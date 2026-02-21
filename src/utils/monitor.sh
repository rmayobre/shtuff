#!/usr/bin/env bash

declare -r SPINNER_LOADING_STYLE="spinner"
declare -r DOTS_LOADING_STYLE="dots"
declare -r BARS_LOADING_STYLE="bars"
declare -r ARROWS_LOADING_STYLE="arrows"
declare -r CLOCK_LOADING_STYLE="clock"

# The default loading style picked if not defined in the "monitor functionn.
DEFAULT_LOADING_STYLE=$SPINNER_LOADING_STYLE

# Function: monitor
# Description: Monitors a background process by PID, displaying a loading indicator until it exits,
#              then prints a success or error message based on its exit code.
#
# Arguments:
#   $1 - pid (integer, required): Process ID of the background process to monitor.
#   --message MSG (string, optional, default: "Processing"): Message shown alongside the loading indicator.
#   --style STYLE (string, optional, default: "spinner"): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --success_msg MSG (string, optional, default: "Process completed"): Message printed on success.
#   --error_msg MSG (string, optional, default: "Process failed"): Message printed on failure.
#
# Globals:
#   DEFAULT_LOADING_STYLE (read): Fallback style used when --style is not provided.
#   SPINNER_LOADING_STYLE (read): Constant identifying the spinner style.
#   DOTS_LOADING_STYLE (read): Constant identifying the dots style.
#   BARS_LOADING_STYLE (read): Constant identifying the bars style.
#   ARROWS_LOADING_STYLE (read): Constant identifying the arrows style.
#   CLOCK_LOADING_STYLE (read): Constant identifying the clock style.
#   RESET_COLOR (read): ANSI reset sequence used to restore terminal color after the completion message.
#
# Returns:
#   0 - The monitored process exited successfully.
#   1 - No PID provided, PID does not exist, or unknown loading style specified.
#   N - Exit code of the monitored process when it exits with a non-zero status.
#
# Examples:
#   some_long_command &
#   monitor $! --message "Building project" --style spinner \
#       --success_msg "Build complete!" --error_msg "Build failed!" || exit 1
#
#   download_file &
#   monitor $! --style dots --message "Downloading"
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
