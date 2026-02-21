#!/usr/bin/env bash

# Function: copy
# Description: Copies a file or directory from source to destination with a progress indicator.
#              Uses rsync when available for reliable transfers; falls back to cp.
#
# Arguments:
#   $1 - source (string, required): Path to the file or directory to copy.
#   $2 - destination (string, required): Destination path for the copy.
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --message MSG (string, optional, default: "Copying..."): Message shown during progress.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - Copy completed successfully.
#   1 - Invalid or missing arguments.
#   2 - Source path does not exist.
#   3 - Copy operation failed.
#
# Examples:
#   copy /etc/nginx /backup/nginx
#   copy /var/data/file.tar.gz /tmp/file.tar.gz --style dots --message "Backing up archive"
function copy {
    local source_path=""
    local dest_path=""
    local style="${SPINNER_LOADING_STYLE}"
    local message="Copying..."

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
                error "copy: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$source_path" ]]; then
        error "copy: source path is required"
        return 1
    fi

    if [[ -z "$dest_path" ]]; then
        error "copy: destination path is required"
        return 1
    fi

    if [[ ! -e "$source_path" ]]; then
        error "copy: source not found: $source_path"
        return 2
    fi

    debug "copy: source='$source_path' destination='$dest_path' style='$style'"
    info "Copying '$source_path' to '$dest_path'"

    if command -v rsync &>/dev/null; then
        debug "copy: using rsync"
        rsync -a "$source_path" "$dest_path" >/dev/null 2>&1 &
    elif [[ -d "$source_path" ]]; then
        debug "copy: rsync not found, using cp -r"
        cp -r "$source_path" "$dest_path" >/dev/null 2>&1 &
    else
        debug "copy: rsync not found, using cp"
        cp "$source_path" "$dest_path" >/dev/null 2>&1 &
    fi

    monitor $! \
        --style "$style" \
        --message "$message" \
        --success_msg "Copy complete." \
        --error_msg "Copy failed." || return 3

    debug "copy: completed successfully"
    return 0
}
