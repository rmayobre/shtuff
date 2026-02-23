#!/usr/bin/env bash

# Function: pct_enter
# Description: Opens an interactive terminal session inside a Proxmox CT container.
#              If the container is stopped, it is started automatically before attaching.
#              Root access uses pct enter directly; non-root access uses pct exec with su.
#
# Arguments:
#   --vmid VMID (integer, required): Numeric ID of the container to enter.
#   --user USER (string, optional, default: "root"): User to run the shell as inside the container.
#   --shell SHELL (string, optional, default: "/bin/bash"): Shell executable to launch (used
#       when --user is not root).
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - Session ended normally.
#   1 - Invalid or missing arguments, or PCT not available on this system.
#   2 - Container does not exist.
#   3 - Container failed to start.
#
# Examples:
#   pct_enter --vmid 100
#   pct_enter --vmid 101 --user deploy --shell /bin/sh
function pct_enter {
    local vmid=""
    local user="root"
    local shell="/bin/bash"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vmid)
                vmid="$2"
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
                error "pct_enter: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$vmid" ]]; then
        error "pct_enter: --vmid is required"
        return 1
    fi

    if ! command -v pct &>/dev/null; then
        error "pct_enter: pct is not available. PCT is part of Proxmox VE and cannot be installed on non-Proxmox systems."
        return 1
    fi

    if ! pct status "$vmid" &>/dev/null; then
        error "pct_enter: container $vmid does not exist"
        return 2
    fi

    local state
    state=$(pct status "$vmid" 2>/dev/null | awk '{print $2}')
    debug "pct_enter: container $vmid state='$state'"

    if [[ "$state" != "running" ]]; then
        info "Container $vmid is not running — starting it..."
        pct start "$vmid" >/dev/null 2>&1 &
        monitor $! \
            --style "${SPINNER_LOADING_STYLE}" \
            --message "Starting container $vmid" \
            --success_msg "Container $vmid started." \
            --error_msg "Container $vmid failed to start." || return 3
    fi

    if [[ "$user" == "root" ]]; then
        info "Attaching to container $vmid..."
        pct enter "$vmid"
    else
        info "Attaching to container $vmid as '$user'..."
        pct exec "$vmid" -- su -l "$user" -s "$shell"
    fi
}
