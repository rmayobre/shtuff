#!/usr/bin/env bash

# Function: pct_network_show
# Description: Displays the current network interface configuration for a
#              Proxmox CT container by reading 'pct config'. Prints one or
#              all netN entries depending on whether --index is given.
#
# Arguments:
#   --vmid VMID (integer, required): Numeric ID of the container to inspect.
#   --index N (integer, optional): Network interface index. When given, only
#       the net<N> entry is shown. Omit to show all netN entries.
#   --dry-run (flag, optional): Print the system calls that would be executed
#       without running them. Defaults to IS_DRY_RUN if not specified.
#
# Globals:
#   IS_DRY_RUN (read): When "true", enables dry-run mode by default.
#
# Returns:
#   0 - Configuration displayed successfully (or no interfaces found).
#   1 - Invalid or missing arguments, or pct not available.
#   2 - Container does not exist.
#   3 - Failed to retrieve configuration.
#
# Examples:
#   pct_network_show --vmid 100
#   pct_network_show --vmid 100 --index 1
function pct_network_show {
    local vmid=""
    local index=""
    local dry_run="${IS_DRY_RUN:-false}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vmid)
                vmid="$2"
                shift 2
                ;;
            --index)
                index="$2"
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            *)
                error "pct_network_show: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$vmid" ]]; then
        error "pct_network_show: --vmid is required"
        return 1
    fi

    if [[ -n "$index" ]] && ! [[ "$index" =~ ^[0-9]+$ ]]; then
        error "pct_network_show: --index must be a non-negative integer"
        return 1
    fi

    if [[ "$dry_run" == "true" ]]; then
        if [[ -n "$index" ]]; then
            echo "[DRY RUN] pct config $vmid | grep '^net${index}:'"
        else
            echo "[DRY RUN] pct config $vmid | grep '^net[0-9]'"
        fi
        return 0
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "pct_network_show: not running as root — PCT operations may fail without elevated privileges"
    fi

    if ! command -v pct &>/dev/null; then
        error "pct_network_show: pct is not available. PCT is part of Proxmox VE."
        return 1
    fi

    if ! pct status "$vmid" &>/dev/null; then
        error "pct_network_show: container $vmid does not exist"
        return 2
    fi

    local config
    config=$(pct config "$vmid" 2>/dev/null) || {
        error "pct_network_show: failed to read config for container $vmid"
        return 3
    }

    local output
    if [[ -n "$index" ]]; then
        output=$(printf '%s\n' "$config" | grep "^net${index}:")
        if [[ -z "$output" ]]; then
            warn "pct_network_show: no net${index} interface configured on container $vmid"
            return 0
        fi
    else
        output=$(printf '%s\n' "$config" | grep "^net[0-9]")
        if [[ -z "$output" ]]; then
            warn "pct_network_show: no network interfaces configured on container $vmid"
            return 0
        fi
    fi

    printf '%s\n' "$output"
    return 0
}
