#!/usr/bin/env bash

declare -r SPINNER_LOADING_STYLE="spinner"
declare -r DOTS_LOADING_STYLE="dots"
declare -r BARS_LOADING_STYLE="bars"
declare -r ARROWS_LOADING_STYLE="arrows"
declare -r CLOCK_LOADING_STYLE="clock"

# The default loading style picked if not defined in the "monitor function.
DEFAULT_LOADING_STYLE=$SPINNER_LOADING_STYLE

# Function: monitor
# Description: Monitors a background process by PID, displaying a loading indicator until it exits,
#              then prints a success or error message based on its exit code.
#              When LOG_LEVEL=verbose the loading indicator is suppressed so that streaming command
#              output written to the console is not garbled by the spinner.
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
#   LOG_LEVEL (read): When set to "verbose", the loading indicator is skipped.
#   VERBOSE_LEVEL (read): Constant identifying the verbose log level.
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
        error "No PID provided"
        return 1
    fi

    local style="$DEFAULT_LOADING_STYLE"
    local message="Processing"
    local success_msg="Process completed"
    local error_msg="Process failed"
    local dry_run="${IS_DRY_RUN:-false}"

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
            --dry-run)
                dry_run="true"
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    if [[ "$dry_run" == "true" ]]; then
        return 0
    fi

    # Check if process exists
    if ! kill -0 "$pid" 2>/dev/null; then
        error "Process $pid does not exist"
        return 1
    fi

    # When LOG_LEVEL=verbose, skip the animated indicator — streaming output would garble it
    if [[ "$LOG_LEVEL" == "$VERBOSE_LEVEL" ]]; then
        local exit_code=0
        wait "$pid" 2>/dev/null || exit_code=$?
        if [[ $exit_code -eq 0 && -n "$success_msg" ]]; then
            info "$success_msg"
        elif [[ $exit_code -ne 0 && -n "$error_msg" ]]; then
            error "$error_msg"
        fi
        return $exit_code
    fi

    # Hide cursor and ensure it is restored on interruption.
    tput civis
    trap 'printf "\033[A\033[2K"; tput cnorm' INT TERM EXIT

    # Display loading indicator
    case "$style" in
        "$SPINNER_LOADING_STYLE")
            draw_loading_spinner "$pid" "$message"
            ;;
        "$DOTS_LOADING_STYLE")
            draw_loading_dots "$pid" "$message"
            ;;
        "$BARS_LOADING_STYLE")
            draw_loading_bars "$pid" "$message"
            ;;
        "$ARROWS_LOADING_STYLE")
            draw_loading_arrows "$pid" "$message"
            ;;
        "$CLOCK_LOADING_STYLE")
            draw_loading_clock "$pid" "$message"
            ;;
        *)
            tput cnorm
            trap - INT TERM EXIT
            error "Unknown loading style: $style"
            return 1
            ;;
    esac

    local exit_code=0

    # Collect error code from pid
    wait "$pid" 2>/dev/null || exit_code=$?

    # Move up to the spinner line and erase it
    printf "\033[A\033[2K"

    # Show cursor
    tput cnorm
    trap - INT TERM EXIT

    # Show completion message
    if [[ $exit_code -eq 0 && -n "$success_msg" ]]; then
        info "$success_msg"
    elif [[ $exit_code -ne 0 && -n "$error_msg" ]]; then
        error "$error_msg"
    fi

    return $exit_code
}
