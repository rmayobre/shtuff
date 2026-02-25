#!/usr/bin/env bash

# Function: pct_start
# Description: Starts a stopped Proxmox CT container.
#
# Arguments:
#   --vmid VMID (integer, required): Numeric ID of the container to start.
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - Container started successfully.
#   1 - Invalid or missing arguments, or PCT not available on this system.
#   2 - Container does not exist.
#   3 - Container failed to start.
#
# Examples:
#   pct_start --vmid 100
#   pct_start --vmid 101 --style dots
function pct_start {
    local vmid=""
    local style="${SPINNER_LOADING_STYLE}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vmid)
                vmid="$2"
                shift 2
                ;;
            -s|--style)
                style="$2"
                shift 2
                ;;
            *)
                error "pct_start: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$vmid" ]]; then
        error "pct_start: --vmid is required"
        return 1
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "pct_start: not running as root — PCT operations may fail without elevated privileges"
    fi

    if ! command -v pct &>/dev/null; then
        error "pct_start: pct is not available. PCT is part of Proxmox VE and cannot be installed on non-Proxmox systems."
        return 1
    fi

    if ! pct status "$vmid" &>/dev/null; then
        error "pct_start: container $vmid does not exist"
        return 2
    fi

    debug "pct_start: starting container $vmid"
    pct start "$vmid" &
    monitor $! \
        --style "$style" \
        --message "Starting container $vmid" \
        --success_msg "Container $vmid started." \
        --error_msg "Container $vmid failed to start." || return 3

    debug "pct_start: container $vmid started successfully"
    return 0
}
