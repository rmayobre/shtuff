#!/usr/bin/env bash

# Function: _container_network_prompt
# Description: Interactively prompts the user for all container network
#              configuration options, then delegates to 'container network'.
#              Displays the current network config before prompting, and lists
#              available host bridge interfaces for selection. Each option is
#              first checked against a corresponding environment variable; if
#              the variable is already set the prompt for that field is skipped.
#
# Arguments:
#   --name NAME (string, required): Container name / hostname (or VMID for PCT).
#   --index N (integer, optional): Network interface index. Skips the index
#       prompt when provided.
#
# Globals:
#   CONTAINER_NETWORK_INDEX (read): Interface index. Skips index prompt if set.
#   CONTAINER_NETWORK_BRIDGE (read): Bridge interface name. Skips bridge prompt if set.
#   CONTAINER_NETWORK_IP (read): IP address with prefix, or 'dhcp'. Skips IP prompt if set.
#   CONTAINER_NETWORK_GATEWAY (read): Default gateway IP. Skips gateway prompt if set.
#   CONTAINER_NETWORK_DNS (read, PCT only): Space-separated DNS nameservers. Skips DNS prompt if set.
#   CONTAINER_NETWORK_TYPE (read, LXC only): Interface type (veth, macvlan, ipvlan, none). Skips type prompt if set.
#   CONTAINER_NETWORK_HWADDR (read, LXC only): MAC address. Skips MAC prompt if set.
#   answer (write): Overwritten by each internal form call.
#
# Returns:
#   0 - Network configured successfully, or the user cancelled at the confirmation prompt.
#   1 - A required field was left empty or an invalid value was given.
#   N - Exit code propagated from 'container network' on failure.
#
# Examples:
#   container network prompt --name mycontainer
#   container network prompt --name mycontainer --index 1
#   CONTAINER_NETWORK_BRIDGE=vmbr0 container network prompt --name 100
function _container_network_prompt {
    local name=""
    local index="${CONTAINER_NETWORK_INDEX:-}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            --index)
                index="$2"
                shift 2
                ;;
            *)
                error "_container_network_prompt: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "_container_network_prompt: --name is required"
        return 1
    fi

    local backend
    backend=$(_container_backend)
    debug "_container_network_prompt: backend='$backend' name='$name'"

    # Show current configuration before prompting
    info "Current network configuration for '$name':"
    if [[ "$backend" == "pct" ]]; then
        local vmid
        vmid=$(pct_find_vmid --name "$name") || return $?
        pct_network_show --vmid "$vmid" 2>/dev/null || true
    else
        lxc_network_show --name "$name" 2>/dev/null || true
    fi

    # --- index ---
    if [[ -n "$index" ]]; then
        info "Using CONTAINER_NETWORK_INDEX='$index'"
    else
        question "Network interface index (leave blank for 0):"
        index="${answer:-0}"
    fi

    if ! [[ "$index" =~ ^[0-9]+$ ]]; then
        error "_container_network_prompt: interface index must be a non-negative integer"
        return 1
    fi

    # --- bridge ---
    local bridge="${CONTAINER_NETWORK_BRIDGE:-}"
    if [[ -n "$bridge" ]]; then
        info "Using CONTAINER_NETWORK_BRIDGE='$bridge'"
    else
        local -a bridge_names=()
        while IFS= read -r br; do
            [[ -n "$br" ]] && bridge_names+=("$br")
        done < <(_network_list_bridges)

        if [[ ${#bridge_names[@]} -gt 0 ]]; then
            local -a bridge_choices=()
            for br in "${bridge_names[@]}"; do
                bridge_choices+=(--choice "$br")
            done
            bridge_choices+=(--choice "other (enter manually)")
            options "Select a bridge interface:" "${bridge_choices[@]}"
            if [[ "$answer" == "other (enter manually)" ]]; then
                question "Bridge interface name:"
                bridge="$answer"
            else
                bridge="$answer"
            fi
        else
            local bridge_default
            [[ "$backend" == "pct" ]] && bridge_default="vmbr0" || bridge_default="lxcbr0"
            question "Bridge interface name (leave blank for '${bridge_default}'):"
            bridge="${answer:-}"
        fi
    fi

    # --- IP configuration ---
    local ip="${CONTAINER_NETWORK_IP:-}"
    local gateway="${CONTAINER_NETWORK_GATEWAY:-}"

    if [[ -n "$ip" ]]; then
        info "Using CONTAINER_NETWORK_IP='$ip'"
    else
        local ip_mode
        if [[ "$backend" == "pct" ]]; then
            options "IP configuration:" \
                --choice "static" \
                --choice "dhcp" \
                --choice "none (configure later)"
        else
            options "IP configuration:" \
                --choice "static" \
                --choice "none (use DHCP client inside container)"
        fi
        ip_mode="$answer"

        if [[ "$ip_mode" == "static" ]]; then
            question "IP address with prefix (e.g. 10.0.0.10/24):"
            ip="$answer"
            if [[ -z "$ip" ]]; then
                error "_container_network_prompt: IP address is required for static configuration"
                return 1
            fi
        elif [[ "$ip_mode" == "dhcp" ]]; then
            ip="dhcp"
        fi
        # ip="" for "none" — leave address unconfigured
    fi

    if [[ -n "$gateway" ]]; then
        info "Using CONTAINER_NETWORK_GATEWAY='$gateway'"
    elif [[ -n "$ip" && "$ip" != "dhcp" ]]; then
        question "Default gateway (leave blank to skip):"
        gateway="${answer:-}"
    fi

    # --- DNS (PCT only) ---
    local dns="${CONTAINER_NETWORK_DNS:-}"
    if [[ "$backend" == "pct" ]]; then
        if [[ -n "$dns" ]]; then
            info "Using CONTAINER_NETWORK_DNS='$dns'"
        else
            question "DNS nameservers (leave blank to skip, e.g. 8.8.8.8 8.8.4.4):"
            dns="${answer:-}"
        fi
    fi

    # --- interface type (LXC only) ---
    local iface_type="${CONTAINER_NETWORK_TYPE:-}"
    if [[ "$backend" == "lxc" ]]; then
        if [[ -n "$iface_type" ]]; then
            info "Using CONTAINER_NETWORK_TYPE='$iface_type'"
        else
            options "Interface type:" \
                --choice "veth" \
                --choice "macvlan" \
                --choice "ipvlan" \
                --choice "none"
            iface_type="$answer"
        fi
    fi

    # --- MAC address (LXC only) ---
    local hwaddr="${CONTAINER_NETWORK_HWADDR:-}"
    if [[ "$backend" == "lxc" ]]; then
        if [[ -n "$hwaddr" ]]; then
            info "Using CONTAINER_NETWORK_HWADDR='$hwaddr'"
        else
            question "MAC address (leave blank to auto-generate):"
            hwaddr="${answer:-}"
        fi
    fi

    # --- confirmation summary ---
    info "Network configuration summary:"
    info "  Container: $name"
    info "  Backend:   $backend"
    info "  Interface: $index"
    [[ -n "$bridge" ]] && info "  Bridge:    $bridge"
    if [[ -n "$ip" ]]; then
        info "  IP:        $ip"
        [[ -n "$gateway" ]] && info "  Gateway:   $gateway"
    else
        info "  IP:        (not configured)"
    fi
    [[ "$backend" == "pct" && -n "$dns"        ]] && info "  DNS:       $dns"
    [[ "$backend" == "lxc" && -n "$iface_type" ]] && info "  Type:      $iface_type"
    [[ "$backend" == "lxc" && -n "$hwaddr"     ]] && info "  MAC:       $hwaddr"

    if ! confirm "Apply this network configuration?"; then
        info "_container_network_prompt: cancelled."
        return 0
    fi

    # Build args and delegate to container network
    local -a net_args=(--name "$name" --index "$index")
    [[ -n "$bridge"  ]] && net_args+=(--bridge "$bridge")
    [[ -n "$ip"      ]] && net_args+=(--ip "$ip")
    [[ -n "$gateway" ]] && net_args+=(--gateway "$gateway")
    if [[ "$backend" == "pct" ]]; then
        [[ -n "$dns" ]] && net_args+=(--dns "$dns")
    else
        [[ -n "$iface_type" ]] && net_args+=(--type "$iface_type")
        [[ -n "$hwaddr"     ]] && net_args+=(--hwaddr "$hwaddr")
    fi

    debug "_container_network_prompt: delegating to container network ${net_args[*]}"
    container network "${net_args[@]}"
}

# _network_list_bridges
# Prints all bridge interface names available on the host, one per line.
# Used internally by _container_network_prompt to populate the bridge selector.
_network_list_bridges() {
    ip link show type bridge 2>/dev/null \
        | awk '/^[0-9]+:/ { gsub(/:$/, "", $2); print $2 }'
}
