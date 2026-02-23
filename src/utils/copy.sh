#!/usr/bin/env bash

# Function: copy
# Description: Copies one or more source files or directories to a destination,
#              displaying a per-item loading indicator as each source is copied.
#              When more than one source is provided an overall progress bar is
#              printed above the per-item output and updated in place after every
#              completion. Directories are detected automatically and copied with
#              cp -r. The last positional argument is treated as the destination.
#
# Visual Output:
#   Copying three files — the bar stays pinned on the first line and updates
#   in place while per-item output scrolls below it:
#
#     Copying [████████████████████████████████████████] 100% (3/3)  <- pinned, updates
#     ✓ config.json copied
#     ✓ settings.yaml copied
#     ✓ env.conf copied
#
# Arguments:
#   SOURCE... DEST (string, required): Two or more positional paths. All paths
#                  except the last are sources; the last is the destination.
#   --style STYLE  (string, optional, default: "spinner"): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --message MSG  (string, optional, default: "Copying"): Verb shown in both
#                  the progress bar label and each per-item loading indicator.
#
# Globals:
#   DEFAULT_LOADING_STYLE (read): Fallback style used when --style is not provided.
#   GREEN                 (read): ANSI color applied to the filled bar segment.
#   RESET_COLOR           (read): ANSI reset sequence used to restore terminal color.
#
# Returns:
#   0 - All items copied successfully.
#   1 - Fewer than two paths provided, or cp failed for any item.
#
# Examples:
#   # Copy three config files into /etc/myapp/
#   copy config.json settings.yaml env.conf /etc/myapp/
#
#   # Copy a directory into a staging area
#   copy src/ /tmp/staging/
#
#   # Custom style and label
#   copy --style dots --message "Deploying" dist/ /var/www/html/
function copy {
    local style="$DEFAULT_LOADING_STYLE"
    local message="Copying"
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
                error "copy: unknown option: $1"
                return 1
                ;;
            *)
                paths+=("$1")
                shift
                ;;
        esac
    done

    if (( ${#paths[@]} < 2 )); then
        error "copy: at least one source and a destination are required"
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
        if [[ -d "$src" ]]; then
            cp -r "$src" "$dest" &
        else
            cp "$src" "$dest" &
        fi
        monitor $! \
            --style "$style" \
            --message "$message $src" \
            --success_msg "$src copied" \
            --error_msg "Failed to copy $src" || return 1
        if (( total > 1 )); then
            progress --current $(( i + 1 )) --total "$total" --message "$message" \
                --lines-above $(( i + 2 ))
        fi
    done
}
