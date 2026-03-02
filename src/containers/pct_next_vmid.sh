#!/usr/bin/env bash

# Function: pct_next_vmid
# Description: Finds and prints the next available VMID for a new PCT container.
#              Scans currently allocated VMIDs via pct list and returns the lowest
#              unused integer greater than or equal to the start value.
#
# Arguments:
#   --start N (integer, optional, default: 100): Lowest VMID to consider.
#
# Globals:
#   None
#
# Returns:
#   0 - Success; the next available VMID is printed to stdout.
#   1 - Invalid arguments or PCT not available on this system.
#
# Examples:
#   vmid=$(pct_next_vmid)
#   vmid=$(pct_next_vmid --start 200)
function pct_next_vmid {
    local start=100

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --start)
                start="$2"
                shift 2
                ;;
            *)
                error "pct_next_vmid: unknown option: $1"
                return 1
                ;;
        esac
    done

    if ! [[ "$start" =~ ^[0-9]+$ ]]; then
        error "pct_next_vmid: --start must be a positive integer"
        return 1
    fi

    if ! command -v pct &>/dev/null; then
        error "pct_next_vmid: pct is not available. PCT is part of Proxmox VE and cannot be installed on non-Proxmox systems."
        return 1
    fi

    # Collect all existing VMIDs into a sorted array
    local -a used_vmids
    mapfile -t used_vmids < <(pct list 2>/dev/null | awk 'NR>1 {print $1}' | sort -n)

    debug "pct_next_vmid: used_vmids='${used_vmids[*]}' start='$start'"

    # Build a lookup set for O(1) existence checks
    local -A vmid_set
    local id
    for id in "${used_vmids[@]}"; do
        vmid_set["$id"]=1
    done

    # Find the lowest unused VMID >= start
    local candidate="$start"
    while [[ -n "${vmid_set[$candidate]+_}" ]]; do
        (( candidate++ ))
    done

    echo "$candidate"
    return 0
}
