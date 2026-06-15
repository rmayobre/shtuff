#!/usr/bin/env bash

# Function: container
# Description: Unified interface for creating and managing containers. Automatically
#              delegates to PCT (Proxmox Container Toolkit) when pct is found on the
#              system, or falls back to LXC otherwise.
#
# Arguments:
#   $1 - command (string, required): Subcommand to run.
#       Valid values: create, config, start, exec, enter, push, pull, delete, prompt.
#   --name NAME (string, required by all subcommands): Container name / hostname.
#       For PCT backends, used as the container hostname and the VMID is automatically
#       generated via pct_next_vmid. For LXC backends, used as the container name.
#
#   create subcommand — resource allocation flags (passed through to backend):
#   --hostname HOSTNAME (string, optional): Hostname to assign inside the container.
#   --memory MB (integer, optional): Memory limit in megabytes.
#   --cores N (integer, optional): Number of CPU cores to allocate.
#   --storage STORAGE (string, optional): Storage type. For LXC: backing store type
#       (dir, btrfs, zfs, overlayfs, best; default: dir). For PCT: Proxmox storage
#       pool name (e.g. local-lvm; default: local-lvm).
#   --disk-size GB (integer, optional): Rootfs size in gigabytes. For LXC, only
#       effective when --storage is btrfs or zfs.
#   --password PASSWORD (string, optional): Root password for the container.
#   --gpu PCI_ADDR (string, optional): PCI address of the GPU to pass through to the
#       container (e.g. 01:00.0). Applied after the container is created via
#       _gpu_apply_passthrough. Use gpu_list to discover available addresses.
#   --pcie (flag, optional): Enable PCIe passthrough mode (pcie=1) when configuring
#       GPU passthrough on PCT backends. Has no effect on LXC backends.
#   --prompt (flag, optional): Interactively prompt for any of the above values that
#       are left null, empty, or unset (skipped if --dry-run is set). Any values
#       already provided on the command line are used as the prompt defaults and are
#       not re-prompted. After confirmation, also offers to configure the container's
#       network interface via 'container network prompt'.
#
#   exec subcommand — run a command inside the container without an interactive session:
#   -- COMMAND... (required): Everything after -- is the command to run inside the container.
#
#   All other subcommand-specific flags are also forwarded unchanged. See
#   pct_create / lxc_create, pct_start / lxc_start, pct_exec / lxc_exec,
#   pct_enter / lxc_enter, pct_push / lxc_push, pct_pull / lxc_pull, and
#   pct_delete / lxc_delete for the complete list of accepted flags per backend.
#
#   config subcommand — update resource settings on an existing container:
#   --hostname HOSTNAME (string, optional): New hostname.
#   --memory MB (integer, optional): New memory limit in megabytes.
#   --cores N (integer, optional): New CPU core count.
#   --set KEY=VALUE (string, optional, repeatable, LXC only): Set an arbitrary
#       lxc.* config key. May be specified multiple times.
#   Any additional flags accepted by 'pct set' are forwarded on PCT hosts.
#
#   delete subcommand:
#   --force (flag, optional): Stop the container before destroying if it is running.
#   --purge (flag, optional, PCT only): Remove from related configurations and jobs.
#
#   network subcommand — manage a container's network interface. Accepts an
#   optional subcommand keyword as the first argument after 'network':
#       (no keyword) — configure the interface (default behaviour).
#       show          — display the current network configuration.
#       prompt        — interactive form to configure the interface.
#
#   prompt subcommand — alias for 'create --prompt'; interactively prompts for any
#   create options not supplied as arguments.
#
#   Configure / show flags:
#   --bridge BRIDGE (string, optional): Host bridge interface to attach to.
#       Default: lxcbr0 (LXC) or vmbr0 (PCT).
#   --ip IP/PREFIX (string, optional): Static IP with prefix (e.g. 10.0.0.10/24).
#       Omit to leave address unconfigured (use a DHCP client inside the container).
#       Use 'dhcp' on PCT to request dynamic assignment via pct.
#   --gateway GW (string, optional): Default gateway IP.
#   --dns NAMESERVERS (string, optional, PCT only): Space-separated DNS nameserver
#       IPs (e.g. "8.8.8.8 8.8.4.4").
#   --index N (integer, optional, default: 0): Network interface index.
#   --type TYPE (string, optional, LXC only): Interface type.
#       Valid values: veth, macvlan, ipvlan, none. Default: veth.
#   --hwaddr MAC (string, optional, LXC only): Hardware (MAC) address to assign.
#
# Globals:
#   None
#
# Returns:
#   0 - Command completed successfully.
#   1 - Unknown subcommand or missing required --name argument.
#   N - Exit code propagated from the delegated backend function.
#
# Examples:
#   container create --name mycontainer --dist debian --release trixie
#   container create --name mycontainer --memory 1024 --cores 2 --hostname myapp
#   container create --name myapp --template "local:vztmpl/debian-13-standard_13.x-1_amd64.tar.zst" \
#       --memory 1024 --cores 2 --disk-size 16
#   container create --name mycontainer --dist debian --release trixie --gpu 01:00.0
#   container create --name mycontainer --template "local:vztmpl/debian-13-standard_13.x-1_amd64.tar.zst" \
#       --gpu 01:00.0 --pcie
#   container start --name mycontainer
#   container exec --name mycontainer -- bash -c "apt-get update && apt-get install -y curl"
#   container enter --name mycontainer
#   container enter --name 100 --user deploy
#   container push /etc/app.conf /etc/app.conf --name mycontainer
#   container pull /var/log/app.log /tmp/app.log --name 100
#   container config --name mycontainer --memory 2048 --cores 4
#   container config --name mycontainer --hostname newname
#   container config --name mycontainer --set lxc.net.0.type=veth
#   container delete --name mycontainer
#   container delete --name 100 --force --purge
#   container network --name mycontainer --bridge lxcbr0 --ip 10.0.0.10/24 --gateway 10.0.0.1
#   container network --name 100 --ip 192.168.1.100/24 --gateway 192.168.1.1
#   container network --name 100 --ip dhcp --dns "8.8.8.8 8.8.4.4"
#   container network show --name mycontainer
#   container network show --name 100 --index 1
#   container network prompt --name mycontainer
#   container network prompt --name mycontainer --index 1
#   container shell-script --name mycontainer --content '#!/bin/bash\necho hello' --path /usr/local/bin/hello.sh
#   container shell-script --name 100 --content "$(cat setup.sh)" --path /opt/setup.sh
#   container shell-script --name mycontainer --path /opt/setup.sh --env PORT="$PORT" --env DIR="$INSTALL_DIR"
#   container create --prompt
#   container create --name myapp --memory 1024 --prompt
#   container prompt
function container {
    local command="${1:-}"
    shift || true

    case "$command" in
        create)  _container_create  "$@" ;;
        config)  _container_config  "$@" ;;
        start)   _container_start   "$@" ;;
        exec)    _container_exec    "$@" ;;
        enter)   _container_enter   "$@" ;;
        push)    _container_push    "$@" ;;
        pull)    _container_pull    "$@" ;;
        delete)  _container_delete  "$@" ;;
        network)       _container_network       "$@" ;;
        shell-script)  _container_shell_script  "$@" ;;
        prompt)        _container_create --prompt "$@" ;;
        *)
            error "container: unknown command: '$command'. Valid commands: create, config, start, exec, enter, push, pull, delete, network, shell-script, prompt"
            return 1
            ;;
    esac
}

