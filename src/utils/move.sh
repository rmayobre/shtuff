#!/usr/bin/env bash

# Function: move
# Description: Moves one or more source files or directories to a destination,
#              displaying a progress bar that advances once per source item.
#              Detects cross-filesystem moves and uses rsync (or cp) plus delete;
#              same-filesystem moves use mv directly.
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
#   1 - Missing required argument, no sources provided, or move/copy/remove failed for any item.
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
    local use_rsync=false
    command -v rsync &>/dev/null && use_rsync=true

    for (( i = 0; i < total; i++ )); do
        local src="${sources[$i]}"

        # Detect cross-filesystem move by comparing device IDs
        local src_dev dest_dev dest_ref
        src_dev=$(stat --format '%d' "$src" 2>/dev/null)
        dest_ref="$dest"
        [[ ! -e "$dest" ]] && dest_ref="$(dirname "$dest")"
        dest_dev=$(stat --format '%d' "$dest_ref" 2>/dev/null)

        if [[ -n "$src_dev" && -n "$dest_dev" && "$src_dev" != "$dest_dev" ]]; then
            # Cross-filesystem: copy then delete
            debug "move: cross-filesystem move detected for '$src'; using copy-then-delete"
            if [[ "$use_rsync" == true ]]; then
                debug "move: using rsync for cross-filesystem copy"
                if ! rsync -a "$src" "$dest" >/dev/null 2>&1; then
                    error "move: rsync failed copying '$src' to '$dest'"
                    return 1
                fi
            elif [[ -d "$src" ]]; then
                debug "move: rsync not found, using cp -r"
                if ! cp -r "$src" "$dest"; then
                    error "move: failed to copy '$src' to '$dest'"
                    return 1
                fi
            else
                debug "move: rsync not found, using cp"
                if ! cp "$src" "$dest"; then
                    error "move: failed to copy '$src' to '$dest'"
                    return 1
                fi
            fi
            if ! rm -rf "$src"; then
                error "move: failed to remove source '$src' after cross-filesystem copy"
                return 1
            fi
        else
            # Same filesystem: atomic mv
            debug "move: same-filesystem move, using mv for '$src'"
            if ! mv "$src" "$dest"; then
                error "move: failed to move '$src' to '$dest'"
                return 1
            fi
        fi

        progress --current $(( i + 1 )) --total "$total" --message "$message"
    done
}
