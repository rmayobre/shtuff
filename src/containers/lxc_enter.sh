#!/usr/bin/env bash

# Function: lxc_enter
# Description: Attaches to a running LXC container in an interactive terminal session.
#              If the container is stopped, it will be started automatically before attaching.
#
# Arguments:
#   --name NAME (string, required): Name of the container to enter.
#   --user USER (string, optional, default: "root"): User to run the shell as inside the container.
#   --shell SHELL (string, optional, default: "/bin/bash"): Shell executable to launch.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - Session ended normally.
#   1 - Invalid or missing arguments, or LXC not installed.
#   2 - Container does not exist.
#   3 - Container failed to start.
#
# Examples:
#   lxc_enter --name mycontainer
#   lxc_enter --name webserver --user www-data --shell /bin/sh
function lxc_enter {
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
                error "lxc_enter: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "lxc_enter: --name is required"
        return 1
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "lxc_enter: not running as root — attaching to containers may fail without elevated privileges"
    fi

    if ! command -v lxc-attach &>/dev/null; then
        error "lxc_enter: LXC is not installed. Run lxc_create first or install lxc manually."
        return 1
    fi

    if ! lxc-info -n "$name" &>/dev/null; then
        error "lxc_enter: container '$name' does not exist"
        return 2
    fi

    local state
    state=$(lxc-info -n "$name" -s 2>/dev/null | awk '{print $2}')
    debug "lxc_enter: container '$name' state='$state'"

    if [[ "$state" != "RUNNING" ]]; then
        info "Container '$name' is not running — starting it..."
        lxc-start -n "$name" &
        monitor $! \
            --style "${SPINNER_LOADING_STYLE}" \
            --message "Starting container '$name'" \
            --success_msg "Container '$name' started." \
            --error_msg "Container '$name' failed to start." || return 3
    fi

    info "Attaching to container '$name' as '$user'..."
    lxc-attach -n "$name" -- su -l "$user" -s "$shell"
}
