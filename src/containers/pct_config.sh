#!/usr/bin/env bash

# Function: pct_config
# Description: Updates configuration settings for an existing Proxmox CT container
#              using 'pct set'. Accepts the same resource flags as pct_create plus
#              any additional flags supported by 'pct set'.
#
# Arguments:
#   --vmid VMID (integer, required): Numeric ID of the container to configure.
#   --hostname HOSTNAME (string, optional): Hostname to assign inside the container.
#   --memory MB (integer, optional): Memory limit in megabytes.
#   --cores N (integer, optional): Number of CPU cores to allocate.
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   Any other flags accepted by 'pct set' may also be passed and are forwarded as-is.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - Configuration updated successfully.
#   1 - Invalid or missing arguments, or PCT not available on this system.
#   2 - Container does not exist.
#   3 - Configuration update failed.
#
# Examples:
#   pct_config --vmid 100 --memory 2048 --cores 4
#   pct_config --vmid 101 --hostname newname
#   pct_config --vmid 102 --memory 1024 --cores 2 --hostname myapp
function pct_config {
    local vmid=""
    local style="${SPINNER_LOADING_STYLE}"
    local -a passthrough=()

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
                passthrough+=("$1")
                shift
                ;;
        esac
    done

    if [[ -z "$vmid" ]]; then
        error "pct_config: --vmid is required"
        return 1
    fi

    if [[ ${#passthrough[@]} -eq 0 ]]; then
        warn "pct_config: no configuration options provided — nothing to update"
        return 0
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "pct_config: not running as root — PCT operations may fail without elevated privileges"
    fi

    if ! command -v pct &>/dev/null; then
        error "pct_config: pct is not available. PCT is part of Proxmox VE and cannot be installed on non-Proxmox systems."
        return 1
    fi

    if ! pct status "$vmid" &>/dev/null; then
        error "pct_config: container $vmid does not exist"
        return 2
    fi

    debug "pct_config: vmid='$vmid' args='${passthrough[*]}'"
    (pct set "$vmid" "${passthrough[@]}" 2>&1 | log_output; exit "${PIPESTATUS[0]}") &
    monitor $! \
        --style "$style" \
        --message "Configuring container $vmid" \
        --success_msg "Container $vmid configuration updated." \
        --error_msg "Container $vmid configuration failed." || return 3

    return 0
}
