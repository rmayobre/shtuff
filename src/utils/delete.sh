#!/usr/bin/env bash

# Function: delete
# Description: Deletes a file or directory with a progress indicator. Automatically
#              handles both files and directories (recursive removal).
#
# Arguments:
#   $1 - target (string, required): Path to the file or directory to delete.
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --message MSG (string, optional, default: "Deleting..."): Message shown during progress.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - Deletion completed successfully.
#   1 - Invalid or missing arguments.
#   2 - Target path does not exist.
#   3 - Deletion operation failed.
#
# Examples:
#   delete /tmp/myapp_extract
#   delete /var/log/myapp.log --style dots --message "Removing old logs"
function delete {
    local target_path=""
    local style="${SPINNER_LOADING_STYLE}"
    local message="Deleting..."

    # Capture positional argument before named flags
    if [[ $# -ge 1 && "$1" != -* ]]; then
        target_path="$1"
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
                error "delete: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$target_path" ]]; then
        error "delete: target path is required"
        return 1
    fi

    if [[ ! -e "$target_path" ]]; then
        error "delete: target not found: $target_path"
        return 2
    fi

    debug "delete: target='$target_path' style='$style'"

    if [[ -d "$target_path" ]]; then
        local item_count
        item_count=$(find "$target_path" -mindepth 1 2>/dev/null | wc -l)
        info "Deleting directory '$target_path' ($item_count item(s))"
    else
        info "Deleting file '$target_path'"
    fi

    rm -rf "$target_path" >/dev/null 2>&1 &

    monitor $! \
        --style "$style" \
        --message "$message" \
        --success_msg "Deletion complete." \
        --error_msg "Deletion failed." || return 3

    debug "delete: completed successfully"
    return 0
}
