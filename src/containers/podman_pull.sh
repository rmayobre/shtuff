#!/usr/bin/env bash

# Function: podman_pull
# Description: Copies a file or directory from inside a Podman container to the host.
#              Uses podman cp, which works whether the container is running or stopped.
#
# Arguments:
#   $1 - source (string, required): Absolute path inside the container to copy from.
#   $2 - destination (string, required): Path on the host to copy to.
#   --name NAME (string, required): Name or ID of the source container.
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --message MSG (string, optional, default: "Pulling from container..."): Progress message.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - File(s) pulled successfully.
#   1 - Invalid or missing arguments, or Podman not installed.
#   2 - Container does not exist.
#   3 - Copy operation failed.
#
# Examples:
#   podman_pull /etc/myapp.conf /tmp/myapp.conf --name myapp
#   podman_pull /var/log/app /tmp/app-logs --name webserver --style dots --message "Fetching logs"
function podman_pull {
    local source_path=""
    local dest_path=""
    local name=""
    local style="${SPINNER_LOADING_STYLE}"
    local message="Pulling from container..."

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
                error "podman_pull: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$source_path" ]]; then
        error "podman_pull: source path inside container is required"
        return 1
    fi

    if [[ -z "$dest_path" ]]; then
        error "podman_pull: destination path on host is required"
        return 1
    fi

    if [[ -z "$name" ]]; then
        error "podman_pull: --name is required"
        return 1
    fi

    if ! command -v podman &>/dev/null; then
        error "podman_pull: Podman is not installed. Run podman_create first or install Podman manually."
        return 1
    fi

    if ! podman inspect "$name" &>/dev/null; then
        error "podman_pull: container '$name' does not exist"
        return 2
    fi

    debug "podman_pull: source='${name}:${source_path}' dest='$dest_path'"
    info "Pulling '$source_path' from container '$name' to '$dest_path'"

    podman cp "${name}:${source_path}" "$dest_path" >/dev/null 2>&1 &
    monitor $! \
        --style "$style" \
        --message "$message" \
        --success_msg "Pull complete." \
        --error_msg "Pull failed." || return 3

    debug "podman_pull: completed successfully"
    return 0
}
