#!/usr/bin/env bash

# Function: move
# Description: Moves a file or directory from source to destination with a progress indicator.
#              Detects cross-filesystem moves and uses a copy-then-delete strategy via rsync
#              or cp when needed. Same-filesystem moves use mv directly.
#
# Arguments:
#   $1 - source (string, required): Path to the file or directory to move.
#   $2 - destination (string, required): Destination path.
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --message MSG (string, optional, default: "Moving..."): Message shown during progress.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - Move completed successfully.
#   1 - Invalid or missing arguments.
#   2 - Source path does not exist.
#   3 - Transfer operation failed.
#   4 - Source removal failed after cross-filesystem copy.
#
# Examples:
#   move /tmp/release.tar.gz /opt/myapp/release.tar.gz
#   move /var/data/exports /backup/exports --style bars --message "Moving exports"
function move {
    local source_path=""
    local dest_path=""
    local style="${SPINNER_LOADING_STYLE}"
    local message="Moving..."

    # Capture positional arguments before named flags
    if [[ $# -ge 1 && "$1" != -* ]]; then
        source_path="$1"
        shift
    fi

    if [[ $# -ge 1 && "$1" != -* ]]; then
        dest_path="$1"
        shift
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--style)
                style="$2"
                shift 2
                ;;
            -m|--message)
                message="$2"
                shift 2
                ;;
            *)
                error "move: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$source_path" ]]; then
        error "move: source path is required"
        return 1
    fi

    if [[ -z "$dest_path" ]]; then
        error "move: destination path is required"
        return 1
    fi

    if [[ ! -e "$source_path" ]]; then
        error "move: source not found: $source_path"
        return 2
    fi

    debug "move: source='$source_path' destination='$dest_path' style='$style'"
    info "Moving '$source_path' to '$dest_path'"

    # Detect cross-filesystem moves by comparing device IDs
    local src_dev dest_dev dest_ref
    src_dev=$(stat --format '%d' "$source_path" 2>/dev/null)
    dest_ref="$dest_path"
    if [[ ! -e "$dest_path" ]]; then
        dest_ref="$(dirname "$dest_path")"
    fi
    dest_dev=$(stat --format '%d' "$dest_ref" 2>/dev/null)

    if [[ -n "$src_dev" && -n "$dest_dev" && "$src_dev" != "$dest_dev" ]]; then
        # Cross-filesystem: copy first, then remove source
        warn "move: cross-filesystem move detected; using copy-then-delete strategy"

        if command -v rsync &>/dev/null; then
            debug "move: using rsync for cross-filesystem copy"
            rsync -a "$source_path" "$dest_path" >/dev/null 2>&1 &
        elif [[ -d "$source_path" ]]; then
            debug "move: rsync not found, using cp -r"
            cp -r "$source_path" "$dest_path" >/dev/null 2>&1 &
        else
            debug "move: rsync not found, using cp"
            cp "$source_path" "$dest_path" >/dev/null 2>&1 &
        fi

        monitor $! \
            --style "$style" \
            --message "$message" \
            --success_msg "Transfer complete. Removing source..." \
            --error_msg "Transfer failed." || return 3

        debug "move: removing source '$source_path'"
        rm -rf "$source_path" >/dev/null 2>&1 &

        monitor $! \
            --style "$style" \
            --message "Removing source..." \
            --success_msg "Move complete." \
            --error_msg "Failed to remove source after copy." || return 4
    else
        # Same filesystem: atomic mv
        debug "move: same-filesystem move, using mv"
        mv "$source_path" "$dest_path" >/dev/null 2>&1 &

        monitor $! \
            --style "$style" \
            --message "$message" \
            --success_msg "Move complete." \
            --error_msg "Move failed." || return 3
    fi

    debug "move: completed successfully"
    return 0
}
