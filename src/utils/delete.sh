#!/usr/bin/env bash

# Function: delete
# Description: Removes one or more files or directories, displaying a per-item
#              loading indicator as each target is deleted. Directories are
#              detected automatically and removed with rm -rf.
#
# Visual Output:
#   Deleting three items sequentially:
#
#     ⠸ Deleting /tmp/myapp.zip
#     ✓ /tmp/myapp.zip deleted
#     ⠸ Deleting /tmp/myapp_extract
#     ✓ /tmp/myapp_extract deleted
#     ⠸ Deleting /tmp/patch.diff
#     ✓ /tmp/patch.diff deleted
#
# Arguments:
#   TARGET...     (string, required): One or more positional paths to remove.
#   --style STYLE (string, optional, default: "spinner"): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --message MSG (string, optional, default: "Deleting"): Verb shown in the
#                 per-item loading indicator (e.g. "Deleting /tmp/myapp.zip").
#
# Globals:
#   DEFAULT_LOADING_STYLE (read): Fallback style used when --style is not provided.
#
# Returns:
#   0 - All items removed successfully.
#   1 - No targets provided, or rm failed for any item.
#
# Examples:
#   # Delete two temporary files
#   delete /tmp/myapp.zip /tmp/patch.diff
#
#   # Delete a temporary directory (detected and removed with rm -rf)
#   delete /tmp/myapp_extract
#
#   # Custom style and label
#   delete --style dots --message "Cleaning up" /tmp/myapp_extract /tmp/myapp.zip
function delete {
    local style="$DEFAULT_LOADING_STYLE"
    local message="Deleting"
    local -a targets=()

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
                error "delete: unknown option: $1"
                return 1
                ;;
            *)
                targets+=("$1")
                shift
                ;;
        esac
    done

    if (( ${#targets[@]} == 0 )); then
        error "delete: at least one target path is required"
        return 1
    fi

    for target in "${targets[@]}"; do
        if [[ -d "$target" ]]; then
            rm -rf "$target" &
        else
            rm "$target" &
        fi
        monitor $! \
            --style "$style" \
            --message "$message $target" \
            --success_msg "$target deleted" \
            --error_msg "Failed to delete $target" || return 1
    done
}
