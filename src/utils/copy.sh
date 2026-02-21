#!/usr/bin/env bash

# Function: copy
# Description: Copies one or more source files or directories to a destination,
#              displaying a progress bar that advances once per source item.
#              Uses rsync when available for reliable transfers; falls back to cp.
#              Pass --recursive to handle directories when rsync is not present (maps to cp -r).
#
# Visual Output:
#   Copying three files, after the second completes:
#
#     Copying [█████████████████████████████░░░░░░░░░░░]  66% (2/3)
#
#   All three files copied:
#
#     Copying [████████████████████████████████████████] 100% (3/3)
#
# Arguments:
#   --dest DEST   (string, required): Destination path passed directly to cp or rsync.
#   --recursive   (flag, optional): Copy directories recursively (cp -r fallback only;
#                 rsync handles directories automatically).
#   --message MSG (string, optional, default: "Copying"): Label shown on the progress bar.
#   --            (separator, optional): Treat all subsequent arguments as source paths,
#                 even if they begin with a hyphen.
#   SOURCE...     (string, required): One or more source paths to copy.
#                 May be listed before or after named flags.
#
# Globals:
#   GREEN       (read): ANSI color applied to the filled portion of the progress bar.
#   RESET_COLOR (read): ANSI reset sequence used to restore terminal color.
#
# Returns:
#   0 - All items copied successfully.
#   1 - Missing required argument, no sources provided, or copy failed for any item.
#
# Examples:
#   # Copy three config files into /etc/myapp/
#   copy --dest /etc/myapp config.json settings.yaml env.conf
#
#   # Recursively copy two directories into a staging area
#   copy --recursive --dest /tmp/staging src/ assets/
#
#   # Custom progress label
#   copy --message "Deploying files" --dest /var/www/html dist/*
function copy {
    local dest=""
    local recursive=false
    local message="Copying"
    local -a sources=()

    while (( "$#" )); do
        case "$1" in
            -D|--dest)
                dest="$2"
                shift 2
                ;;
            -r|--recursive)
                recursive=true
                shift
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
                error "copy: unknown option: $1"
                return 1
                ;;
            *)
                sources+=("$1")
                shift
                ;;
        esac
    done

    if [[ -z "$dest" ]]; then
        error "copy: --dest is required"
        return 1
    fi

    if (( ${#sources[@]} == 0 )); then
        error "copy: at least one source path is required"
        return 1
    fi

    local total=${#sources[@]}
    local use_rsync=false
    command -v rsync &>/dev/null && use_rsync=true

    for (( i = 0; i < total; i++ )); do
        local src="${sources[$i]}"
        if [[ "$use_rsync" == true ]]; then
            debug "copy: using rsync for '$src'"
            if ! rsync -a "$src" "$dest" >/dev/null 2>&1; then
                error "copy: rsync failed copying '$src' to '$dest'"
                return 1
            fi
        elif [[ "$recursive" == true || -d "$src" ]]; then
            debug "copy: rsync not found, using cp -r for '$src'"
            if ! cp -r "$src" "$dest"; then
                error "copy: failed to copy '$src' to '$dest'"
                return 1
            fi
        else
            debug "copy: rsync not found, using cp for '$src'"
            if ! cp "$src" "$dest"; then
                error "copy: failed to copy '$src' to '$dest'"
                return 1
            fi
        fi
        progress --current $(( i + 1 )) --total "$total" --message "$message"
    done
}
