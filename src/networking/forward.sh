#!/usr/bin/env bash

# Function: forward
# Description: Manages iptables NAT DNAT rules for host-to-container port
#              forwarding. Supports adding, removing, and listing forwarding
#              rules. Also ensures IP forwarding is enabled in the kernel.
#              Rules are not persistent across reboots without iptables-persistent
#              or an equivalent tool.
#
# Arguments:
#   $1 - command (string, required): Subcommand to run.
#       Valid values: add, remove, list.
#
#   add subcommand:
#   --from-port PORT (integer, required): Host port to forward from.
#   --to-host HOST (string, required): Destination IP address (e.g. container IP).
#   --to-port PORT (integer, optional, default: same as --from-port): Destination port.
#   --protocol PROTO (string, optional, default: tcp): Protocol (tcp or udp).
#
#   remove subcommand:
#   --from-port PORT (integer, required): Host port of the rule to remove.
#   --protocol PROTO (string, optional, default: tcp): Protocol of the rule to remove.
#
#   list subcommand:
#   No additional arguments. Displays current NAT PREROUTING rules.
#
# Globals:
#   None
#
# Returns:
#   0 - Command completed successfully.
#   1 - Invalid arguments, unknown subcommand, or iptables not available.
#   2 - No matching rule found (remove only).
#   3 - Operation failed.
#
# Examples:
#   forward add --from-port 8080 --to-host 10.0.0.10 --to-port 80
#   forward add --from-port 2222 --to-host 10.0.0.10 --to-port 22 --protocol tcp
#   forward add --from-port 5353 --to-host 10.0.0.20 --protocol udp
#   forward remove --from-port 8080
#   forward remove --from-port 5353 --protocol udp
#   forward list
function forward {
    local command="${1:-}"
    shift || true

    if ! command -v iptables &>/dev/null; then
        error "forward: 'iptables' command not found. Install iptables to manage port forwarding."
        return 1
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "forward: not running as root — iptables operations may fail without elevated privileges"
    fi

    case "$command" in
        add)    _forward_add    "$@" ;;
        remove) _forward_remove "$@" ;;
        list)   _forward_list   "$@" ;;
        *)
            error "forward: unknown command: '$command'. Valid commands: add, remove, list"
            return 1
            ;;
    esac
}

# _forward_add
# Adds a DNAT rule in the NAT PREROUTING chain and ensures MASQUERADE is set.
_forward_add() {
    local from_port="" to_host="" to_port="" protocol="tcp"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--from-port)
                from_port="$2"
                shift 2
                ;;
            -t|--to-host)
                to_host="$2"
                shift 2
                ;;
            -T|--to-port)
                to_port="$2"
                shift 2
                ;;
            -p|--protocol)
                protocol="$2"
                shift 2
                ;;
            *)
                error "forward add: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$from_port" ]]; then
        error "forward add: --from-port is required"
        return 1
    fi

    if [[ -z "$to_host" ]]; then
        error "forward add: --to-host is required"
        return 1
    fi

    if ! [[ "$from_port" =~ ^[0-9]+$ ]] || (( from_port < 1 || from_port > 65535 )); then
        error "forward add: invalid --from-port: '$from_port' (must be 1–65535)"
        return 1
    fi

    # Default to-port matches from-port if not specified
    if [[ -z "$to_port" ]]; then
        to_port="$from_port"
    fi

    if ! [[ "$to_port" =~ ^[0-9]+$ ]] || (( to_port < 1 || to_port > 65535 )); then
        error "forward add: invalid --to-port: '$to_port' (must be 1–65535)"
        return 1
    fi

    if [[ "$protocol" != "tcp" && "$protocol" != "udp" ]]; then
        error "forward add: --protocol must be 'tcp' or 'udp'"
        return 1
    fi

    debug "forward add: from_port=$from_port to_host=$to_host to_port=$to_port protocol=$protocol"

    # Enable IP forwarding
    if [[ "$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)" != "1" ]]; then
        debug "forward add: enabling IP forwarding"
        if ! echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null; then
            warn "forward add: could not enable IP forwarding in /proc/sys/net/ipv4/ip_forward"
        fi
    fi

    # Add the DNAT rule
    debug "forward add: iptables -t nat -A PREROUTING -p $protocol --dport $from_port -j DNAT --to-destination $to_host:$to_port"
    if ! iptables -t nat -A PREROUTING \
            -p "$protocol" \
            --dport "$from_port" \
            -j DNAT \
            --to-destination "${to_host}:${to_port}" 2>/dev/null; then
        error "forward add: failed to add DNAT rule for $protocol port $from_port → $to_host:$to_port"
        return 3
    fi

    # Ensure MASQUERADE rule exists in POSTROUTING
    if ! iptables -t nat -C POSTROUTING -j MASQUERADE &>/dev/null; then
        debug "forward add: adding MASQUERADE to POSTROUTING"
        if ! iptables -t nat -A POSTROUTING -j MASQUERADE 2>/dev/null; then
            warn "forward add: could not add MASQUERADE rule — forwarded packets may not be routed back correctly"
        fi
    fi

    info "Forwarding $protocol port $from_port → $to_host:$to_port"
    warn "forward add: this rule will not persist after reboot. Install iptables-persistent or save rules with 'iptables-save'."
    return 0
}

# _forward_remove
# Removes matching DNAT rules from the NAT PREROUTING chain.
_forward_remove() {
    local from_port="" protocol="tcp"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--from-port)
                from_port="$2"
                shift 2
                ;;
            -p|--protocol)
                protocol="$2"
                shift 2
                ;;
            *)
                error "forward remove: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$from_port" ]]; then
        error "forward remove: --from-port is required"
        return 1
    fi

    if ! [[ "$from_port" =~ ^[0-9]+$ ]] || (( from_port < 1 || from_port > 65535 )); then
        error "forward remove: invalid --from-port: '$from_port' (must be 1–65535)"
        return 1
    fi

    if [[ "$protocol" != "tcp" && "$protocol" != "udp" ]]; then
        error "forward remove: --protocol must be 'tcp' or 'udp'"
        return 1
    fi

    debug "forward remove: searching for DNAT rules on $protocol port $from_port"

    # Find all matching PREROUTING rules for this port and protocol, then delete them.
    local found=0
    local rule
    while IFS= read -r rule; do
        [[ -z "$rule" ]] && continue
        # rule is like: -A PREROUTING -p tcp -m tcp --dport 8080 -j DNAT --to-destination 10.0.0.10:80
        local delete_rule="${rule#-A PREROUTING }"
        debug "forward remove: iptables -t nat -D PREROUTING $delete_rule"
        if iptables -t nat -D PREROUTING $delete_rule 2>/dev/null; then
            found=$(( found + 1 ))
        fi
    done < <(iptables -t nat -S PREROUTING 2>/dev/null | grep -E -- "-p ${protocol}.*--dport ${from_port}[^0-9].*-j DNAT")

    if (( found == 0 )); then
        error "forward remove: no $protocol DNAT rule found for port $from_port"
        return 2
    fi

    info "Removed $found forwarding rule(s) for $protocol port $from_port."
    return 0
}

# _forward_list
# Displays current NAT PREROUTING rules.
_forward_list() {
    debug "forward list: iptables -t nat -L PREROUTING -n --line-numbers"
    if ! iptables -t nat -L PREROUTING -n --line-numbers 2>/dev/null; then
        error "forward list: failed to list NAT rules"
        return 3
    fi
    return 0
}
