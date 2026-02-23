#!/usr/bin/env bash

# Function: move
# Description: Moves one or more source files or directories to a destination,
#              displaying a per-item loading indicator as each source is moved.
#              When more than one source is provided an overall progress bar is
#              printed above each item and updated after every completion.
#              The last positional argument is treated as the destination.
#
# Visual Output:
#   Moving three files (bar updates after each item completes):
#
#     Moving [░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░]   0% (0/3)
#     ⠸ Moving app.log
#     ✓ app.log moved
#     Moving [█████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░]  33% (1/3)
#     ⠸ Moving error.log
#     ✓ error.log moved
#     Moving [██████████████████████████░░░░░░░░░░░░░░]  66% (2/3)
#     ⠸ Moving debug.log
#     ✓ debug.log moved
#     Moving [████████████████████████████████████████] 100% (3/3)
#
# Arguments:
#   SOURCE... DEST (string, required): Two or more positional paths. All paths
#                  except the last are sources; the last is the destination.
#   --style STYLE  (string, optional, default: "spinner"): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --message MSG  (string, optional, default: "Moving"): Verb shown in both
#                  the progress bar label and each per-item loading indicator.
#
# Globals:
#   DEFAULT_LOADING_STYLE (read): Fallback style used when --style is not provided.
#   GREEN                 (read): ANSI color applied to the filled bar segment.
#   RESET_COLOR           (read): ANSI reset sequence used to restore terminal color.
#
# Returns:
#   0 - All items moved successfully.
#   1 - Fewer than two paths provided, or mv failed for any item.
#
# Examples:
#   # Move three log files into an archive directory
#   move app.log error.log debug.log /var/log/archive/
#
#   # Move a build artifact to a publish directory
#   move dist/ /srv/releases/v2.0/
#
#   # Custom style and label
#   move --style bars --message "Archiving" monday.tar tuesday.tar /mnt/backup/
function move {
    local style="$DEFAULT_LOADING_STYLE"
    local message="Moving"
    local -a paths=()

    while (( "$#" )); do
        case "$1" in
            -s|--style)
                style="$2"
                shift 2
                ;;
            -m|--message)
                message="$2"
                shift 2
                ;;
            -*)
                error "move: unknown option: $1"
                return 1
                ;;
            *)
                paths+=("$1")
                shift
                ;;
        esac
    done

    if (( ${#paths[@]} < 2 )); then
        error "move: at least one source and a destination are required"
        return 1
    fi

    local dest="${paths[-1]}"
    local -a sources=("${paths[@]:0:${#paths[@]}-1}")
    local total=${#sources[@]}

    if (( total > 1 )); then
        progress --current 0 --total "$total" --message "$message"
        printf "\n"
    fi

    for (( i = 0; i < total; i++ )); do
        local src="${sources[$i]}"
        mv "$src" "$dest" &
        monitor $! \
            --style "$style" \
            --message "$message $src" \
            --success_msg "$src moved" \
            --error_msg "Failed to move $src" || return 1
        if (( total > 1 )); then
            progress --current $(( i + 1 )) --total "$total" --message "$message"
            if (( i + 1 < total )); then
                printf "\n"
            fi
        fi
    done
}
