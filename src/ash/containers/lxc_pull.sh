#!/bin/sh

# Function: lxc_pull
# Description: Copies a file or directory from inside an LXC container to the host by reading
#              directly from the container's rootfs. Works whether the container is running
#              or stopped.
#
# Arguments:
#   $1 - source (string, required): Absolute path inside the container to copy from.
#   $2 - destination (string, required): Path on the host to copy to.
#   --name NAME (string, required): Name of the source container.
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --message MSG (string, optional, default: "Pulling from container..."): Progress message.
#   --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#   IS_DRY_RUN (read): When "true", enables dry-run mode by default.
#
# Returns:
#   0 - File(s) pulled successfully.
#   1 - Invalid or missing arguments, or LXC not installed.
#   2 - Source path does not exist inside the container, container does not exist,
#       or rootfs not found.
#   3 - Copy operation failed.
#
# Examples:
#   lxc_pull /etc/myapp.conf /tmp/myapp.conf --name mycontainer
#   lxc_pull /var/log/app /tmp/app-logs --name webserver --style dots --message "Fetching logs"
lxc_pull() {
    local source_path=""
    local dest_path=""
    local name=""
    local style="${SPINNER_LOADING_STYLE}"
    local message="Pulling from container..."
    local dry_run="${IS_DRY_RUN:-false}"

    # Capture positional arguments before named flags
    if [ "$#" -ge 1 ]; then
        case "$1" in
            -*) ;;
            *)
                source_path="$1"
                shift
                ;;
        esac
    fi

    if [ "$#" -ge 1 ]; then
        case "$1" in
            -*) ;;
            *)
                dest_path="$1"
                shift
                ;;
        esac
    fi

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -n|--name)
                name="$2"
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
                error "lxc_pull: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [ -z "$source_path" ]; then
        error "lxc_pull: source path inside container is required"
        return 1
    fi

    if [ -z "$dest_path" ]; then
        error "lxc_pull: destination path on host is required"
        return 1
    fi

    if [ -z "$name" ]; then
        error "lxc_pull: --name is required"
        return 1
    fi

    if [ "$dry_run" = "true" ]; then
        local rootfs="/var/lib/lxc/${name}/rootfs"
        local full_source="${rootfs}${source_path}"
        if command -v rsync >/dev/null 2>&1; then
            printf '[DRY RUN] rsync -a "%s" "%s"\n' "$full_source" "$dest_path"
        elif [ -d "$full_source" ]; then
            printf '[DRY RUN] cp -r "%s" "%s"\n' "$full_source" "$dest_path"
        else
            printf '[DRY RUN] cp "%s" "%s"\n' "$full_source" "$dest_path"
        fi
        return 0
    fi

    if [ "$(id -u)" -ne 0 ]; then
        warn "lxc_pull: not running as root — reading from container rootfs may fail without elevated privileges"
    fi

    if ! command -v lxc-info >/dev/null 2>&1; then
        error "lxc_pull: LXC is not installed. Run lxc_create first or install lxc manually."
        return 1
    fi

    if ! lxc-info -n "$name" >/dev/null 2>&1; then
        error "lxc_pull: container '$name' does not exist"
        return 2
    fi

    local rootfs="/var/lib/lxc/${name}/rootfs"
    if [ ! -d "$rootfs" ]; then
        error "lxc_pull: rootfs not found for container '$name' (expected: $rootfs)"
        return 2
    fi

    local full_source="${rootfs}${source_path}"
    if [ ! -e "$full_source" ]; then
        error "lxc_pull: source not found inside container '$name': $source_path"
        return 2
    fi

    debug "lxc_pull: source='$full_source' dest='$dest_path'"

    info "Pulling '$source_path' from container '$name' to '$dest_path'"

    local _logpipe
    _logpipe=$(mktemp -u)
    mkfifo "$_logpipe"
    log_output < "$_logpipe" &
    local _logpid=$!

    if command -v rsync >/dev/null 2>&1; then
        debug "lxc_pull: using rsync"
        rsync -a "$full_source" "$dest_path" > "$_logpipe" 2>&1 &
    elif [ -d "$full_source" ]; then
        debug "lxc_pull: rsync not found, using cp -r"
        cp -r "$full_source" "$dest_path" > "$_logpipe" 2>&1 &
    else
        debug "lxc_pull: rsync not found, using cp"
        cp "$full_source" "$dest_path" > "$_logpipe" 2>&1 &
    fi

    local _bgpid=$!
    monitor $_bgpid \
        --style "$style" \
        --message "$message" \
        --success_msg "Pull complete." \
        --error_msg "Pull failed."
    local _rc=$?
    rm -f "$_logpipe"
    wait "$_logpid" 2>/dev/null
    if [ "$_rc" -ne 0 ]; then
        return 3
    fi

    debug "lxc_pull: completed successfully"
    return 0
}
