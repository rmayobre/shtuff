#!/bin/sh

# Function: copy
# Description: Copies one or more source files or directories to a destination,
#              displaying a per-item loading indicator as each source is copied.
#              When more than one source is provided an overall progress bar is
#              printed above the per-item output and updated in place after every
#              completion. Directories are detected automatically and copied with
#              cp -r. The last positional argument is treated as the destination.
#
#              Note: flags (--style, --message, --dry-run) must appear before
#              path arguments.
#
# Arguments:
#   SOURCE... DEST (string, required): Two or more positional paths. All paths
#                  except the last are sources; the last is the destination.
#   --style STYLE  (string, optional, default: "spinner"): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --message MSG  (string, optional, default: "Copying"): Verb shown in both
#                  the progress bar label and each per-item loading indicator.
#   --dry-run      (flag, optional): Print the copy commands that would be executed
#                  without running them. Defaults to IS_DRY_RUN if not specified.
#
# Globals:
#   DEFAULT_LOADING_STYLE (read): Fallback style used when --style is not provided.
#   GREEN                 (read): ANSI color applied to the filled bar segment.
#   RESET_COLOR           (read): ANSI reset sequence used to restore terminal color.
#   IS_DRY_RUN            (read): When "true", enables dry-run mode by default.
#
# Returns:
#   0 - All items copied successfully.
#   1 - Fewer than two paths provided, or cp failed for any item.
#
# Examples:
#   copy config.json settings.yaml env.conf /etc/myapp/
#   copy src/ /tmp/staging/
#   copy --style dots --message "Deploying" dist/ /var/www/html/
copy() {
    local style="$DEFAULT_LOADING_STYLE"
    local message="Copying"
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
                error "copy: unknown option: $1"
                return 1
                ;;
            *)
                break
                ;;
        esac
    done

    # $@ now contains only path arguments
    if [ "$#" -lt 2 ]; then
        error "copy: at least one source and a destination are required"
        return 1
    fi

    local _total=$(( $# - 1 ))
    eval "_dest=\${$#}"

    if [ "$dry_run" = "true" ]; then
        local _i=1
        while [ "$_i" -le "$_total" ]; do
            eval "_src=\${$_i}"
            if [ -d "$_src" ]; then
                echo "[DRY RUN] cp -r \"$_src\" \"$_dest\""
            else
                echo "[DRY RUN] cp \"$_src\" \"$_dest\""
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
        eval "_src=\${$_i}"
        if [ -d "$_src" ]; then
            cp -r "$_src" "$_dest" &
        else
            cp "$_src" "$_dest" &
        fi
        monitor $! \
            --style "$style" \
            --message "$message $_src" \
            --success_msg "$_src copied" \
            --error_msg "Failed to copy $_src" || return 1
        if [ "$_total" -gt 1 ]; then
            progress --current "$_i" --total "$_total" --message "$message" \
                --lines-above $(( _i + 1 ))
        fi
        _i=$(( _i + 1 ))
    done
}