# _container_backend
# Prints "pct" if the pct binary is present on the system, "lxc" otherwise.
_container_backend() {
    if command -v pct &>/dev/null; then
        echo "pct"
    else
        echo "lxc"
    fi
}

# _container_start
# Extracts --name NAME from args, maps it to --vmid (PCT) or --name (LXC),
# and forwards all remaining flags to the appropriate start function.
_container_start() {
    local name=""
    local passthrough=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            *)
                passthrough+=("$1")
                shift
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "container start: --name is required"
        return 1
    fi

    local backend
    backend=$(_container_backend)
    debug "container start: backend='$backend' name='$name'"

    if [[ "$backend" == "pct" ]]; then
        local vmid
        vmid=$(pct_find_vmid --name "$name") || return $?
        pct_start --vmid "$vmid" "${passthrough[@]}"
    else
        lxc_start --name "$name" "${passthrough[@]}"
    fi
}

# _container_exec
# Extracts --name NAME from args, maps it to --vmid (PCT) or --name (LXC),
# and forwards the command (everything after --) to the appropriate exec function.
_container_exec() {
    local name=""
    local cmd=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            --)
                shift
                cmd=("$@")
                break
                ;;
            *)
                error "container exec: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "container exec: --name is required"
        return 1
    fi

    if [[ ${#cmd[@]} -eq 0 ]]; then
        error "container exec: a command is required after --"
        return 1
    fi

    local backend
    backend=$(_container_backend)
    debug "container exec: backend='$backend' name='$name'"

    if [[ "$backend" == "pct" ]]; then
        local vmid
        vmid=$(pct_find_vmid --name "$name") || return $?
        pct_exec --vmid "$vmid" -- "${cmd[@]}"
    else
        lxc_exec --name "$name" -- "${cmd[@]}"
    fi
}

# _container_config
# Extracts --name NAME from args, maps it to --vmid (PCT) or --name (LXC),
# and forwards all remaining flags to the appropriate config function.
_container_config() {
    local name=""
    local passthrough=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            *)
                passthrough+=("$1")
                shift
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "container config: --name is required"
        return 1
    fi

    local backend
    backend=$(_container_backend)
    debug "container config: backend='$backend' name='$name'"

    if [[ "$backend" == "pct" ]]; then
        local vmid
        vmid=$(pct_find_vmid --name "$name") || return $?
        pct_config --vmid "$vmid" "${passthrough[@]}"
    else
        lxc_config --name "$name" "${passthrough[@]}"
    fi
}

# _container_create_prompt
# Interactively prompts for any container creation option left null, empty, or unset,
# using the caller's existing local variables as defaults (and skipping the prompt
# entirely when a value is already present). Relies on bash's dynamic scoping: the
# caller (_container_create) must declare 'name', 'template', 'dist', 'release', 'arch',
# 'hostname', 'memory', 'cores', 'storage', 'disk_size', 'password', 'gpu_addr',
# 'pcie_mode', and 'backend' as local variables before calling this function — those
# variables are assigned directly.
#
# Returns:
#   0 - User confirmed; caller should proceed with creation.
#   1 - GPU selection failed.
#   2 - User cancelled at the confirmation prompt.
_container_create_prompt() {
    if [[ -z "$name" ]]; then
        question "Container name:"
        name="$answer"
    fi

    if [[ -n "$template" ]]; then
        info "Using --template='$template'"
    elif [[ "$backend" == "pct" ]]; then
        question "Template path (leave blank to auto-resolve via distribution/release):"
        template="$answer"
    else
        question "Template name (leave blank for 'download'):"
        template="${answer:-download}"
    fi

    local needs_dist_release="false"
    if [[ "$backend" == "pct" ]]; then
        [[ -z "$template" ]] && needs_dist_release="true"
    elif [[ "$template" == "download" ]]; then
        needs_dist_release="true"
    fi

    if [[ "$needs_dist_release" == "true" ]]; then
        if [[ -n "$dist" ]]; then
            info "Using --dist='$dist'"
        fi
        if [[ -n "$release" ]]; then
            info "Using --release='$release'"
        fi
        if [[ -z "$dist" || -z "$release" ]]; then
            _container_dist_release_prompt
        fi

        if [[ -n "$arch" ]]; then
            info "Using --arch='$arch'"
        elif [[ "$backend" == "lxc" ]]; then
            options "Architecture:" \
                --choice "amd64" \
                --choice "arm64" \
                --choice "armhf" \
                --choice "i386"
            arch="$answer"
        fi
    fi

    if [[ -n "$hostname" ]]; then
        info "Using --hostname='$hostname'"
    else
        question "Hostname inside container (leave blank to use container name):"
        hostname="$answer"
    fi

    if [[ -n "$memory" ]]; then
        info "Using --memory='${memory}MB'"
    else
        local mem_prompt="Memory limit in MB"
        [[ "$backend" == "pct" ]] && mem_prompt+=" (leave blank for 512MB)"
        mem_prompt+=":"
        question "$mem_prompt"
        memory="$answer"
    fi

    if [[ -n "$cores" ]]; then
        info "Using --cores='$cores'"
    else
        local cores_prompt="Number of CPU cores"
        [[ "$backend" == "pct" ]] && cores_prompt+=" (leave blank for 1)"
        cores_prompt+=":"
        question "$cores_prompt"
        cores="$answer"
    fi

    if [[ -n "$storage" ]]; then
        info "Using --storage='$storage'"
    elif [[ "$backend" == "pct" ]]; then
        question "Storage pool (leave blank for 'local-lvm'):"
        storage="$answer"
    else
        options "Storage backing store:" \
            --choice "dir" \
            --choice "btrfs" \
            --choice "zfs" \
            --choice "overlayfs" \
            --choice "best"
        storage="$answer"
    fi

    if [[ -n "$disk_size" ]]; then
        info "Using --disk-size='${disk_size}GB'"
    else
        local disk_prompt="Root disk size in GB"
        [[ "$backend" == "pct" ]] && disk_prompt+=" (leave blank for 8GB)"
        disk_prompt+=":"
        question "$disk_prompt"
        disk_size="$answer"
    fi

    if [[ -n "$password" ]]; then
        info "Using --password from arguments"
    else
        question "Root password (leave blank to skip):"
        password="$answer"
    fi

    if [[ -n "$gpu_addr" ]]; then
        info "Using --gpu='$gpu_addr'"
    elif confirm "Enable GPU passthrough for this container?"; then
        gpu_select || return 1
        gpu_addr="${answer%% *}"
    fi

    info "Container configuration summary:"
    info "  Backend:  $backend"
    info "  Name:     $name"
    info "  Template: $template"
    [[ "$needs_dist_release" == "true" ]] && info "  Dist / Release / Arch: ${dist} / ${release} / ${arch}"
    [[ -n "$hostname"  ]] && info "  Hostname: $hostname"
    [[ -n "$memory"    ]] && info "  Memory:   ${memory}MB"
    [[ -n "$cores"     ]] && info "  Cores:    $cores"
    [[ -n "$storage"   ]] && info "  Storage:  $storage"
    [[ -n "$disk_size" ]] && info "  Disk:     ${disk_size}GB"
    [[ -n "$password"  ]] && info "  Password: (set)"
    if [[ -n "$gpu_addr" ]]; then
        local gpu_summary="  GPU:      $gpu_addr"
        [[ "$pcie_mode" == "true" ]] && gpu_summary+=" (PCIe)"
        info "$gpu_summary"
    fi

    if ! confirm "Create this container?"; then
        info "container create: cancelled."
        return 2
    fi

    return 0
}

# _container_create
# Extracts --name NAME, --gpu PCI_ADDR, --pcie, and --prompt from args. All other flags
# are forwarded unchanged to the appropriate backend. Both pct_create and lxc_create
# accept --dist, --release, and --arch for download-template selection; pct_create
# resolves them via pveam while lxc_create uses the lxc-create download template. When
# --gpu is provided, GPU passthrough is applied after the container is created using
# _gpu_apply_passthrough.
#
# When --prompt is given, any argument left null, empty, or unset is interactively
# prompted for via _container_create_prompt (skipped entirely if --dry-run is set),
# using any value already supplied as the default. After confirmation the container is
# created, and the user is asked whether to configure its network interface via
# _container_network_prompt. Without --prompt, missing required arguments simply
# cause the backend create function to error out.
#
# Each option below can also be shortcut via the corresponding CONTAINER_* environment
# variable: if the command-line flag is not given, the environment variable (when set)
# is used in its place and its prompt (under --prompt) is skipped.
#
# Globals:
#   CONTAINER_NAME (read): Shortcut for --name.
#   CONTAINER_TEMPLATE (read): Shortcut for --template.
#   CONTAINER_DIST (read): Shortcut for --dist.
#   CONTAINER_RELEASE (read): Shortcut for --release.
#   CONTAINER_ARCH (read): Shortcut for --arch.
#   CONTAINER_HOSTNAME (read): Shortcut for --hostname.
#   CONTAINER_MEMORY (read): Shortcut for --memory.
#   CONTAINER_CORES (read): Shortcut for --cores.
#   CONTAINER_STORAGE (read): Shortcut for --storage.
#   CONTAINER_DISK_SIZE (read): Shortcut for --disk-size.
#   CONTAINER_PASSWORD (read): Shortcut for --password.
#   CONTAINER_GPU (read): Shortcut for --gpu.
#   CONTAINER_GPU_PCIE (read): Set to "true" to shortcut --pcie.
_container_create() {
    local name=""
    local gpu_addr=""
    local pcie_mode="false"
    local template="" dist="" release="" arch=""
    local hostname="" memory="" cores="" storage="" disk_size="" password=""
    local dry_run="${IS_DRY_RUN:-false}"
    local prompt_mode="false"
    local passthrough=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            --gpu)
                gpu_addr="$2"
                shift 2
                ;;
            --pcie)
                pcie_mode="true"
                shift
                ;;
            --prompt)
                prompt_mode="true"
                shift
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
            --dry-run)
                dry_run="true"
                shift
                ;;
            *)
                passthrough+=("$1")
                shift
                ;;
        esac
    done

    # CONTAINER_* environment variables shortcut any prompts for unset values.
    name="${name:-${CONTAINER_NAME:-}}"
    gpu_addr="${gpu_addr:-${CONTAINER_GPU:-}}"
    [[ "$pcie_mode" == "false" && "${CONTAINER_GPU_PCIE:-false}" == "true" ]] && pcie_mode="true"
    template="${template:-${CONTAINER_TEMPLATE:-}}"
    dist="${dist:-${CONTAINER_DIST:-}}"
    release="${release:-${CONTAINER_RELEASE:-}}"
    arch="${arch:-${CONTAINER_ARCH:-}}"
    hostname="${hostname:-${CONTAINER_HOSTNAME:-}}"
    memory="${memory:-${CONTAINER_MEMORY:-}}"
    cores="${cores:-${CONTAINER_CORES:-}}"
    storage="${storage:-${CONTAINER_STORAGE:-}}"
    disk_size="${disk_size:-${CONTAINER_DISK_SIZE:-}}"
    password="${password:-${CONTAINER_PASSWORD:-}}"

    local backend
    backend=$(_container_backend)

    if [[ "$prompt_mode" == "true" && "$dry_run" != "true" ]]; then
        _container_create_prompt
        case $? in
            2) return 0 ;;
            1) return 1 ;;
        esac
    fi

    if [[ -z "$name" ]]; then
        error "container create: --name is required"
        return 1
    fi

    debug "container create: backend='$backend' name='$name' prompt='$prompt_mode'"

    [[ -n "$template"  ]] && passthrough+=(--template "$template")
    [[ -n "$dist"      ]] && passthrough+=(--dist "$dist")
    [[ -n "$release"   ]] && passthrough+=(--release "$release")
    [[ -n "$arch"      ]] && passthrough+=(--arch "$arch")
    [[ -n "$hostname"  ]] && passthrough+=(--hostname "$hostname")
    [[ -n "$memory"    ]] && passthrough+=(--memory "$memory")
    [[ -n "$cores"     ]] && passthrough+=(--cores "$cores")
    [[ -n "$storage"   ]] && passthrough+=(--storage "$storage")
    [[ -n "$disk_size" ]] && passthrough+=(--disk-size "$disk_size")
    [[ -n "$password"  ]] && passthrough+=(--password "$password")
    [[ "$dry_run" == "true" ]] && passthrough+=(--dry-run)

    local container_id
    if [[ "$backend" == "pct" ]]; then
        local vmid
        local vmid_start=100
        local attempt=0
        local max_attempts=3
        while (( attempt < max_attempts )); do
            vmid=$(pct_next_vmid --start "$vmid_start") || return 1
            debug "container create: attempt $((attempt + 1)) using vmid='$vmid' hostname='$name'"
            if pct_create --vmid "$vmid" --hostname "$name" "${passthrough[@]}"; then
                break
            fi
            (( attempt++ ))
            if (( attempt >= max_attempts )); then
                error "container create: failed to create container after $max_attempts attempts"
                return 1
            fi
            warn "container create: vmid=$vmid creation failed, trying next available vmid"
            vmid_start=$(( vmid + 1 ))
        done
        container_id="$vmid"
    else
        lxc_create --name "$name" "${passthrough[@]}" || return 1
        container_id="$name"
    fi

    if [[ -n "$gpu_addr" ]]; then
        debug "container create: applying GPU passthrough pci='$gpu_addr' pcie='$pcie_mode'"
        _gpu_apply_passthrough \
            --container "$container_id" \
            --pci-addr  "$gpu_addr"    \
            --pcie      "$pcie_mode"   || return 1
    fi

    if [[ "$prompt_mode" == "true" && "$dry_run" != "true" ]]; then
        if confirm "Configure network interface for '$name'?"; then
            _container_network_prompt --name "$name"
            return $?
        fi
    fi

    return 0
}

