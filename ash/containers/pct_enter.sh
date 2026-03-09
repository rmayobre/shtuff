#!/bin/sh

# Function: pct_enter
# Description: Opens an interactive terminal session inside a Proxmox CT container.
#              If the container is stopped, it is started automatically before attaching.
#              Root access uses pct enter directly; non-root access uses pct exec with su.
#
# Arguments:
#   --vmid VMID (integer, required): Numeric ID of the container to enter.
#   --user USER (string, optional, default: "root"): User to run the shell as inside the container.
#   --shell SHELL (string, optional, default: "/bin/bash"): Shell executable to launch (used
#       when --user is not root).
#   --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.
#
# Globals:
#   IS_DRY_RUN (read): When "true", enables dry-run mode by default.
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - Session ended normally.
#   1 - Invalid or missing arguments, or PCT not available on this system.
#   2 - Container does not exist.
#   3 - Container failed to start.
#
# Examples:
#   pct_enter --vmid 100
#   pct_enter --vmid 101 --user deploy --shell /bin/sh
pct_enter() {
    local vmid=""
    local user="root"
    local shell="/bin/bash"
    local dry_run="${IS_DRY_RUN:-false}"

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --vmid)
                vmid="$2"
                shift 2
                ;;
            -u|--user)
                user="$2"
                shift 2
                ;;
            -s|--shell)
                shell="$2"
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            *)
                error "pct_enter: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [ -z "$vmid" ]; then
        error "pct_enter: --vmid is required"
        return 1
    fi

    if [ "$dry_run" = "true" ]; then
        echo "[DRY RUN] pct start $vmid (if not running)"
        if [ "$user" = "root" ]; then
            echo "[DRY RUN] pct enter $vmid"
        else
            printf '[DRY RUN] pct exec %s -- su -l "%s" -s "%s"\n' "$vmid" "$user" "$shell"
        fi
        return 0
    fi

    if [ "$(id -u)" -ne 0 ]; then
        warn "pct_enter: not running as root — PCT operations may fail without elevated privileges"
    fi

    if ! command -v pct >/dev/null 2>&1; then
        error "pct_enter: pct is not available. PCT is part of Proxmox VE and cannot be installed on non-Proxmox systems."
        return 1
    fi

    if ! pct status "$vmid" >/dev/null 2>&1; then
        error "pct_enter: container $vmid does not exist"
        return 2
    fi

    local state
    state=$(pct status "$vmid" 2>/dev/null | awk '{print $2}')
    debug "pct_enter: container $vmid state='$state'"

    if [ "$state" != "running" ]; then
        info "Container $vmid is not running — starting it..."

        local _fifo
        _fifo=$(mktemp -u /tmp/shtuff_XXXXXX)
        mkfifo "$_fifo"
        log_output < "$_fifo" &
        pct start "$vmid" > "$_fifo" 2>&1 &
        local _pid=$!
        rm -f "$_fifo"

        monitor "$_pid" \
            --style "${SPINNER_LOADING_STYLE}" \
            --message "Starting container $vmid" \
            --success_msg "Container $vmid started." \
            --error_msg "Container $vmid failed to start." || return 3
    fi

    if [ "$user" = "root" ]; then
        info "Attaching to container $vmid..."
        pct enter "$vmid"
    else
        info "Attaching to container $vmid as '$user'..."
        pct exec "$vmid" -- su -l "$user" -s "$shell"
    fi
}
