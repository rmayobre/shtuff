#!/usr/bin/env bash

# Function: pct_network
# Description: Configures network interface settings for a Proxmox CT container
#              using 'pct set'. Builds the --netN key=value string from individual
#              flags and applies it, optionally also setting a nameserver.
#
# Arguments:
#   --vmid VMID (integer, required): Numeric ID of the container to configure.
#   --bridge BRIDGE (string, optional, default: vmbr0): Host bridge to attach
#       the container's interface to.
#   --ip IP/PREFIX (string, optional): IP address with prefix length
#       (e.g. 192.168.1.100/24), or 'dhcp' for dynamic assignment.
#   --gateway GW (string, optional): Default gateway IP. Ignored when --ip dhcp.
#   --dns NAMESERVERS (string, optional): Space-separated list of DNS nameserver
#       IPs (e.g. "8.8.8.8 8.8.4.4"). Applied via 'pct set --nameserver'.
#   --index N (integer, optional, default: 0): Network interface index.
#       Controls which --netN option is configured.
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - Network configuration updated successfully.
#   1 - Invalid or missing arguments, or PCT not available on this system.
#   2 - Container does not exist.
#   3 - Configuration update failed.
#
# Examples:
#   pct_network --vmid 100 --bridge vmbr0 --ip 192.168.1.100/24 --gateway 192.168.1.1
#   pct_network --vmid 100 --ip dhcp
#   pct_network --vmid 101 --ip 10.0.0.10/24 --dns "8.8.8.8 8.8.4.4"
#   pct_network --vmid 102 --index 1 --bridge vmbr1 --ip 172.16.0.5/24
function pct_network {
    local vmid=""
    local bridge="vmbr0"
    local ip=""
    local gateway=""
    local dns=""
    local index=0
    local style="${SPINNER_LOADING_STYLE}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vmid)
                vmid="$2"
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
            -d|--dns)
                dns="$2"
                shift 2
                ;;
            --index)
                index="$2"
                shift 2
                ;;
            -s|--style)
                style="$2"
                shift 2
                ;;
            *)
                error "pct_network: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$vmid" ]]; then
        error "pct_network: --vmid is required"
        return 1
    fi

    if ! [[ "$index" =~ ^[0-9]+$ ]]; then
        error "pct_network: --index must be a non-negative integer"
        return 1
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "pct_network: not running as root — PCT operations may fail without elevated privileges"
    fi

    if ! command -v pct &>/dev/null; then
        error "pct_network: pct is not available. PCT is part of Proxmox VE and cannot be installed on non-Proxmox systems."
        return 1
    fi

    if ! pct status "$vmid" &>/dev/null; then
        error "pct_network: container $vmid does not exist"
        return 2
    fi

    # Build the net string: name=eth0,bridge=vmbr0[,ip=...][,gw=...]
    local net_string="name=eth${index},bridge=${bridge}"

    if [[ -n "$ip" ]]; then
        net_string="${net_string},ip=${ip}"
        if [[ "$ip" != "dhcp" && -n "$gateway" ]]; then
            net_string="${net_string},gw=${gateway}"
        fi
    fi

    debug "pct_network: vmid='$vmid' net${index}='$net_string'"

    pct set "$vmid" "--net${index}" "$net_string" > >(log_output) 2>&1 &
    monitor $! \
        --style "$style" \
        --message "Configuring network interface $index on container $vmid" \
        --success_msg "Container $vmid network interface $index configured." \
        --error_msg "Failed to configure network interface $index on container $vmid." || return 3

    if [[ -n "$dns" ]]; then
        debug "pct_network: setting nameserver '$dns' on container $vmid"
        pct set "$vmid" --nameserver "$dns" > >(log_output) 2>&1 &
        monitor $! \
            --style "$style" \
            --message "Setting DNS on container $vmid" \
            --success_msg "Container $vmid DNS set to: $dns" \
            --error_msg "Failed to set DNS on container $vmid." || return 3
    fi

    return 0
}
