#!/usr/bin/env bash

# Function: lxc_start
# Description: Starts a stopped LXC container.
#
# Arguments:
#   --name NAME (string, required): Name of the container to start.
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - Container started successfully.
#   1 - Invalid or missing arguments, or LXC not installed.
#   2 - Container does not exist.
#   3 - Container failed to start.
#
# Examples:
#   lxc_start --name mycontainer
#   lxc_start --name webserver --style dots
function lxc_start {
    local name=""
    local style="${SPINNER_LOADING_STYLE}"

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
            *)
                error "lxc_start: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "lxc_start: --name is required"
        return 1
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "lxc_start: not running as root — container operations may fail without elevated privileges"
    fi

    if ! command -v lxc-start &>/dev/null; then
        error "lxc_start: LXC is not installed. Run lxc_create first or install lxc manually."
        return 1
    fi

    if ! lxc-info -n "$name" &>/dev/null; then
        error "lxc_start: container '$name' does not exist"
        return 2
    fi

    debug "lxc_start: starting container '$name'"
    lxc-start -n "$name" &
    monitor $! \
        --style "$style" \
        --message "Starting container '$name'" \
        --success_msg "Container '$name' started." \
        --error_msg "Container '$name' failed to start." || return 3

    debug "lxc_start: container '$name' started successfully"
    return 0
}
