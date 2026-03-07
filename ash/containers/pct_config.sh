#!/bin/sh

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
#   --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.
#   Any other flags accepted by 'pct set' may also be passed and are forwarded as-is.
#
# Globals:
#   IS_DRY_RUN (read): When "true", enables dry-run mode by default.
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
pct_config() {
    local vmid=""
    local style="${SPINNER_LOADING_STYLE}"
    local dry_run="${IS_DRY_RUN:-false}"
    local _pt_count=0

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --vmid)
                vmid="$2"
                shift 2
                ;;
            -s|--style)
                style="$2"
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            *)
                _pt_count=$(( _pt_count + 1 ))
                eval "_pt_${_pt_count}=\$1"
                shift
                ;;
        esac
    done

    if [ -z "$vmid" ]; then
        error "pct_config: --vmid is required"
        return 1
    fi

    if [ "$_pt_count" -eq 0 ]; then
        warn "pct_config: no configuration options provided — nothing to update"
        return 0
    fi

    # Rebuild passthrough args as $@
    set --
    local _i=1
    while [ "$_i" -le "$_pt_count" ]; do
        eval "_v=\$_pt_${_i}"
        set -- "$@" "$_v"
        _i=$(( _i + 1 ))
    done

    if [ "$dry_run" = "true" ]; then
        echo "[DRY RUN] pct set $vmid $*"
        return 0
    fi

    if [ "$(id -u)" -ne 0 ]; then
        warn "pct_config: not running as root — PCT operations may fail without elevated privileges"
    fi

    if ! command -v pct >/dev/null 2>&1; then
        error "pct_config: pct is not available. PCT is part of Proxmox VE and cannot be installed on non-Proxmox systems."
        return 1
    fi

    if ! pct status "$vmid" >/dev/null 2>&1; then
        error "pct_config: container $vmid does not exist"
        return 2
    fi

    debug "pct_config: vmid='$vmid' args='$*'"

    local _fifo
    _fifo=$(mktemp -u /tmp/shtuff_XXXXXX)
    mkfifo "$_fifo"
    log_output < "$_fifo" &
    pct set "$vmid" "$@" > "$_fifo" 2>&1 &
    local _pid=$!
    rm -f "$_fifo"

    monitor "$_pid" \
        --style "$style" \
        --message "Configuring container $vmid" \
        --success_msg "Container $vmid configuration updated." \
        --error_msg "Container $vmid configuration failed." || return 3

    return 0
}