# _container_enter
# Extracts --name NAME from args, maps it to --vmid (PCT) or --name (LXC),
# and forwards all remaining flags to the appropriate enter function.
_container_enter() {
    local name=""
    local passthrough=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            *)
                passthrough+=("$1")
                shift
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "container enter: --name is required"
        return 1
    fi

    local backend
    backend=$(_container_backend)
    debug "container enter: backend='$backend' name='$name'"

    if [[ "$backend" == "pct" ]]; then
        local vmid
        vmid=$(pct_find_vmid --name "$name") || return $?
        pct_enter --vmid "$vmid" "${passthrough[@]}"
    else
        lxc_enter --name "$name" "${passthrough[@]}"
    fi
}

# _container_push
# Extracts the two positional paths and --name NAME from args, maps --name to the
# appropriate backend identifier, and forwards remaining flags to the push function.
_container_push() {
    local source_path=""
    local dest_path=""
    local name=""
    local passthrough=()

    # Capture leading positional args before any flags
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
            *)
                passthrough+=("$1")
                shift
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "container push: --name is required"
        return 1
    fi

    local backend
    backend=$(_container_backend)
    debug "container push: backend='$backend' name='$name'"

    if [[ "$backend" == "pct" ]]; then
        local vmid
        vmid=$(pct_find_vmid --name "$name") || return $?
        pct_push "$source_path" "$dest_path" --vmid "$vmid" "${passthrough[@]}"
    else
        lxc_push "$source_path" "$dest_path" --name "$name" "${passthrough[@]}"
    fi
}

