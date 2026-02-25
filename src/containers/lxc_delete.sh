#!/usr/bin/env bash

# Function: lxc_delete
# Description: Destroys an LXC container, permanently removing it and all its data.
#              The container must be stopped first unless --force is specified.
#
# Arguments:
#   --name NAME (string, required): Name of the container to destroy.
#   --force (flag, optional): Stop the container before destroying if it is running.
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - Container destroyed successfully.
#   1 - Invalid or missing arguments, or LXC not installed.
#   2 - Container does not exist.
#   3 - Container destruction failed.
#
# Examples:
#   lxc_delete --name mycontainer
#   lxc_delete --name mycontainer --force
function lxc_delete {
    local name=""
    local force=0
    local style="${SPINNER_LOADING_STYLE}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            -f|--force)
                force=1
                shift
                ;;
            -s|--style)
                style="$2"
                shift 2
                ;;
            *)
                error "lxc_delete: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "lxc_delete: --name is required"
        return 1
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "lxc_delete: not running as root — container operations may fail without elevated privileges"
    fi

    if ! command -v lxc-destroy &>/dev/null; then
        error "lxc_delete: LXC is not installed. Run lxc_create first or install lxc manually."
        return 1
    fi

    if ! lxc-info -n "$name" &>/dev/null; then
        error "lxc_delete: container '$name' does not exist"
        return 2
    fi

    local destroy_args=(-n "$name")
    if [[ "$force" -eq 1 ]]; then
        destroy_args+=(-f)
    fi

    debug "lxc_delete: destroying container '$name' (force=$force)"
    lxc-destroy "${destroy_args[@]}" &
    monitor $! \
        --style "$style" \
        --message "Destroying container '$name'" \
        --success_msg "Container '$name' destroyed." \
        --error_msg "Container '$name' destruction failed." || return 3

    debug "lxc_delete: container '$name' destroyed successfully"
    return 0
}
