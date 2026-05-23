#!/usr/bin/env bash

# Function: pct_find_vmid
# Description: Resolves a container hostname to its numeric VMID by searching
#              the output of pct list. If NAME is already a numeric VMID, it is
#              validated via pct status and returned as-is.
#
# Arguments:
#   --name NAME (string, required): Container hostname or numeric VMID to resolve.
#
# Globals:
#   None
#
# Returns:
#   0 - Success; the resolved VMID is printed to stdout.
#   1 - Invalid arguments or PCT not available on this system.
#   2 - No container found with the given name or VMID.
#
# Examples:
#   vmid=$(pct_find_vmid --name mycontainer)
#   vmid=$(pct_find_vmid --name 100)
function pct_find_vmid {
    local name=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            *)
                error "pct_find_vmid: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "pct_find_vmid: --name is required"
        return 1
    fi

    if ! command -v pct &>/dev/null; then
        error "pct_find_vmid: pct is not available. PCT is part of Proxmox VE and cannot be installed on non-Proxmox systems."
        return 1
    fi

    # If name is already a numeric VMID, validate existence and return it.
    if [[ "$name" =~ ^[0-9]+$ ]]; then
        if pct status "$name" &>/dev/null; then
            debug "pct_find_vmid: '$name' is a valid VMID"
            echo "$name"
            return 0
        else
            error "pct_find_vmid: container with VMID '$name' does not exist"
            return 2
        fi
    fi

    # Search pct list by hostname. The Name column is always last ($NF), which
    # correctly handles the optional Lock column being absent or present.
    local vmid
    vmid=$(pct list 2>/dev/null | awk -v name="$name" 'NR>1 && $NF == name {print $1}')

    if [[ -z "$vmid" ]]; then
        error "pct_find_vmid: no container found with name '$name'"
        return 2
    fi

    debug "pct_find_vmid: resolved '$name' -> VMID '$vmid'"
    echo "$vmid"
    return 0
}
