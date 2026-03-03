#!/usr/bin/env bash

# Function: bridge
# Description: Manages Linux bridge interfaces on the host using iproute2.
#              Supports creating, deleting, and adding or removing physical
#              interfaces from a bridge. Changes take effect immediately but
#              are not persistent across reboots — use your distribution's
#              network configuration tool (netplan, systemd-networkd, etc.)
#              to make them permanent.
#
# Arguments:
#   $1 - command (string, required): Subcommand to run.
#       Valid values: create, delete, add-interface, remove-interface.
#
#   create subcommand:
#   --name NAME (string, required): Name of the bridge interface to create.
#   --ip IP/PREFIX (string, optional): IP address and prefix length to assign
#       (e.g. 10.0.0.1/24). Omit to create a bridge with no IP.
#
#   delete subcommand:
#   --name NAME (string, required): Name of the bridge interface to remove.
#
#   add-interface subcommand:
#   --name NAME (string, required): Name of the bridge to add the interface to.
#   --interface IFACE (string, required): Network interface to attach to the bridge.
#
#   remove-interface subcommand:
#   --name NAME (string, required): Name of the bridge to remove the interface from.
#   --interface IFACE (string, required): Network interface to detach from the bridge.
#
#   --dry-run (flag, optional): Print the system calls that would be executed without
#       running them. Defaults to IS_DRY_RUN if not specified.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#   IS_DRY_RUN (read): When "true", enables dry-run mode by default.
#
# Returns:
#   0 - Command completed successfully.
#   1 - Invalid arguments, unknown subcommand, or 'ip' tool not available.
#   2 - Bridge or interface already exists / does not exist.
#   3 - Operation failed.
#
# Examples:
#   bridge create --name lxcbr0 --ip 10.0.0.1/24
#   bridge create --name lxcbr0
#   bridge add-interface --name lxcbr0 --interface eth0
#   bridge remove-interface --name lxcbr0 --interface eth0
#   bridge delete --name lxcbr0
function bridge {
    local command="${1:-}"
    shift || true

    # Pre-parse --dry-run from the remaining args before dispatching.
    local dry_run="${IS_DRY_RUN:-false}"
    local -a sub_args=()
    for arg in "$@"; do
        if [[ "$arg" == "--dry-run" ]]; then
            dry_run="true"
        else
            sub_args+=("$arg")
        fi
    done

    if ! command -v ip &>/dev/null; then
        error "bridge: 'ip' command not found. Install iproute2 to manage bridge interfaces."
        return 1
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "bridge: not running as root — bridge operations may fail without elevated privileges"
    fi

    case "$command" in
        create)           _bridge_create          "$dry_run" "${sub_args[@]}" ;;
        delete)           _bridge_delete          "$dry_run" "${sub_args[@]}" ;;
        add-interface)    _bridge_add_interface   "$dry_run" "${sub_args[@]}" ;;
        remove-interface) _bridge_remove_interface "$dry_run" "${sub_args[@]}" ;;
        *)
            error "bridge: unknown command: '$command'. Valid commands: create, delete, add-interface, remove-interface"
            return 1
            ;;
    esac
}

# _bridge_create
# Creates a new bridge interface, optionally assigns an IP, and brings it up.
_bridge_create() {
    local dry_run="$1"; shift
    local name="" ip=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            -i|--ip)
                ip="$2"
                shift 2
                ;;
            *)
                error "bridge create: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "bridge create: --name is required"
        return 1
    fi

    if [[ "$dry_run" == "true" ]]; then
        echo "ip link add $name type bridge"
        [[ -n "$ip" ]] && echo "ip addr add $ip dev $name"
        echo "ip link set $name up"
        return 0
    fi

    if ip link show "$name" &>/dev/null; then
        error "bridge create: interface '$name' already exists"
        return 2
    fi

    debug "bridge create: ip link add $name type bridge"
    if ! ip link add "$name" type bridge 2>/dev/null; then
        error "bridge create: failed to create bridge '$name'"
        return 3
    fi

    if [[ -n "$ip" ]]; then
        debug "bridge create: ip addr add $ip dev $name"
        if ! ip addr add "$ip" dev "$name" 2>/dev/null; then
            error "bridge create: failed to assign $ip to '$name'"
            ip link delete "$name" 2>/dev/null
            return 3
        fi
    fi

    debug "bridge create: ip link set $name up"
    if ! ip link set "$name" up 2>/dev/null; then
        error "bridge create: failed to bring up bridge '$name'"
        return 3
    fi

    info "Bridge '$name' created and up."
    warn "bridge create: '$name' will not persist after reboot. Configure your network manager to make it permanent."
    return 0
}

