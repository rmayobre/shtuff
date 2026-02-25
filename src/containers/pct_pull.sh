#!/usr/bin/env bash

# Function: pct_pull
# Description: Copies a file from inside a Proxmox CT container to the host using pct pull.
#              The container does not need to be running for file transfers.
#              Note: pct pull only supports individual files, not directories.
#
# Arguments:
#   $1 - source (string, required): Absolute path to the file inside the container.
#   $2 - destination (string, required): Path on the host to copy the file to.
#   --vmid VMID (integer, required): Numeric ID of the source container.
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --message MSG (string, optional, default: "Pulling from container..."): Progress message.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - File pulled successfully.
#   1 - Invalid or missing arguments, or PCT not available on this system.
#   2 - Container does not exist.
#   3 - Pull operation failed.
#
# Examples:
#   pct_pull /etc/myapp.conf /tmp/myapp.conf --vmid 100
#   pct_pull /var/log/app.log /tmp/app.log --vmid 101 --style dots --message "Fetching log"
function pct_pull {
    local source_path=""
    local dest_path=""
    local vmid=""
    local style="${SPINNER_LOADING_STYLE}"
    local message="Pulling from container..."

    # Capture positional arguments before named flags
    if [[ $# -ge 1 && "$1" != -* ]]; then
        source_path="$1"
        shift
    fi

    if [[ $# -ge 1 && "$1" != -* ]]; then
        dest_path="$1"
        shift
    fi

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
            -m|--message)
                message="$2"
                shift 2
                ;;
            *)
                error "pct_pull: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$source_path" ]]; then
        error "pct_pull: source path inside container is required"
        return 1
    fi

    if [[ -z "$dest_path" ]]; then
        error "pct_pull: destination path on host is required"
        return 1
    fi

    if [[ -z "$vmid" ]]; then
        error "pct_pull: --vmid is required"
        return 1
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "pct_pull: not running as root — PCT operations may fail without elevated privileges"
    fi

    if ! command -v pct &>/dev/null; then
        error "pct_pull: pct is not available. PCT is part of Proxmox VE and cannot be installed on non-Proxmox systems."
        return 1
    fi

    if ! pct status "$vmid" &>/dev/null; then
        error "pct_pull: container $vmid does not exist"
        return 2
    fi

    debug "pct_pull: vmid='$vmid' source='$source_path' dest='$dest_path'"
    info "Pulling '$source_path' from container $vmid to '$dest_path'"

    pct pull "$vmid" "$source_path" "$dest_path" >/dev/null 2>&1 &
    monitor $! \
        --style "$style" \
        --message "$message" \
        --success_msg "Pull complete." \
        --error_msg "Pull failed." || return 3

    debug "pct_pull: completed successfully"
    return 0
}
