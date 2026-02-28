#!/usr/bin/env bash

# Function: lxc_network
# Description: Configures network interface settings for an LXC container by
#              writing lxc.net.N.* keys to /var/lib/lxc/NAME/config. If a key
#              already exists it is replaced in-place; otherwise it is appended.
#              Changes take effect the next time the container is started —
#              restart if currently running.
#
# Arguments:
#   --name NAME (string, required): Name of the container to configure.
#   --type TYPE (string, optional, default: veth): Interface type.
#       Valid values: veth, macvlan, ipvlan, none.
#   --bridge BRIDGE (string, optional, default: lxcbr0): Host bridge interface
#       that the container's veth peer is attached to (lxc.net.N.link).
#   --ip IP/PREFIX (string, optional): Static IP address with prefix length
#       (e.g. 10.0.0.10/24). Omit to leave address unconfigured (use DHCP
#       client inside the container for dynamic assignment).
#   --gateway GW (string, optional): Default gateway IP. Ignored when --ip
#       is not provided.
#   --hwaddr MAC (string, optional): Hardware (MAC) address to assign
#       (e.g. 00:16:3e:ab:cd:ef). Omit to let LXC auto-generate one.
#   --index N (integer, optional, default: 0): Network interface index.
#       Controls which lxc.net.N.* block is configured.
#
# Globals:
#   None
#
# Returns:
#   0 - Network configuration updated successfully.
#   1 - Invalid or missing arguments, or LXC not installed.
#   2 - Container does not exist or config file not found.
#   3 - Configuration write failed.
#
# Examples:
#   lxc_network --name mycontainer --bridge lxcbr0 --ip 10.0.0.10/24 --gateway 10.0.0.1
#   lxc_network --name mycontainer --ip 10.0.0.10/24 --gateway 10.0.0.1
#   lxc_network --name mycontainer --bridge lxcbr0
#   lxc_network --name mycontainer --index 1 --bridge br1 --ip 192.168.1.5/24
#   lxc_network --name mycontainer --hwaddr 00:16:3e:ab:cd:ef --ip 10.0.0.10/24
function lxc_network {
    local name=""
    local type="veth"
    local bridge="lxcbr0"
    local ip=""
    local gateway=""
    local hwaddr=""
    local index=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            --type)
                type="$2"
                shift 2
                ;;
            -b|--bridge)
                bridge="$2"
                shift 2
                ;;
            -i|--ip)
                ip="$2"
                shift 2
                ;;
            -g|--gateway)
                gateway="$2"
                shift 2
                ;;
            --hwaddr)
                hwaddr="$2"
                shift 2
                ;;
            --index)
                index="$2"
                shift 2
                ;;
            *)
                error "lxc_network: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "lxc_network: --name is required"
        return 1
    fi

    local valid_types="veth macvlan ipvlan none"
    if [[ ! " $valid_types " =~ " $type " ]]; then
        error "lxc_network: invalid --type: '$type'. Valid values: veth, macvlan, ipvlan, none"
        return 1
    fi

    if ! [[ "$index" =~ ^[0-9]+$ ]]; then
        error "lxc_network: --index must be a non-negative integer"
        return 1
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "lxc_network: not running as root — container operations may fail without elevated privileges"
    fi

    if ! command -v lxc-info &>/dev/null; then
        error "lxc_network: LXC is not installed. Run lxc_create first or install lxc manually."
        return 1
    fi

    if ! lxc-info -n "$name" &>/dev/null; then
        error "lxc_network: container '$name' does not exist"
        return 2
    fi

    local config_file="/var/lib/lxc/${name}/config"
    if [[ ! -f "$config_file" ]]; then
        error "lxc_network: config file not found: $config_file"
        return 2
    fi

    # Apply a single lxc.net.N.KEY = VALUE to the config file.
    # Replaces the line if the key already exists; appends otherwise.
    _lxc_net_apply_key() {
        local key="$1" value="$2"
        if grep -q "^${key}" "$config_file" 2>/dev/null; then
            sed -i "s|^${key}.*|${key} = ${value}|" "$config_file" || return 1
            debug "lxc_network: updated '${key} = ${value}'"
        else
            printf "%s = %s\n" "$key" "$value" >> "$config_file" || return 1
            debug "lxc_network: appended '${key} = ${value}'"
        fi
    }

    local prefix="lxc.net.${index}"

    _lxc_net_apply_key "${prefix}.type" "$type" || {
        error "lxc_network: failed to set ${prefix}.type"
        return 3
    }

    if [[ "$type" != "none" ]]; then
        _lxc_net_apply_key "${prefix}.link" "$bridge" || {
            error "lxc_network: failed to set ${prefix}.link"
            return 3
        }

        _lxc_net_apply_key "${prefix}.flags" "up" || {
            error "lxc_network: failed to set ${prefix}.flags"
            return 3
        }
    fi

    if [[ -n "$ip" ]]; then
        _lxc_net_apply_key "${prefix}.ipv4.address" "$ip" || {
            error "lxc_network: failed to set ${prefix}.ipv4.address"
            return 3
        }

        if [[ -n "$gateway" ]]; then
            _lxc_net_apply_key "${prefix}.ipv4.gateway" "$gateway" || {
                error "lxc_network: failed to set ${prefix}.ipv4.gateway"
                return 3
            }
        fi
    fi

    if [[ -n "$hwaddr" ]]; then
        _lxc_net_apply_key "${prefix}.hwaddr" "$hwaddr" || {
            error "lxc_network: failed to set ${prefix}.hwaddr"
            return 3
        }
    fi

    info "Container '$name' network interface $index configured."
    if [[ -z "$ip" && "$type" != "none" ]]; then
        info "No static IP set — configure a DHCP client inside the container for dynamic IP assignment."
    fi

    return 0
}
