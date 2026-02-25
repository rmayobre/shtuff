#!/usr/bin/env bash

# Function: container
# Description: Unified interface for creating and managing containers. Automatically
#              delegates to PCT (Proxmox Container Toolkit) when pct is found on the
#              system, or falls back to LXC otherwise.
#
# Arguments:
#   $1 - command (string, required): Subcommand to run.
#       Valid values: create, config, start, exec, enter, push, pull, delete.
#   --name NAME (string, required by all subcommands): Container name (LXC) or
#       numeric VMID (PCT). Translated to the appropriate backend identifier automatically.
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
#   container create --name 100 --template "local:vztmpl/debian-13-standard_13.x-1_amd64.tar.zst" \
#       --memory 1024 --cores 2 --disk-size 16 --hostname myapp
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
function container {
    local command="${1:-}"
    shift || true

    case "$command" in
        create) _container_create "$@" ;;
        config) _container_config "$@" ;;
        start)  _container_start  "$@" ;;
        exec)   _container_exec   "$@" ;;
        enter)  _container_enter  "$@" ;;
        push)   _container_push   "$@" ;;
        pull)   _container_pull   "$@" ;;
        delete) _container_delete "$@" ;;
        *)
            error "container: unknown command: '$command'. Valid commands: create, config, start, exec, enter, push, pull, delete"
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
        pct_start --vmid "$name" "${passthrough[@]}"
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
        pct_exec --vmid "$name" -- "${cmd[@]}"
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
        pct_config --vmid "$name" "${passthrough[@]}"
    else
        lxc_config --name "$name" "${passthrough[@]}"
    fi
}

# _container_create
# Extracts --name NAME from args, maps it to --vmid (PCT) or --name (LXC),
# and forwards all remaining flags to the appropriate create function.
_container_create() {
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
        error "container create: --name is required"
        return 1
    fi

    local backend
    backend=$(_container_backend)
    debug "container create: backend='$backend' name='$name'"

    if [[ "$backend" == "pct" ]]; then
        pct_create --vmid "$name" "${passthrough[@]}"
    else
        lxc_create --name "$name" "${passthrough[@]}"
    fi
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
        pct_enter --vmid "$name" "${passthrough[@]}"
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
        pct_push "$source_path" "$dest_path" --vmid "$name" "${passthrough[@]}"
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
        pct_pull "$source_path" "$dest_path" --vmid "$name" "${passthrough[@]}"
    else
        lxc_pull "$source_path" "$dest_path" --name "$name" "${passthrough[@]}"
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
        pct_delete --vmid "$name" "${passthrough[@]}"
    else
        lxc_delete --name "$name" "${passthrough[@]}"
    fi
}
