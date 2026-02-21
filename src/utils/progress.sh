#!/usr/bin/env bash

# Function: progress
# Description: Draws or updates a progress bar in-place on the current terminal line.
#              Call repeatedly with increasing --current values to animate the bar
#              as work progresses. The bar finalizes (prints a trailing newline)
#              automatically when --current equals --total, or immediately when
#              --done is passed.
#
# Visual Output:
#   In-progress (current = 4, total = 10, message = "Downloading", width = 40):
#
#     Downloading [████████████████░░░░░░░░░░░░░░░░░░░░░░░░]  40% ( 4/10)
#
#   Complete (current = 10, total = 10):
#
#     Downloading [████████████████████████████████████████] 100% (10/10)
#
#   With a wider bar (--width 60) and custom message at 75%:
#
#     Installing  [█████████████████████████████████████████████░░░░░░░░░░░░░░░]  75% (15/20)
#
# Arguments:
#   --current N   (integer, required): Current step/value (0 to --total inclusive).
#   --total N     (integer, required): Total steps/value representing 100%.
#   --message MSG (string, optional, default: "Progress"): Label printed before the bar.
#   --width N     (integer, optional, default: 40): Number of fill characters in the bar.
#   --done        (flag, optional): Force a trailing newline, finalizing the bar output.
#                 Automatically implied when --current equals --total.
#
# Globals:
#   GREEN       (read): ANSI color applied to the filled portion of the bar.
#   RESET_COLOR (read): ANSI reset sequence used to restore terminal color.
#
# Returns:
#   0 - Success.
#   1 - Missing or invalid argument: --current or --total absent or non-numeric,
#       --total is zero, --width is zero or non-numeric, or --current exceeds --total.
#
# Examples:
#   # Iterate over a list of files and report progress after each one
#   local files=(file1 file2 file3 file4 file5)
#   local total=${#files[@]}
#   for i in "${!files[@]}"; do
#       process "${files[$i]}"
#       progress --current $(( i + 1 )) --total "$total" --message "Processing files"
#   done
#
#   # Custom bar width for a download loop
#   for i in $(seq 1 20); do
#       sleep 0.05
#       progress --current "$i" --total 20 --message "Downloading" --width 60
#   done
#
#   # Manually finalize the bar before reaching --total
#   progress --current 7 --total 10 --message "Uploading" --done
function progress {
    local current=""
    local total=""
    local message="Progress"
    local width=40
    local done_flag=false

    while (( "$#" )); do
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
            -d|--done)
                done_flag=true
                shift
                ;;
            *)
                error "progress: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$current" ]]; then
        error "progress: --current is required"
        return 1
    fi

    if [[ -z "$total" ]]; then
        error "progress: --total is required"
        return 1
    fi

    if ! [[ "$current" =~ ^[0-9]+$ ]]; then
        error "progress: --current must be a non-negative integer"
        return 1
    fi

    if ! [[ "$total" =~ ^[0-9]+$ ]] || (( total == 0 )); then
        error "progress: --total must be a positive integer"
        return 1
    fi

    if ! [[ "$width" =~ ^[0-9]+$ ]] || (( width == 0 )); then
        error "progress: --width must be a positive integer"
        return 1
    fi

    if (( current > total )); then
        error "progress: --current ($current) exceeds --total ($total)"
        return 1
    fi

    # Calculate how many characters to fill vs leave empty.
    local percent=$(( current * 100 / total ))
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))

    # Build the filled and empty bar segments character by character.
    local bar_filled=""
    local bar_empty=""
    local i
    for (( i = 0; i < filled; i++ )); do
        bar_filled+="█"
    done
    for (( i = 0; i < empty; i++ )); do
        bar_empty+="░"
    done

    # Format percentage right-aligned to 3 chars and count with equal-width fields.
    local pct_str count_str count_width
    count_width=${#total}
    printf -v pct_str "%3d%%" "$percent"
    printf -v count_str "(%${count_width}d/%d)" "$current" "$total"

    # Overwrite the current terminal line with the updated bar.
    printf "\r%s [%b%s%b%s] %s %s" \
        "$message" \
        "$GREEN" "$bar_filled" \
        "$RESET_COLOR" "$bar_empty" \
        "$pct_str" "$count_str"

    # Print a newline to finalize the bar when complete or explicitly requested.
    if [[ "$done_flag" == true ]] || (( current == total )); then
        printf "\n"
    fi
}
