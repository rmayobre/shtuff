#!/usr/bin/env bash

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
#              When terminal zones are active (init_display was called), the bar
#              renders in the status zone instead. Each unique --id gets its own
#              status zone slot, enabling multiple simultaneous progress bars.
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
#   Pinned bar (--lines-above 2) while per-item output scrolls below it:
#
#     Copying [██████████████████████████░░░░░░░░░░░░░░]  50% (1/2)   <- stays here
#     ✓ first.txt copied
#     ⠸ Copying second.txt                                             <- monitor below
#
# Arguments:
#   --current N      (integer, required): Current step/value (0 to --total inclusive).
#   --total N        (integer, required): Total steps/value representing 100%.
#   --message MSG    (string, optional, default: "Progress"): Label printed before the bar.
#   --width N        (integer, optional, default: 40): Number of fill characters in the bar.
#   --id NAME        (string, optional, default: "_default"): Identifier for this progress
#                    bar. When zones are active, each unique ID gets its own status zone
#                    slot, enabling multiple simultaneous progress bars.
#   --lines-above N  (integer, optional, default: 0): Lines between the current cursor
#                    position and the bar line. When non-zero, the cursor is moved up N
#                    lines before drawing and restored to its original position afterward.
#                    Ignored when terminal zones are active.
#   --done           (flag, optional): Force a trailing newline, finalizing the bar output.
#                    Automatically implied when --current equals --total.
#
# Globals:
#   GREEN       (read): ANSI color applied to the filled portion of the bar.
#   RESET_COLOR (read): ANSI reset sequence used to restore terminal color.
#   _SHTUFF_PROGRESS_SLOTS (read/write): Maps progress IDs to status zone slot indices.
#
# Returns:
#   0 - Success.
#   1 - Missing or invalid argument: --current or --total absent or non-numeric,
#       --total is zero, --width is zero or non-numeric, --lines-above is non-numeric,
#       or --current exceeds --total.
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
#   # Pinned bar above per-item monitor output (bar is i+2 lines above after item i)
#   progress --current 0 --total "$total" --message "Copying"
#   printf "\n"
#   for (( i = 0; i < total; i++ )); do
#       cp "${sources[$i]}" "$dest" &
#       monitor $! --message "Copying ${sources[$i]}"
#       progress --current $(( i + 1 )) --total "$total" --message "Copying" \
#           --lines-above $(( i + 2 ))
#   done
#
#   # Multiple simultaneous progress bars with zones
#   init_display --status-lines 4
#   progress --id "images" --current 3 --total 10 --message "Images"
#   progress --id "configs" --current 1 --total 5 --message "Configs"
function progress {
    local current=""
    local total=""
    local message="Progress"
    local width=40
    local lines_above=0
    local done_flag=false
    local progress_id="_default"

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
            -l|--lines-above)
                lines_above="$2"
                shift 2
                ;;
            -d|--done)
                done_flag=true
                shift
                ;;
            --id)
                progress_id="$2"
                shift 2
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

    if ! [[ "$lines_above" =~ ^[0-9]+$ ]]; then
        error "progress: --lines-above must be a non-negative integer"
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

    local bar_line
    printf -v bar_line "%s [%b%s%b%s] %s %s" \
        "$message" \
        "$GREEN" "$bar_filled" \
        "$RESET_COLOR" "$bar_empty" \
        "$pct_str" "$count_str"

    # Zone-aware rendering: render in the status zone when zones are active
    if _zones_active; then
        # Acquire a slot for this progress ID if we don't have one yet
        if [[ -z "${_SHTUFF_PROGRESS_SLOTS[$progress_id]:-}" ]]; then
            local slot
            slot=$(_acquire_status_slot) || {
                error "progress: no free status zone slots"
                return 1
            }
            _SHTUFF_PROGRESS_SLOTS[$progress_id]="$slot"
        fi

        local slot="${_SHTUFF_PROGRESS_SLOTS[$progress_id]}"
        _write_to_status_zone --slot "$slot" --message "$bar_line"

        # On completion, move final bar to log zone and release the slot
        if [[ "$done_flag" == true ]] || (( current == total )); then
            _write_to_log_zone "$bar_line"
            _release_status_slot "$slot"
            unset '_SHTUFF_PROGRESS_SLOTS[$progress_id]'
        fi
        return 0
    fi

    # Non-zone rendering: original behavior

    # Move cursor up to the bar line when it was drawn above the current position.
    if (( lines_above > 0 )); then
        printf "\033[%dA\r" "$lines_above"
    fi

    # Overwrite the current terminal line with the updated bar.
    printf "\r%s" "$bar_line"

    # Print a newline to finalize the bar when complete or explicitly requested.
    local printed_newline=false
    if [[ "$done_flag" == true ]] || (( current == total )); then
        printf "\n"
        printed_newline=true
    fi

    # Restore cursor to its original position below the bar.
    if (( lines_above > 0 )); then
        if [[ "$printed_newline" == true ]]; then
            # The auto-\n already moved down one line; move down the remaining distance.
            if (( lines_above > 1 )); then
                printf "\033[%dB\r" "$((lines_above - 1))"
            fi
        else
            printf "\033[%dB\r" "$lines_above"
        fi
    fi
}