# _container_pull
# Extracts the two positional paths and --name NAME from args, maps --name to the
# appropriate backend identifier, and forwards remaining flags to the pull function.
_container_pull() {
    local source_path=""
    local dest_path=""
    local name=""
    local passthrough=()

    # Capture leading positional args before any flags
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
            *)
                passthrough+=("$1")
                shift
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "container pull: --name is required"
        return 1
    fi

    local backend
    backend=$(_container_backend)
    debug "container pull: backend='$backend' name='$name'"

    if [[ "$backend" == "pct" ]]; then
        local vmid
        vmid=$(pct_find_vmid --name "$name") || return $?
        pct_pull "$source_path" "$dest_path" --vmid "$vmid" "${passthrough[@]}"
    else
        lxc_pull "$source_path" "$dest_path" --name "$name" "${passthrough[@]}"
    fi
}

# _container_network
# Dispatches 'container network' subcommands: show, prompt, or configure (default).
# Extracts --name NAME and an optional leading subcommand keyword, then delegates
# to pct_network_show / lxc_network_show, _container_network_prompt, or
# pct_network / lxc_network as appropriate.
_container_network() {
    local subcommand=""
    case "${1:-}" in
        show|prompt) subcommand="$1"; shift ;;
    esac

    local name=""
    local passthrough=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            *)
                passthrough+=("$1")
                shift
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "container network: --name is required"
        return 1
    fi

    local backend
    backend=$(_container_backend)
    debug "container network: backend='$backend' name='$name' subcommand='${subcommand:-configure}'"

    if [[ "$subcommand" == "show" ]]; then
        if [[ "$backend" == "pct" ]]; then
            local vmid
            vmid=$(pct_find_vmid --name "$name") || return $?
            pct_network_show --vmid "$vmid" "${passthrough[@]}"
        else
            lxc_network_show --name "$name" "${passthrough[@]}"
        fi
    elif [[ "$subcommand" == "prompt" ]]; then
        _container_network_prompt --name "$name" "${passthrough[@]}"
    else
        if [[ "$backend" == "pct" ]]; then
            local vmid
            vmid=$(pct_find_vmid --name "$name") || return $?
            pct_network --vmid "$vmid" "${passthrough[@]}"
        else
            lxc_network --name "$name" "${passthrough[@]}"
        fi
    fi
}

