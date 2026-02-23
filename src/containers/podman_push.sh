#!/usr/bin/env bash

# Function: podman_push
# Description: Copies a file or directory from the host into a Podman container.
#              Uses podman cp, which works whether the container is running or stopped.
#
# Arguments:
#   $1 - source (string, required): Path on the host to copy from.
#   $2 - destination (string, required): Absolute path inside the container to copy to.
#   --name NAME (string, required): Name or ID of the target container.
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --message MSG (string, optional, default: "Pushing to container..."): Progress message.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - File(s) pushed successfully.
#   1 - Invalid or missing arguments, or Podman not installed.
#   2 - Source path does not exist, or container does not exist.
#   3 - Copy operation failed.
#
# Examples:
#   podman_push /etc/myapp.conf /etc/myapp.conf --name myapp
#   podman_push /opt/app /opt/app --name webserver --style dots --message "Deploying app"
function podman_push {
    local source_path=""
    local dest_path=""
    local name=""
    local style="${SPINNER_LOADING_STYLE}"
    local message="Pushing to container..."

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
            -n|--name)
                name="$2"
                shift 2
                ;;
            -s|--style)
                style="$2"
                shift 2
                ;;
            -m|--message)
                message="$2"
                shift 2
                ;;
            *)
                error "podman_push: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$source_path" ]]; then
        error "podman_push: source path is required"
        return 1
    fi

    if [[ -z "$dest_path" ]]; then
        error "podman_push: destination path inside container is required"
        return 1
    fi

    if [[ -z "$name" ]]; then
        error "podman_push: --name is required"
        return 1
    fi

    if ! command -v podman &>/dev/null; then
        error "podman_push: Podman is not installed. Run podman_create first or install Podman manually."
        return 1
    fi

    if [[ ! -e "$source_path" ]]; then
        error "podman_push: source not found: $source_path"
        return 2
    fi

    if ! podman inspect "$name" &>/dev/null; then
        error "podman_push: container '$name' does not exist"
        return 2
    fi

    debug "podman_push: source='$source_path' dest='${name}:${dest_path}'"
    info "Pushing '$source_path' into container '$name' at '$dest_path'"

    podman cp "$source_path" "${name}:${dest_path}" >/dev/null 2>&1 &
    monitor $! \
        --style "$style" \
        --message "$message" \
        --success_msg "Push complete." \
        --error_msg "Push failed." || return 3

    debug "podman_push: completed successfully"
    return 0
}
