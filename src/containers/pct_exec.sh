#!/usr/bin/env bash

# Function: pct_exec
# Description: Runs a command inside a Proxmox CT container without opening an
#              interactive session. The container does not need to be running
#              (pct exec can operate on stopped containers for some commands).
#
# Arguments:
#   --vmid VMID (integer, required): Numeric ID of the container to execute the command in.
#   -- COMMAND... (required): The command and its arguments to run inside the container.
#       Everything after -- is passed verbatim to pct exec.
#
# Globals:
#   None
#
# Returns:
#   0 - Command completed successfully.
#   1 - Invalid or missing arguments, or PCT not available on this system.
#   2 - Container does not exist.
#   N - Exit code returned by the command run inside the container.
#
# Examples:
#   pct_exec --vmid 100 -- bash -c "apt-get update -qq && apt-get install -y curl"
#   pct_exec --vmid 101 -- systemctl restart nginx
function pct_exec {
    local vmid=""
    local cmd=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vmid)
                vmid="$2"
                shift 2
                ;;
            --)
                shift
                cmd=("$@")
                break
                ;;
            *)
                error "pct_exec: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$vmid" ]]; then
        error "pct_exec: --vmid is required"
        return 1
    fi

    if [[ ${#cmd[@]} -eq 0 ]]; then
        error "pct_exec: a command is required after --"
        return 1
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "pct_exec: not running as root — PCT operations may fail without elevated privileges"
    fi

    if ! command -v pct &>/dev/null; then
        error "pct_exec: pct is not available. PCT is part of Proxmox VE and cannot be installed on non-Proxmox systems."
        return 1
    fi

    if ! pct status "$vmid" &>/dev/null; then
        error "pct_exec: container $vmid does not exist"
        return 2
    fi

    debug "pct_exec: vmid='$vmid' cmd='${cmd[*]}'"
    pct exec "$vmid" -- "${cmd[@]}"
}
