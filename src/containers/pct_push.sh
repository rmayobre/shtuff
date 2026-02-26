#!/usr/bin/env bash

# Function: pct_push
# Description: Copies a file from the host into a Proxmox CT container using pct push.
#              The container does not need to be running for file transfers.
#              Note: pct push only supports individual files, not directories.
#
# Arguments:
#   $1 - source (string, required): Path to the file on the host to copy.
#   $2 - destination (string, required): Absolute path inside the container to copy to.
#   --vmid VMID (integer, required): Numeric ID of the target container.
#   --perms PERMS (string, optional): File permissions to set (e.g. "0644").
#   --user USER (string, optional): Owner user to set inside the container.
#   --group GROUP (string, optional): Owner group to set inside the container.
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --message MSG (string, optional, default: "Pushing to container..."): Progress message.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - File pushed successfully.
#   1 - Invalid or missing arguments, or PCT not available on this system.
#   2 - Source file does not exist, or container does not exist.
#   3 - Push operation failed.
#
# Examples:
#   pct_push /etc/myapp.conf /etc/myapp.conf --vmid 100
#   pct_push /opt/app/config.json /opt/app/config.json --vmid 101 --perms 0644 --user root
function pct_push {
    local source_path=""
    local dest_path=""
    local vmid=""
    local perms=""
    local owner_user=""
    local owner_group=""
    local style="${SPINNER_LOADING_STYLE}"
    local message="Pushing to container..."

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
            --perms)
                perms="$2"
                shift 2
                ;;
            -u|--user)
                owner_user="$2"
                shift 2
                ;;
            -g|--group)
                owner_group="$2"
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
                error "pct_push: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$source_path" ]]; then
        error "pct_push: source path is required"
        return 1
    fi

    if [[ -z "$dest_path" ]]; then
        error "pct_push: destination path inside container is required"
        return 1
    fi

    if [[ -z "$vmid" ]]; then
        error "pct_push: --vmid is required"
        return 1
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "pct_push: not running as root — PCT operations may fail without elevated privileges"
    fi

    if ! command -v pct &>/dev/null; then
        error "pct_push: pct is not available. PCT is part of Proxmox VE and cannot be installed on non-Proxmox systems."
        return 1
    fi

    if [[ ! -f "$source_path" ]]; then
        error "pct_push: source file not found: $source_path"
        return 2
    fi

    if ! pct status "$vmid" &>/dev/null; then
        error "pct_push: container $vmid does not exist"
        return 2
    fi

    # Build pct push arguments
    local pct_args=("$vmid" "$source_path" "$dest_path")

    if [[ -n "$perms" ]]; then
        pct_args+=(--perms "$perms")
    fi

    if [[ -n "$owner_user" ]]; then
        pct_args+=(--user "$owner_user")
    fi

    if [[ -n "$owner_group" ]]; then
        pct_args+=(--group "$owner_group")
    fi

    debug "pct_push: vmid='$vmid' source='$source_path' dest='$dest_path'"
    info "Pushing '$source_path' into container $vmid at '$dest_path'"

    pct push "${pct_args[@]}" > >(log_output) 2>&1 &
    monitor $! \
        --style "$style" \
        --message "$message" \
        --success_msg "Push complete." \
        --error_msg "Push failed." || return 3

    debug "pct_push: completed successfully"
    return 0
}
