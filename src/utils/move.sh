#!/usr/bin/env bash

# Function: move
# Description: Moves one or more source files or directories to a destination,
#              displaying a progress bar that advances once per source item.
#              Each item is moved with the standard mv command.
#
# Visual Output:
#   Moving five items, after the second completes:
#
#     Moving [████████████████░░░░░░░░░░░░░░░░░░░░░░░░]  40% (2/5)
#
#   All five items moved:
#
#     Moving [████████████████████████████████████████] 100% (5/5)
#
# Arguments:
#   --dest DEST   (string, required): Destination path passed directly to mv.
#   --message MSG (string, optional, default: "Moving"): Label shown on the progress bar.
#   --            (separator, optional): Treat all subsequent arguments as source paths,
#                 even if they begin with a hyphen.
#   SOURCE...     (string, required): One or more source paths to move.
#                 May be listed before or after named flags.
#
# Globals:
#   GREEN       (read): ANSI color applied to the filled portion of the progress bar.
#   RESET_COLOR (read): ANSI reset sequence used to restore terminal color.
#
# Returns:
#   0 - All items moved successfully.
#   1 - Missing required argument, no sources provided, or mv failed for any item.
#
# Examples:
#   # Move three log files into an archive directory
#   move --dest /var/log/archive app.log error.log debug.log
#
#   # Move build artifacts to a publish directory
#   move --dest /srv/releases/v2.0 dist/ README.md LICENSE
#
#   # Custom progress label
#   move --message "Archiving backups" --dest /mnt/backup monday.tar tuesday.tar
function move {
    local dest=""
    local message="Moving"
    local -a sources=()

    while (( "$#" )); do
        case "$1" in
            -D|--dest)
                dest="$2"
                shift 2
                ;;
            -m|--message)
                message="$2"
                shift 2
                ;;
            --)
                shift
                sources+=("$@")
                break
                ;;
            -*)
                error "move: unknown option: $1"
                return 1
                ;;
            *)
                sources+=("$1")
                shift
                ;;
        esac
    done

    if [[ -z "$dest" ]]; then
        error "move: --dest is required"
        return 1
    fi

    if (( ${#sources[@]} == 0 )); then
        error "move: at least one source path is required"
        return 1
    fi

    local total=${#sources[@]}

    for (( i = 0; i < total; i++ )); do
        local src="${sources[$i]}"
        if ! mv "$src" "$dest"; then
            error "move: failed to move '$src' to '$dest'"
            return 1
        fi
        progress --current $(( i + 1 )) --total "$total" --message "$message"
    done
}
