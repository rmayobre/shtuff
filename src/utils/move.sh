#!/usr/bin/env bash

# Function: move
# Description: Moves one or more source files or directories to a destination,
#              displaying a per-item loading indicator as each source is moved.
#              The last positional argument is treated as the destination.
#
# Visual Output:
#   Moving three files sequentially:
#
#     ⠸ Moving app.log
#     ✓ app.log moved
#     ⠸ Moving error.log
#     ✓ error.log moved
#     ⠸ Moving debug.log
#     ✓ debug.log moved
#
# Arguments:
#   SOURCE... DEST (string, required): Two or more positional paths. All paths
#                  except the last are sources; the last is the destination.
#   --style STYLE  (string, optional, default: "spinner"): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --message MSG  (string, optional, default: "Moving"): Verb shown in the
#                  per-item loading indicator (e.g. "Moving app.log").
#
# Globals:
#   DEFAULT_LOADING_STYLE (read): Fallback style used when --style is not provided.
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

    for src in "${sources[@]}"; do
        mv "$src" "$dest" &
        monitor $! \
            --style "$style" \
            --message "$message $src" \
            --success_msg "$src moved" \
            --error_msg "Failed to move $src" || return 1
    done
}
