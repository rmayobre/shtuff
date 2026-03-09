#!/bin/sh

# Function: pct_create
# Description: Creates a Proxmox Container Toolkit (PCT) LXC container on a Proxmox VE host.
#              PCT is a Proxmox-specific tool and cannot be installed automatically; this
#              function will error if pct is not found on the system.
#
# Arguments:
#   --vmid VMID (integer, required): Unique numeric ID for the new container (e.g. 100).
#   --template TEMPLATE (string, required): CT template path as shown by pveam
#       (e.g. "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst").
#   --hostname HOSTNAME (string, optional): Hostname to assign inside the container.
#   --memory MB (integer, optional, default: 512): Memory limit in megabytes.
#   --cores N (integer, optional, default: 1): Number of CPU cores to allocate.
#   --storage STORAGE (string, optional, default: "local-lvm"): Storage pool for the root disk.
#   --disk-size GB (integer, optional, default: 8): Root disk size in gigabytes.
#   --password PASSWORD (string, optional): Root password for the container.
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.
#
# Globals:
#   IS_DRY_RUN (read): When "true", enables dry-run mode by default.
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - Container created successfully.
#   1 - Invalid or missing arguments, or PCT not available on this system.
#   3 - Container creation failed.
#
# Examples:
#   pct_create --vmid 100 --template "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
#   pct_create --vmid 101 \
#       --template "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst" \
#       --hostname mycontainer \
#       --memory 1024 \
#       --cores 2 \
#       --storage local-lvm \
#       --disk-size 16
pct_create() {
    local vmid=""
    local template=""
    local hostname=""
    local memory="512"
    local cores="1"
    local storage="local-lvm"
    local disk_size="8"
    local password=""
    local style="${SPINNER_LOADING_STYLE}"
    local dry_run="${IS_DRY_RUN:-false}"

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --vmid)
                vmid="$2"
                shift 2
                ;;
            -t|--template)
                template="$2"
                shift 2
                ;;
            -h|--hostname)
                hostname="$2"
                shift 2
                ;;
            -m|--memory)
                memory="$2"
                shift 2
                ;;
            -c|--cores)
                cores="$2"
                shift 2
                ;;
            --storage)
                storage="$2"
                shift 2
                ;;
            --disk-size)
                disk_size="$2"
                shift 2
                ;;
            -p|--password)
                password="$2"
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
                error "pct_create: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [ -z "$vmid" ]; then
        error "pct_create: --vmid is required"
        return 1
    fi

    if [ -z "$template" ]; then
        error "pct_create: --template is required"
        return 1
    fi

    if [ "$dry_run" = "true" ]; then
        local dry_pct_args="$vmid \"$template\" --memory $memory --cores $cores --storage $storage --rootfs ${storage}:${disk_size}"
        [ -n "$hostname" ] && dry_pct_args="${dry_pct_args} --hostname \"$hostname\""
        [ -n "$password" ] && dry_pct_args="${dry_pct_args} --password ***"
        echo "[DRY RUN] pct create ${dry_pct_args}"
        return 0
    fi

    if [ "$(id -u)" -ne 0 ]; then
        warn "pct_create: not running as root — PCT operations may fail without elevated privileges"
    fi

    if ! command -v pct >/dev/null 2>&1; then
        error "pct_create: pct is not available. PCT is part of Proxmox VE and cannot be installed on non-Proxmox systems."
        return 1
    fi

    # Build pct create arguments using positional params
    set -- "$vmid" "$template" \
        --memory "$memory" \
        --cores "$cores" \
        --storage "$storage" \
        --rootfs "${storage}:${disk_size}"

    [ -n "$hostname" ] && set -- "$@" --hostname "$hostname"
    [ -n "$password" ] && set -- "$@" --password "$password"

    debug "pct_create: vmid='$vmid' template='$template' args='$*'"
    info "Creating PCT container $vmid from template '$template'"

    local _fifo
    _fifo=$(mktemp -u /tmp/shtuff_XXXXXX)
    mkfifo "$_fifo"
    log_output < "$_fifo" &
    pct create "$@" > "$_fifo" 2>&1 &
    local _pid=$!
    rm -f "$_fifo"

    monitor "$_pid" \
        --style "$style" \
        --message "Creating container $vmid" \
        --success_msg "Container $vmid created." \
        --error_msg "Container $vmid creation failed." || return 3

    debug "pct_create: container $vmid created successfully"
    return 0
}
