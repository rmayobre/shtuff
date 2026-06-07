#!/usr/bin/env bash

# Function: lxc_network_show
# Description: Displays the current network interface configuration for an LXC
#              container by reading lxc.net.* entries from the container's
#              config file at /var/lib/lxc/NAME/config.
#
# Arguments:
#   --name NAME (string, required): Name of the LXC container to inspect.
#   --index N (integer, optional): Network interface index. When given, only
#       lxc.net.<N>.* entries are shown. Omit to show all lxc.net.* entries.
#   --dry-run (flag, optional): Print the system calls that would be executed
#       without running them. Defaults to IS_DRY_RUN if not specified.
#
# Globals:
#   IS_DRY_RUN (read): When "true", enables dry-run mode by default.
#
# Returns:
#   0 - Configuration displayed successfully (or no entries found).
#   1 - Invalid or missing arguments, or lxc not installed.
#   2 - Container does not exist or config file not found.
#
# Examples:
#   lxc_network_show --name mycontainer
#   lxc_network_show --name mycontainer --index 0
function lxc_network_show {
    local name=""
    local index=""
    local dry_run="${IS_DRY_RUN:-false}"

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
            --dry-run)
                dry_run="true"
                shift
                ;;
            *)
                error "lxc_network_show: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "lxc_network_show: --name is required"
        return 1
    fi

    if [[ -n "$index" ]] && ! [[ "$index" =~ ^[0-9]+$ ]]; then
        error "lxc_network_show: --index must be a non-negative integer"
        return 1
    fi

    local config_file="/var/lib/lxc/${name}/config"

    if [[ "$dry_run" == "true" ]]; then
        if [[ -n "$index" ]]; then
            echo "[DRY RUN] grep '^lxc.net.${index}' $config_file"
        else
            echo "[DRY RUN] grep '^lxc.net' $config_file"
        fi
        return 0
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "lxc_network_show: not running as root — LXC operations may fail without elevated privileges"
    fi

    if ! command -v lxc-info &>/dev/null; then
        error "lxc_network_show: LXC is not installed."
        return 1
    fi

    if ! lxc-info -n "$name" &>/dev/null; then
        error "lxc_network_show: container '$name' does not exist"
        return 2
    fi

    if [[ ! -f "$config_file" ]]; then
        error "lxc_network_show: config file not found: $config_file"
        return 2
    fi

    local output
    if [[ -n "$index" ]]; then
        output=$(grep "^lxc\.net\.${index}\." "$config_file" 2>/dev/null)
        if [[ -z "$output" ]]; then
            warn "lxc_network_show: no lxc.net.${index}.* entries in $config_file"
            return 0
        fi
    else
        output=$(grep "^lxc\.net\." "$config_file" 2>/dev/null)
        if [[ -z "$output" ]]; then
            warn "lxc_network_show: no lxc.net.* entries in $config_file"
            return 0
        fi
    fi

    printf '%s\n' "$output"
    return 0
}
