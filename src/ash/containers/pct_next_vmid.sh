#!/bin/sh

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
pct_next_vmid() {
    local start=100

    while [ "$#" -gt 0 ]; do
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

    case "$start" in
        ''|*[!0-9]*)
            error "pct_next_vmid: --start must be a positive integer"
            return 1
            ;;
    esac

    if ! command -v pct >/dev/null 2>&1; then
        error "pct_next_vmid: pct is not available. PCT is part of Proxmox VE and cannot be installed on non-Proxmox systems."
        return 1
    fi

    # Collect all existing VMIDs into a sorted newline-separated list
    local _used
    _used=$(pct list 2>/dev/null | awk 'NR>1 {print $1}' | sort -n)

    debug "pct_next_vmid: used_vmids='$(printf '%s' "$_used" | tr '\n' ' ')' start='$start'"

    # Find the lowest unused VMID >= start
    local _candidate="$start"
    while printf '%s\n' "$_used" | grep -qx "$_candidate"; do
        _candidate=$(( _candidate + 1 ))
    done

    echo "$_candidate"
    return 0
}
