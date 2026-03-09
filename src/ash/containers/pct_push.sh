#!/bin/sh

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
#   --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.
#
# Globals:
#   IS_DRY_RUN (read): When "true", enables dry-run mode by default.
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
pct_push() {
    local source_path=""
    local dest_path=""
    local vmid=""
    local perms=""
    local owner_user=""
    local owner_group=""
    local style="${SPINNER_LOADING_STYLE}"
    local message="Pushing to container..."
    local dry_run="${IS_DRY_RUN:-false}"

    # Capture positional arguments before named flags
    if [ "$#" -ge 1 ]; then
        case "$1" in
            -*) ;;
            *) source_path="$1"; shift ;;
        esac
    fi

    if [ "$#" -ge 1 ]; then
        case "$1" in
            -*) ;;
            *) dest_path="$1"; shift ;;
        esac
    fi

    while [ "$#" -gt 0 ]; do
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
            --dry-run)
                dry_run="true"
                shift
                ;;
            *)
                error "pct_push: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [ -z "$source_path" ]; then
        error "pct_push: source path is required"
        return 1
    fi

    if [ -z "$dest_path" ]; then
        error "pct_push: destination path inside container is required"
        return 1
    fi

    if [ -z "$vmid" ]; then
        error "pct_push: --vmid is required"
        return 1
    fi

    if [ "$dry_run" = "true" ]; then
        local dry_pct_args="$vmid \"$source_path\" \"$dest_path\""
        [ -n "$perms"       ] && dry_pct_args="${dry_pct_args} --perms $perms"
        [ -n "$owner_user"  ] && dry_pct_args="${dry_pct_args} --user $owner_user"
        [ -n "$owner_group" ] && dry_pct_args="${dry_pct_args} --group $owner_group"
        echo "[DRY RUN] pct push ${dry_pct_args}"
        return 0
    fi

    if [ "$(id -u)" -ne 0 ]; then
        warn "pct_push: not running as root — PCT operations may fail without elevated privileges"
    fi

    if ! command -v pct >/dev/null 2>&1; then
        error "pct_push: pct is not available. PCT is part of Proxmox VE and cannot be installed on non-Proxmox systems."
        return 1
    fi

    if [ ! -f "$source_path" ]; then
        error "pct_push: source file not found: $source_path"
        return 2
    fi

    if ! pct status "$vmid" >/dev/null 2>&1; then
        error "pct_push: container $vmid does not exist"
        return 2
    fi

    # Build pct push arguments using positional params
    set -- "$vmid" "$source_path" "$dest_path"
    [ -n "$perms"       ] && set -- "$@" --perms "$perms"
    [ -n "$owner_user"  ] && set -- "$@" --user "$owner_user"
    [ -n "$owner_group" ] && set -- "$@" --group "$owner_group"

    debug "pct_push: vmid='$vmid' source='$source_path' dest='$dest_path'"
    info "Pushing '$source_path' into container $vmid at '$dest_path'"

    local _fifo
    _fifo=$(mktemp -u /tmp/shtuff_XXXXXX)
    mkfifo "$_fifo"
    log_output < "$_fifo" &
    pct push "$@" > "$_fifo" 2>&1 &
    local _pid=$!
    rm -f "$_fifo"

    monitor "$_pid" \
        --style "$style" \
        --message "$message" \
        --success_msg "Push complete." \
        --error_msg "Push failed." || return 3

    debug "pct_push: completed successfully"
    return 0
}
