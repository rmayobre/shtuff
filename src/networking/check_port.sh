#!/usr/bin/env bash

# Function: check_port
# Description: Validates a port number and checks whether it is currently bound
#              on the local host. Returns 0 if the port is valid and free,
#              1 if the port is in use, or 2 if the port number is invalid.
#
# Arguments:
#   --port PORT (integer, required): Port number to check (1–65535).
#   --dry-run (flag, optional): Print the system calls that would be executed without
#       running them. Defaults to IS_DRY_RUN if not specified.
#
# Globals:
#   IS_DRY_RUN (read): When "true", enables dry-run mode by default.
#
# Returns:
#   0 - Port number is valid and is not currently in use.
#   1 - Port is valid but is already bound (in use) on the host.
#   2 - Invalid arguments or port number out of range (not 1–65535).
#
# Examples:
#   check_port --port 8080
#   check_port --port 443
#   if check_port --port "$PORT"; then
#       info "Port $PORT is available"
#   else
#       error "Port $PORT is already in use"
#   fi
function check_port {
    local port=""
    local dry_run="${IS_DRY_RUN:-false}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--port)
                port="$2"
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            *)
                error "check_port: unknown option: $1"
                return 2
                ;;
        esac
    done

    if [[ -z "$port" ]]; then
        error "check_port: --port is required"
        return 2
    fi

    if ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
        error "check_port: invalid port number: '$port' (must be an integer between 1 and 65535)"
        return 2
    fi

    if [[ "$dry_run" == "true" ]]; then
        echo "[DRY RUN] check if port $port is bound on localhost (via ss or /proc/net/tcp)"
        return 0
    fi

    debug "check_port: checking port $port"

    if command -v ss &>/dev/null; then
        if ss -tlnp 2>/dev/null | awk 'NR>1{print $4}' | grep -qE "(^|:)${port}$"; then
            debug "check_port: port $port is in use (via ss)"
            return 1
        fi
    elif [[ -r /proc/net/tcp || -r /proc/net/tcp6 ]]; then
        local hex_port
        hex_port=$(printf "%04X" "$port")
        if grep -qi ": *[0-9A-Fa-f]*:${hex_port} " /proc/net/tcp /proc/net/tcp6 2>/dev/null; then
            debug "check_port: port $port is in use (via /proc/net/tcp)"
            return 1
        fi
    else
        warn "check_port: neither 'ss' nor /proc/net/tcp is available; cannot verify port status"
        return 0
    fi

    debug "check_port: port $port is available"
    return 0
}
