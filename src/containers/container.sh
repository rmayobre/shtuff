#!/usr/bin/env bash

# Function: container
# Description: Unified interface for creating and managing containers. Automatically
#              delegates to PCT (Proxmox Container Toolkit) when pct is found on the
#              system, or falls back to LXC otherwise.
#
# Arguments:
#   $1 - command (string, required): Subcommand to run.
#       Valid values: create, start, exec, enter, push, pull.
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
#   pct_enter / lxc_enter, pct_push / lxc_push, and pct_pull / lxc_pull for the
#   complete list of accepted flags per backend.
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
function container {
    local command="${1:-}"
    shift || true

    case "$command" in
        create) _container_create "$@" ;;
        start)  _container_start  "$@" ;;
        exec)   _container_exec   "$@" ;;
        enter)  _container_enter  "$@" ;;
        push)   _container_push   "$@" ;;
        pull)   _container_pull   "$@" ;;
        *)
            error "container: unknown command: '$command'. Valid commands: create, start, exec, enter, push, pull"
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
