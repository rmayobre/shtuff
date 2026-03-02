#!/usr/bin/env bash

# Function: wait_for_port
# Description: Polls a TCP host:port until it accepts connections or a timeout
#              is reached. Displays a loading indicator while waiting. Useful
#              for scripts that start a service and must wait for it to be ready
#              before proceeding.
#
# Arguments:
#   --host HOST (string, required): Hostname or IP address to probe.
#   --port PORT (integer, required): TCP port to probe (1–65535).
#   --timeout SECONDS (integer, optional, default: 30): Maximum seconds to wait
#       before giving up.
#   --interval SECONDS (integer, optional, default: 2): Seconds between each
#       probe attempt.
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - Port became reachable within the timeout.
#   1 - Invalid arguments or port number out of range.
#   2 - Timed out waiting for the port to become reachable.
#
# Examples:
#   wait_for_port --host 127.0.0.1 --port 8080
#   wait_for_port --host 10.0.0.10 --port 80 --timeout 60
#   wait_for_port --host 10.0.0.10 --port 5432 --timeout 120 --interval 5 || exit 1
function wait_for_port {
    local host=""
    local port=""
    local timeout=30
    local interval=2
    local style="${SPINNER_LOADING_STYLE}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -H|--host)
                host="$2"
                shift 2
                ;;
            -p|--port)
                port="$2"
                shift 2
                ;;
            -t|--timeout)
                timeout="$2"
                shift 2
                ;;
            -i|--interval)
                interval="$2"
                shift 2
                ;;
            -s|--style)
                style="$2"
                shift 2
                ;;
            *)
                error "wait_for_port: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$host" ]]; then
        error "wait_for_port: --host is required"
        return 1
    fi

    if [[ -z "$port" ]]; then
        error "wait_for_port: --port is required"
        return 1
    fi

    if ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
        error "wait_for_port: invalid port number: '$port' (must be an integer between 1 and 65535)"
        return 1
    fi

    if ! [[ "$timeout" =~ ^[0-9]+$ ]] || (( timeout < 1 )); then
        error "wait_for_port: --timeout must be a positive integer"
        return 1
    fi

    if ! [[ "$interval" =~ ^[0-9]+$ ]] || (( interval < 1 )); then
        error "wait_for_port: --interval must be a positive integer"
        return 1
    fi

    debug "wait_for_port: host='$host' port='$port' timeout=${timeout}s interval=${interval}s"

    # Run the polling loop as a background job so monitor can display a spinner.
    _wait_for_port_poll() {
        local h="$1" p="$2" t="$3" iv="$4"
        local elapsed=0
        while (( elapsed < t )); do
            if (echo >/dev/tcp/"$h"/"$p") 2>/dev/null; then
                return 0
            fi
            sleep "$iv"
            elapsed=$(( elapsed + iv ))
        done
        return 1
    }

    _wait_for_port_poll "$host" "$port" "$timeout" "$interval" &
    monitor $! \
        --style "$style" \
        --message "Waiting for $host:$port" \
        --success_msg "$host:$port is ready." \
        --error_msg "Timed out waiting for $host:$port after ${timeout}s." || return 2

    return 0
}
