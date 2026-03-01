#!/usr/bin/env bash

# Function: network
# Description: Unified interface for networking utilities. Dispatches subcommands
#              to the appropriate networking function. Individual functions
#              (download, check_port, wait_for_port, bridge, forward) remain
#              callable directly; this is a convenience entry point.
#
# Arguments:
#   $1 - command (string, required): Subcommand to run.
#       Valid values: download, check-port, wait-for-port, bridge, forward.
#
#   download subcommand:
#   --url URL (string, required): URL to download.
#   --dir DIR (string, optional): Directory to save the file.
#   --output NAME (string, optional): Output filename.
#   --style STYLE (string, optional): Loading indicator style.
#   --message MSG (string, optional): Progress message.
#
#   check-port subcommand:
#   --port PORT (integer, required): Port number to check (1–65535).
#
#   wait-for-port subcommand:
#   --host HOST (string, required): Hostname or IP to probe.
#   --port PORT (integer, required): TCP port to probe.
#   --timeout SECONDS (integer, optional, default: 30): Max seconds to wait.
#   --interval SECONDS (integer, optional, default: 2): Seconds between probes.
#   --style STYLE (string, optional): Loading indicator style.
#
#   bridge subcommand — manage Linux bridge interfaces:
#   See bridge function for full subcommand and flag documentation.
#   Valid bridge subcommands: create, delete, add-interface, remove-interface.
#
#   forward subcommand — manage iptables DNAT port forwarding rules:
#   See forward function for full subcommand and flag documentation.
#   Valid forward subcommands: add, remove, list.
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
#   network check-port --port 8080
#   network wait-for-port --host 127.0.0.1 --port 8080 --timeout 60
#   network bridge create --name lxcbr0 --ip 10.0.0.1/24
#   network bridge add-interface --name lxcbr0 --interface eth0
#   network bridge delete --name lxcbr0
#   network forward add --from-port 8080 --to-host 10.0.0.10 --to-port 80
#   network forward remove --from-port 8080
#   network forward list
function network {
    local command="${1:-}"
    shift || true

    case "$command" in
        download)      download      "$@" ;;
        check-port)    check_port    "$@" ;;
        wait-for-port) wait_for_port "$@" ;;
        bridge)        bridge        "$@" ;;
        forward)       forward       "$@" ;;
        *)
            error "network: unknown command: '$command'. Valid commands: download, check-port, wait-for-port, bridge, forward"
            return 1
            ;;
    esac
}
