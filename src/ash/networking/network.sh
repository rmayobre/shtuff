#!/bin/sh

# Function: network
# Description: Unified interface for networking utilities. Dispatches subcommands
#              to the appropriate networking function.
#
# Arguments:
#   $1 - command (string, required): Subcommand: download, check, wait, bridge, forward.
#   $@ - Remaining arguments passed to the delegated function.
#
# Globals:
#   None
#
# Returns:
#   0 - Command completed successfully.
#   1 - Unknown subcommand or missing required arguments.
#   N - Exit code propagated from the delegated function.
#
# Examples:
#   network download --url https://example.com/file.zip --dir /tmp
#   network check --port 8080
#   network wait --host 127.0.0.1 --port 8080 --timeout 60
#   network bridge create --name lxcbr0 --ip 10.0.0.1/24
#   network forward add --from-port 8080 --to-host 10.0.0.10 --to-port 80
network() {
    local _cmd="${1:-}"
    shift || true

    case "$_cmd" in
        download) download      "$@" ;;
        check)    check_port    "$@" ;;
        wait)     wait_for_port "$@" ;;
        bridge)   bridge        "$@" ;;
        forward)  forward       "$@" ;;
        *)
            error "network: unknown command: '$_cmd'. Valid commands: download, check, wait, bridge, forward"
            return 1
            ;;
    esac
}
