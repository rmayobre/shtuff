#!/usr/bin/env bash

# Function: lxc_push
# Description: Copies a file or directory from the host into an LXC container by writing
#              directly into the container's rootfs. Works whether the container is running
#              or stopped.
#
# Arguments:
#   $1 - source (string, required): Path on the host to copy from.
#   $2 - destination (string, required): Absolute path inside the container to copy to.
#   --name NAME (string, required): Name of the target container.
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --message MSG (string, optional, default: "Pushing to container..."): Progress message.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - File(s) pushed successfully.
#   1 - Invalid or missing arguments, or LXC not installed.
#   2 - Source path does not exist, container does not exist, or rootfs not found.
#   3 - Copy operation failed.
#
# Examples:
#   lxc_push /etc/myapp.conf /etc/myapp.conf --name mycontainer
#   lxc_push /opt/app /opt/app --name webserver --style dots --message "Deploying app"
function lxc_push {
    local source_path=""
    local dest_path=""
    local name=""
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
            *)
                error "lxc_push: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$source_path" ]]; then
        error "lxc_push: source path is required"
        return 1
    fi

    if [[ -z "$dest_path" ]]; then
        error "lxc_push: destination path inside container is required"
        return 1
    fi

    if [[ -z "$name" ]]; then
        error "lxc_push: --name is required"
        return 1
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "lxc_push: not running as root — writing to container rootfs may fail without elevated privileges"
    fi

    if ! command -v lxc-info &>/dev/null; then
        error "lxc_push: LXC is not installed. Run lxc_create first or install lxc manually."
        return 1
    fi

    if [[ ! -e "$source_path" ]]; then
        error "lxc_push: source not found: $source_path"
        return 2
    fi

    if ! lxc-info -n "$name" &>/dev/null; then
        error "lxc_push: container '$name' does not exist"
        return 2
    fi

    local rootfs="/var/lib/lxc/${name}/rootfs"
    if [[ ! -d "$rootfs" ]]; then
        error "lxc_push: rootfs not found for container '$name' (expected: $rootfs)"
        return 2
    fi

    local full_dest="${rootfs}${dest_path}"
    debug "lxc_push: source='$source_path' dest='$full_dest'"

    info "Pushing '$source_path' into container '$name' at '$dest_path'"

    if command -v rsync &>/dev/null; then
        debug "lxc_push: using rsync"
        rsync -a "$source_path" "$full_dest" >/dev/null 2>&1 &
    elif [[ -d "$source_path" ]]; then
        debug "lxc_push: rsync not found, using cp -r"
        cp -r "$source_path" "$full_dest" >/dev/null 2>&1 &
    else
        debug "lxc_push: rsync not found, using cp"
        cp "$source_path" "$full_dest" >/dev/null 2>&1 &
    fi

    monitor $! \
        --style "$style" \
        --message "$message" \
        --success_msg "Push complete." \
        --error_msg "Push failed." || return 3

    debug "lxc_push: completed successfully"
    return 0
}
