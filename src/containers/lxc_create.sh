#!/usr/bin/env bash

# Function: lxc_create
# Description: Creates a new LXC container, installing LXC tooling first if not present.
#              Resource constraints (memory, CPU) are written to the container config
#              using cgroup v2 keys after creation.
#
# Arguments:
#   --name NAME (string, required): Name for the new container.
#   --template TEMPLATE (string, optional, default: "download"): LXC template to use.
#   --dist DIST (string, optional, default: "debian"): Distribution name (used with "download" template).
#   --release RELEASE (string, optional, default: "trixie"): Distribution release (used with "download" template).
#   --arch ARCH (string, optional, default: "amd64"): Architecture (used with "download" template).
#   --hostname HOSTNAME (string, optional): Hostname to assign inside the container.
#   --memory MB (integer, optional): Memory limit in megabytes.
#   --cores N (integer, optional): Number of CPU cores to allocate.
#   --storage STORAGE (string, optional, default: "dir"): Backing store type for the
#       container rootfs. Valid values: dir, btrfs, zfs, overlayfs, best.
#       Note: --disk-size only takes effect with btrfs or zfs.
#   --disk-size GB (integer, optional): Rootfs size in gigabytes. Requires --storage
#       to be set to btrfs or zfs; silently ignored for other backing stores.
#   --password PASSWORD (string, optional): Root password to set inside the container.
#       The container is started briefly to apply the password, then stopped.
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - Container created successfully.
#   1 - Invalid or missing arguments.
#   2 - LXC installation failed.
#   3 - Container creation or post-creation configuration failed.
#
# Examples:
#   lxc_create --name mycontainer
#   lxc_create --name webserver --dist debian --release trixie --arch amd64
#   lxc_create --name myapp --dist debian --release trixie \
#       --hostname myapp --memory 1024 --cores 2 \
#       --storage btrfs --disk-size 16 --password secret
function lxc_create {
    local name=""
    local template="download"
    local dist="debian"
    local release="trixie"
    local arch="amd64"
    local hostname=""
    local memory=""
    local cores=""
    local storage="dir"
    local disk_size=""
    local password=""
    local style="${SPINNER_LOADING_STYLE}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            -t|--template)
                template="$2"
                shift 2
                ;;
            -d|--dist)
                dist="$2"
                shift 2
                ;;
            -r|--release)
                release="$2"
                shift 2
                ;;
            -a|--arch)
                arch="$2"
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
            *)
                error "lxc_create: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "lxc_create: --name is required"
        return 1
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "lxc_create: not running as root — container creation may fail without elevated privileges"
    fi

    # Ensure LXC is installed
    if ! command -v lxc-create &>/dev/null; then
        info "LXC not found — installing..."
        install lxc lxc-utils &
        monitor $! \
            --style "$style" \
            --message "Installing LXC" \
            --success_msg "LXC installed." \
            --error_msg "LXC installation failed." || return 2
    fi

    debug "lxc_create: name='$name' template='$template' dist='$dist' release='$release' arch='$arch' storage='$storage'"

    # Build lxc-create arguments
    local lxc_args=(-n "$name" -B "$storage")

    if [[ -n "$disk_size" ]]; then
        if [[ "$storage" == "btrfs" || "$storage" == "zfs" ]]; then
            lxc_args+=(--bsize "${disk_size}G")
            debug "lxc_create: disk-size='${disk_size}G'"
        else
            warn "lxc_create: --disk-size requires btrfs or zfs storage; ignored for storage='$storage'"
        fi
    fi

    if [[ "$template" == "download" ]]; then
        info "Creating LXC container '$name' ($dist/$release/$arch)"
        lxc-create "${lxc_args[@]}" -t download -- \
            --dist "$dist" \
            --release "$release" \
            --arch "$arch" \
            > >(log_output) 2>&1 &
    else
        info "Creating LXC container '$name' using template '$template'"
        lxc-create "${lxc_args[@]}" -t "$template" > >(log_output) 2>&1 &
    fi

    monitor $! \
        --style "$style" \
        --message "Creating container '$name'" \
        --success_msg "Container '$name' created." \
        --error_msg "Container '$name' creation failed." || return 3

    # Apply resource constraints to the container config file
    local config_file="/var/lib/lxc/${name}/config"

    if [[ -n "$hostname" ]]; then
        debug "lxc_create: setting hostname='$hostname'"
        printf "\nlxc.uts.name = %s\n" "$hostname" >> "$config_file"
    fi

    if [[ -n "$memory" ]]; then
        debug "lxc_create: setting memory limit='${memory}M'"
        printf "lxc.cgroup2.memory.max = %sM\n" "$memory" >> "$config_file"
    fi

    if [[ -n "$cores" ]]; then
        debug "lxc_create: setting cpu cores='$cores'"
        printf "lxc.cgroup2.cpuset.cpus = 0-%s\n" "$((cores - 1))" >> "$config_file"
    fi

    # Set root password by starting the container briefly
    if [[ -n "$password" ]]; then
        { lxc-start -n "$name" &&
          lxc-attach -n "$name" -- bash -c "echo 'root:${password}' | chpasswd" &&
          lxc-stop -n "$name"; } > >(log_output) 2>&1 &
        monitor $! \
            --style "$style" \
            --message "Setting root password" \
            --success_msg "Root password set." \
            --error_msg "Failed to set root password." || return 3
    fi

    debug "lxc_create: container '$name' created successfully"
    return 0
}
