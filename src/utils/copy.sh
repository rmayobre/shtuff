#!/usr/bin/env bash

# Function: copy
# Description: Copies one or more source files or directories to a destination,
#              displaying a per-item loading indicator as each source is copied.
#              Directories are detected automatically and copied with cp -r.
#              The last positional argument is treated as the destination.
#
# Visual Output:
#   Copying three files sequentially:
#
#     ⠸ Copying config.json
#     ✓ config.json copied
#     ⠸ Copying settings.yaml
#     ✓ settings.yaml copied
#     ⠸ Copying env.conf
#     ✓ env.conf copied
#
# Arguments:
#   SOURCE... DEST (string, required): Two or more positional paths. All paths
#                  except the last are sources; the last is the destination.
#   --style STYLE  (string, optional, default: "spinner"): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --message MSG  (string, optional, default: "Copying"): Verb shown in the
#                  per-item loading indicator (e.g. "Copying config.json").
#
# Globals:
#   DEFAULT_LOADING_STYLE (read): Fallback style used when --style is not provided.
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

    for src in "${sources[@]}"; do
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
    done
}
