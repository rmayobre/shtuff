#!/bin/sh

# Function: progress
# Description: Draws or updates a progress bar in-place on the current terminal line.
#              Call repeatedly with increasing --current values to animate the bar
#              as work progresses. The bar finalizes (prints a trailing newline)
#              automatically when --current equals --total, or immediately when
#              --done is passed.
#
#              When --lines-above N is provided the function moves the cursor up
#              N lines before drawing, then restores the cursor to its original
#              position afterward. This keeps the bar pinned at the top of a
#              block of scrolling output (e.g. per-item monitor messages) without
#              the caller needing to manage cursor movement itself.
#
# Arguments:
#   --current N      (integer, required): Current step/value (0 to --total inclusive).
#   --total N        (integer, required): Total steps/value representing 100%.
#   --message MSG    (string, optional, default: "Progress"): Label printed before the bar.
#   --width N        (integer, optional, default: 40): Number of fill characters in the bar.
#   --lines-above N  (integer, optional, default: 0): Lines between the current cursor
#                    position and the bar line. When non-zero, the cursor is moved up N
#                    lines before drawing and restored to its original position afterward.
#   --done           (flag, optional): Force a trailing newline, finalizing the bar output.
#                    Automatically implied when --current equals --total.
#
# Globals:
#   GREEN       (read): ANSI color applied to the filled portion of the bar.
#   RESET_COLOR (read): ANSI reset sequence used to restore terminal color.
#
# Returns:
#   0 - Success.
#   1 - Missing or invalid argument: --current or --total absent or non-numeric,
#       --total is zero, --width is zero or non-numeric, --lines-above is non-numeric,
#       or --current exceeds --total.
#
# Examples:
#   progress --current 4 --total 10 --message "Downloading"
#   progress --current 0 --total "$total" --message "Copying"
progress() {
    local current=""
    local total=""
    local message="Progress"
    local width=40
    local lines_above=0
    local done_flag="false"

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -c|--current)
                current="$2"
                shift 2
                ;;
            -t|--total)
                total="$2"
                shift 2
                ;;
            -m|--message)
                message="$2"
                shift 2
                ;;
            -w|--width)
                width="$2"
                shift 2
                ;;
            -l|--lines-above)
                lines_above="$2"
                shift 2
                ;;
            -d|--done)
                done_flag="true"
                shift
                ;;
            *)
                error "progress: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [ -z "$current" ]; then
        error "progress: --current is required"
        return 1
    fi

    if [ -z "$total" ]; then
        error "progress: --total is required"
        return 1
    fi

    case "$current" in
        ''|*[!0-9]*)
            error "progress: --current must be a non-negative integer"
            return 1
            ;;
    esac

    case "$total" in
        ''|*[!0-9]*)
            error "progress: --total must be a positive integer"
            return 1
            ;;
    esac
    if [ "$total" -eq 0 ]; then
        error "progress: --total must be a positive integer"
        return 1
    fi

    case "$width" in
        ''|*[!0-9]*)
            error "progress: --width must be a positive integer"
            return 1
            ;;
    esac
    if [ "$width" -eq 0 ]; then
        error "progress: --width must be a positive integer"
        return 1
    fi

    case "$lines_above" in
        ''|*[!0-9]*)
            error "progress: --lines-above must be a non-negative integer"
            return 1
            ;;
    esac

    if [ "$current" -gt "$total" ]; then
        error "progress: --current ($current) exceeds --total ($total)"
        return 1
    fi

    # Move cursor up to the bar line when it was drawn above the current position.
    if [ "$lines_above" -gt 0 ]; then
        printf "\033[%dA\r" "$lines_above"
    fi

    # Calculate how many characters to fill vs leave empty.
    local percent=$(( current * 100 / total ))
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))

    # Build the filled and empty bar segments character by character.
    local bar_filled=""
    local bar_empty=""
    local i=0
    while [ "$i" -lt "$filled" ]; do
        bar_filled="${bar_filled}█"
        i=$(( i + 1 ))
    done
    i=0
    while [ "$i" -lt "$empty" ]; do
        bar_empty="${bar_empty}░"
        i=$(( i + 1 ))
    done

    # Format percentage right-aligned to 3 chars and count with equal-width fields.
    local pct_str count_str count_width
    count_width=${#total}
    pct_str=$(printf "%3d%%" "$percent")
    count_str=$(printf "(%${count_width}d/%d)" "$current" "$total")

    # Overwrite the current terminal line with the updated bar.
    printf "\r%s [%b%s%b%s] %s %s" \
        "$message" \
        "$GREEN" "$bar_filled" \
        "$RESET_COLOR" "$bar_empty" \
        "$pct_str" "$count_str"

    # Print a newline to finalize the bar when complete or explicitly requested.
    local printed_newline="false"
    if [ "$done_flag" = "true" ] || [ "$current" -eq "$total" ]; then
        printf "\n"
        printed_newline="true"
    fi

    # Restore cursor to its original position below the bar.
    if [ "$lines_above" -gt 0 ]; then
        if [ "$printed_newline" = "true" ]; then
            if [ "$lines_above" -gt 1 ]; then
                printf "\033[%dB\r" "$(( lines_above - 1 ))"
            fi
        else
            printf "\033[%dB\r" "$lines_above"
        fi
    fi
}
