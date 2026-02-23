#!/usr/bin/env bash

# Function: podman_enter
# Description: Opens an interactive terminal session inside a Podman container.
#              If the container is stopped, it is started automatically before attaching.
#
# Arguments:
#   --name NAME (string, required): Name or ID of the container to enter.
#   --user USER (string, optional, default: "root"): User to run the shell as.
#   --shell SHELL (string, optional, default: "/bin/bash"): Shell executable to launch.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - Session ended normally.
#   1 - Invalid or missing arguments, or Podman not installed.
#   2 - Container does not exist.
#   3 - Container failed to start.
#
# Examples:
#   podman_enter --name myapp
#   podman_enter --name webserver --user www-data --shell /bin/sh
function podman_enter {
    local name=""
    local user="root"
    local shell="/bin/bash"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            -u|--user)
                user="$2"
                shift 2
                ;;
            -s|--shell)
                shell="$2"
                shift 2
                ;;
            *)
                error "podman_enter: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "podman_enter: --name is required"
        return 1
    fi

    if ! command -v podman &>/dev/null; then
        error "podman_enter: Podman is not installed. Run podman_create first or install Podman manually."
        return 1
    fi

    if ! podman inspect "$name" &>/dev/null; then
        error "podman_enter: container '$name' does not exist"
        return 2
    fi

    local running
    running=$(podman inspect --format='{{.State.Running}}' "$name" 2>/dev/null)
    debug "podman_enter: container '$name' running='$running'"

    if [[ "$running" != "true" ]]; then
        info "Container '$name' is not running — starting it..."
        podman start "$name" >/dev/null 2>&1 &
        monitor $! \
            --style "${SPINNER_LOADING_STYLE}" \
            --message "Starting container '$name'" \
            --success_msg "Container '$name' started." \
            --error_msg "Container '$name' failed to start." || return 3
    fi

    info "Attaching to container '$name' as '$user'..."
    podman exec -it -u "$user" "$name" "$shell"
}
