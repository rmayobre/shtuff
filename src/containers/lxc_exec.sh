#!/usr/bin/env bash

# Function: lxc_exec
# Description: Runs a command inside a running LXC container without opening an
#              interactive session. The container must already be running.
#
# Arguments:
#   --name NAME (string, required): Name of the container to execute the command in.
#   -- COMMAND... (required): The command and its arguments to run inside the container.
#       Everything after -- is passed verbatim to lxc-attach.
#
# Globals:
#   None
#
# Returns:
#   0 - Command completed successfully.
#   1 - Invalid or missing arguments, or LXC not installed.
#   2 - Container does not exist.
#   N - Exit code returned by the command run inside the container.
#
# Examples:
#   lxc_exec --name mycontainer -- bash -c "apt-get update -qq && apt-get install -y curl"
#   lxc_exec --name webserver -- systemctl restart nginx
function lxc_exec {
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
                error "lxc_exec: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "lxc_exec: --name is required"
        return 1
    fi

    if [[ ${#cmd[@]} -eq 0 ]]; then
        error "lxc_exec: a command is required after --"
        return 1
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "lxc_exec: not running as root — container operations may fail without elevated privileges"
    fi

    if ! command -v lxc-attach &>/dev/null; then
        error "lxc_exec: LXC is not installed. Run lxc_create first or install lxc manually."
        return 1
    fi

    if ! lxc-info -n "$name" &>/dev/null; then
        error "lxc_exec: container '$name' does not exist"
        return 2
    fi

    debug "lxc_exec: name='$name' cmd='${cmd[*]}'"
    lxc-attach -n "$name" -- "${cmd[@]}"
}
