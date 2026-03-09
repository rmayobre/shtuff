#!/bin/sh

# Function: delete
# Description: Removes one or more files or directories, displaying a per-item
#              loading indicator as each target is deleted. When more than one
#              target is provided an overall progress bar is printed above the
#              per-item output and updated in place after every completion.
#              Directories are detected automatically and removed with rm -rf.
#
#              Note: flags (--style, --message, --dry-run) must appear before
#              path arguments.
#
# Arguments:
#   TARGET...     (string, required): One or more positional paths to remove.
#   --style STYLE (string, optional, default: "spinner"): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --message MSG (string, optional, default: "Deleting"): Verb shown in both
#                 the progress bar label and each per-item loading indicator.
#   --dry-run     (flag, optional): Print the delete commands that would be executed
#                 without running them. Defaults to IS_DRY_RUN if not specified.
#
# Globals:
#   DEFAULT_LOADING_STYLE (read): Fallback style used when --style is not provided.
#   GREEN                 (read): ANSI color applied to the filled bar segment.
#   RESET_COLOR           (read): ANSI reset sequence used to restore terminal color.
#   IS_DRY_RUN            (read): When "true", enables dry-run mode by default.
#
# Returns:
#   0 - All items removed successfully.
#   1 - No targets provided, or rm failed for any item.
#
# Examples:
#   delete /tmp/myapp.zip /tmp/patch.diff
#   delete /tmp/myapp_extract
#   delete --style dots --message "Cleaning up" /tmp/myapp_extract /tmp/myapp.zip
delete() {
    local style="$DEFAULT_LOADING_STYLE"
    local message="Deleting"
    local dry_run="${IS_DRY_RUN:-false}"

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -s|--style)
                style="$2"
                shift 2
                ;;
            -m|--message)
                message="$2"
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            -*)
                error "delete: unknown option: $1"
                return 1
                ;;
            *)
                break
                ;;
        esac
    done

    # $@ now contains only path arguments
    if [ "$#" -eq 0 ]; then
        error "delete: at least one target path is required"
        return 1
    fi

    local _total="$#"

    if [ "$dry_run" = "true" ]; then
        local _i=1
        while [ "$_i" -le "$_total" ]; do
            eval "_target=\${$_i}"
            if [ -d "$_target" ]; then
                echo "[DRY RUN] rm -rf \"$_target\""
            else
                echo "[DRY RUN] rm \"$_target\""
            fi
            _i=$(( _i + 1 ))
        done
        return 0
    fi

    if [ "$_total" -gt 1 ]; then
        progress --current 0 --total "$_total" --message "$message"
        printf "\n"
    fi

    local _i=1
    while [ "$_i" -le "$_total" ]; do
        eval "_target=\${$_i}"
        if [ -d "$_target" ]; then
            rm -rf "$_target" &
        else
            rm "$_target" &
        fi
        monitor $! \
            --style "$style" \
            --message "$message $_target" \
            --success_msg "$_target deleted" \
            --error_msg "Failed to delete $_target" || return 1
        if [ "$_total" -gt 1 ]; then
            progress --current "$_i" --total "$_total" --message "$message" \
                --lines-above $(( _i + 1 ))
        fi
        _i=$(( _i + 1 ))
    done
}