# _container_shell_script
# Extracts --name NAME from args, maps it to --vmid (PCT) or --name (LXC),
# and forwards all remaining flags to the appropriate shell-script function.
_container_shell_script() {
    local name=""
    local passthrough=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            *)
                passthrough+=("$1")
                shift
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "container shell-script: --name is required"
        return 1
    fi

    local backend
    backend=$(_container_backend)
    debug "container shell-script: backend='$backend' name='$name'"

    if [[ "$backend" == "pct" ]]; then
        local vmid
        vmid=$(pct_find_vmid --name "$name") || return $?
        pct_shell_script --vmid "$vmid" "${passthrough[@]}"
    else
        lxc_shell_script --name "$name" "${passthrough[@]}"
    fi
}

# _container_delete
# Extracts --name NAME from args, maps it to --vmid (PCT) or --name (LXC),
# and forwards all remaining flags to the appropriate delete function.
_container_delete() {
    local name=""
    local passthrough=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            *)
                passthrough+=("$1")
                shift
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "container delete: --name is required"
        return 1
    fi

    local backend
    backend=$(_container_backend)
    debug "container delete: backend='$backend' name='$name'"

    if [[ "$backend" == "pct" ]]; then
        local vmid
        vmid=$(pct_find_vmid --name "$name") || return $?
        pct_delete --vmid "$vmid" "${passthrough[@]}"
    else
        lxc_delete --name "$name" "${passthrough[@]}"
    fi
}
