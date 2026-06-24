#!/usr/bin/env bash

# Function: pct_next_vmid
# Description: Finds and prints the next available VMID for a new PCT container.
#              Queries the Proxmox cluster API via pvesh to obtain the next free VMID
#              (shared across both LXC containers and QEMU VMs). Falls back to scanning
#              pct list and qm list directly when pvesh is unavailable.
#
# Arguments:
#   --start N (integer, optional, default: 100): Lowest VMID to consider. Only used
#       in fallback mode; pvesh /cluster/nextid always returns the cluster-wide next ID.
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

    # Prefer the cluster API — it covers both LXC containers and QEMU VMs atomically.
    # pvesh /cluster/nextid always scans from 100; if that result falls below --start
    # we fall through to the scan so the start constraint is honoured.
    if command -v pvesh &>/dev/null; then
        local next_id
        next_id=$(pvesh get /cluster/nextid 2>/dev/null | tr -d '[:space:]"')
        if [[ "$next_id" =~ ^[0-9]+$ && "$next_id" -ge "$start" ]]; then
            debug "pct_next_vmid: pvesh /cluster/nextid -> '$next_id'"
            echo "$next_id"
            return 0
        fi
        if [[ "$next_id" =~ ^[0-9]+$ ]]; then
            debug "pct_next_vmid: pvesh returned '$next_id' which is below start='$start', falling back to list scan"
        else
            debug "pct_next_vmid: pvesh /cluster/nextid returned unexpected output, falling back to list scan"
        fi
    fi

    # Fallback: merge pct list and qm list to cover all allocated VMIDs on this node.
    local -A vmid_set
    local id
    while IFS= read -r id; do
        [[ "$id" =~ ^[0-9]+$ ]] && vmid_set["$id"]=1
    done < <(
        { pct list 2>/dev/null; qm list 2>/dev/null; } | awk 'NR>1 {print $1}'
    )

    debug "pct_next_vmid: fallback scan used_vmids='${!vmid_set[*]}' start='$start'"

    local candidate="$start"
    while [[ -n "${vmid_set[$candidate]+_}" ]]; do
        (( candidate++ ))
    done

    echo "$candidate"
    return 0
}