# _bridge_delete
# Brings down and removes an existing bridge interface.
_bridge_delete() {
    local dry_run="$1"; shift
    local name=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            *)
                error "bridge delete: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "bridge delete: --name is required"
        return 1
    fi

    if [[ "$dry_run" == "true" ]]; then
        echo "ip link set $name down"
        echo "ip link delete $name type bridge"
        return 0
    fi

    if ! ip link show "$name" &>/dev/null; then
        error "bridge delete: bridge '$name' does not exist"
        return 2
    fi

    debug "bridge delete: ip link set $name down"
    if ! ip link set "$name" down 2>/dev/null; then
        error "bridge delete: failed to bring down bridge '$name'"
        return 3
    fi

    debug "bridge delete: ip link delete $name type bridge"
    if ! ip link delete "$name" type bridge 2>/dev/null; then
        error "bridge delete: failed to delete bridge '$name'"
        return 3
    fi

    info "Bridge '$name' deleted."
    return 0
}

# _bridge_add_interface
# Attaches a network interface to an existing bridge.
_bridge_add_interface() {
    local dry_run="$1"; shift
    local name="" interface=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            -I|--interface)
                interface="$2"
                shift 2
                ;;
            *)
                error "bridge add-interface: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "bridge add-interface: --name is required"
        return 1
    fi

    if [[ -z "$interface" ]]; then
        error "bridge add-interface: --interface is required"
        return 1
    fi

    if [[ "$dry_run" == "true" ]]; then
        echo "ip link set $interface master $name"
        return 0
    fi

    if ! ip link show "$name" &>/dev/null; then
        error "bridge add-interface: bridge '$name' does not exist"
        return 2
    fi

    if ! ip link show "$interface" &>/dev/null; then
        error "bridge add-interface: interface '$interface' does not exist"
        return 2
    fi

    debug "bridge add-interface: ip link set $interface master $name"
    if ! ip link set "$interface" master "$name" 2>/dev/null; then
        error "bridge add-interface: failed to attach '$interface' to bridge '$name'"
        return 3
    fi

    info "Interface '$interface' added to bridge '$name'."
    return 0
}

# _bridge_remove_interface
# Detaches a network interface from a bridge.
_bridge_remove_interface() {
    local dry_run="$1"; shift
    local name="" interface=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            -I|--interface)
                interface="$2"
                shift 2
                ;;
            *)
                error "bridge remove-interface: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "bridge remove-interface: --name is required"
        return 1
    fi

    if [[ -z "$interface" ]]; then
        error "bridge remove-interface: --interface is required"
        return 1
    fi

    if [[ "$dry_run" == "true" ]]; then
        echo "ip link set $interface nomaster"
        return 0
    fi

    if ! ip link show "$interface" &>/dev/null; then
        error "bridge remove-interface: interface '$interface' does not exist"
        return 2
    fi

    debug "bridge remove-interface: ip link set $interface nomaster"
    if ! ip link set "$interface" nomaster 2>/dev/null; then
        error "bridge remove-interface: failed to detach '$interface' from bridge '$name'"
        return 3
    fi

    info "Interface '$interface' removed from bridge '$name'."
    return 0
}
