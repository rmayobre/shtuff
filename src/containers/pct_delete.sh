#!/usr/bin/env bash

# Function: pct_delete
# Description: Destroys a Proxmox CT container, permanently removing it and all its data.
#              The container must be stopped first unless --force is specified.
#
# Arguments:
#   --vmid VMID (integer, required): Numeric ID of the container to destroy.
#   --force (flag, optional): Stop the container before destroying if it is running.
#   --purge (flag, optional): Remove the container from related configurations and jobs.
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - Container destroyed successfully.
#   1 - Invalid or missing arguments, or PCT not available on this system.
#   2 - Container does not exist.
#   3 - Container destruction failed.
#
# Examples:
#   pct_delete --vmid 100
#   pct_delete --vmid 101 --force --purge
function pct_delete {
    local vmid=""
    local force=0
    local purge=0
    local style="${SPINNER_LOADING_STYLE}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vmid)
                vmid="$2"
                shift 2
                ;;
            -f|--force)
                force=1
                shift
                ;;
            --purge)
                purge=1
                shift
                ;;
            -s|--style)
                style="$2"
                shift 2
                ;;
            *)
                error "pct_delete: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$vmid" ]]; then
        error "pct_delete: --vmid is required"
        return 1
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "pct_delete: not running as root — PCT operations may fail without elevated privileges"
    fi

    if ! command -v pct &>/dev/null; then
        error "pct_delete: pct is not available. PCT is part of Proxmox VE and cannot be installed on non-Proxmox systems."
        return 1
    fi

    if ! pct status "$vmid" &>/dev/null; then
        error "pct_delete: container $vmid does not exist"
        return 2
    fi

    local destroy_args=("$vmid")
    if [[ "$force" -eq 1 ]]; then
        destroy_args+=(--force)
    fi
    if [[ "$purge" -eq 1 ]]; then
        destroy_args+=(--purge)
    fi

    debug "pct_delete: destroying container $vmid (force=$force purge=$purge)"
    pct destroy "${destroy_args[@]}" &
    monitor $! \
        --style "$style" \
        --message "Destroying container $vmid" \
        --success_msg "Container $vmid destroyed." \
        --error_msg "Container $vmid destruction failed." || return 3

    debug "pct_delete: container $vmid destroyed successfully"
    return 0
}
