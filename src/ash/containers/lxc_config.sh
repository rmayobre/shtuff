#!/bin/sh

# Function: lxc_config
# Description: Updates configuration settings for an existing LXC container by
#              modifying /var/lib/lxc/NAME/config directly. If a key already exists
#              it is replaced in-place; otherwise it is appended. Changes take effect
#              the next time the container is started — restart if currently running.
#
# Arguments:
#   --name NAME (string, required): Name of the container to configure.
#   --hostname HOSTNAME (string, optional): Hostname to set (lxc.uts.name).
#   --memory MB (integer, optional): Memory limit in megabytes (lxc.cgroup2.memory.max).
#   --cores N (integer, optional): CPU core count (lxc.cgroup2.cpuset.cpus).
#   --set KEY=VALUE (string, optional, repeatable): Set any arbitrary lxc.* config key.
#       May be specified multiple times to update several keys in one call.
#   --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.
#
# Globals:
#   IS_DRY_RUN (read): When "true", enables dry-run mode by default.
#
# Returns:
#   0 - Configuration updated successfully.
#   1 - Invalid or missing arguments, or LXC not installed.
#   2 - Container does not exist or config file not found.
#   3 - Configuration update failed.
#
# Examples:
#   lxc_config --name mycontainer --memory 2048 --cores 4
#   lxc_config --name mycontainer --hostname newname
#   lxc_config --name mycontainer --set lxc.net.0.type=veth
#   lxc_config --name mycontainer --memory 1024 --set lxc.start.auto=1
lxc_config() {
    local name=""
    local hostname=""
    local memory=""
    local cores=""
    local _set_count=0
    local dry_run="${IS_DRY_RUN:-false}"

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            -h|--hostname)
                hostname="$2"
                shift 2
                ;;
            -m|--memory)
                memory="$2"
                shift 2
                ;;
            -c|--cores)
                cores="$2"
                shift 2
                ;;
            --set)
                _set_count=$(( _set_count + 1 ))
                eval "_set_key_${_set_count}=\${2%%=*}"
                eval "_set_val_${_set_count}=\${2#*=}"
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            *)
                error "lxc_config: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [ -z "$name" ]; then
        error "lxc_config: --name is required"
        return 1
    fi

    if [ "$(id -u)" -ne 0 ]; then
        warn "lxc_config: not running as root — container operations may fail without elevated privileges"
    fi

    if ! command -v lxc-info >/dev/null 2>&1; then
        error "lxc_config: LXC is not installed. Run lxc_create first or install lxc manually."
        return 1
    fi

    if ! lxc-info -n "$name" >/dev/null 2>&1; then
        error "lxc_config: container '$name' does not exist"
        return 2
    fi

    local config_file="/var/lib/lxc/${name}/config"
    if [ ! -f "$config_file" ]; then
        error "lxc_config: config file not found: $config_file"
        return 2
    fi

    # Check that at least one setting was requested
    if [ -z "$hostname" ] && [ -z "$memory" ] && [ -z "$cores" ] && [ "$_set_count" -eq 0 ]; then
        warn "lxc_config: no configuration options provided — nothing to update"
        return 0
    fi

    if [ "$dry_run" = "true" ]; then
        local _config_file="/var/lib/lxc/${name}/config"
        [ -n "$hostname" ] && echo "[DRY RUN] set lxc.uts.name = $hostname in $_config_file"
        [ -n "$memory"   ] && echo "[DRY RUN] set lxc.cgroup2.memory.max = ${memory}M in $_config_file"
        [ -n "$cores"    ] && echo "[DRY RUN] set lxc.cgroup2.cpuset.cpus = 0-$(( cores - 1 )) in $_config_file"
        local _i=1
        while [ "$_i" -le "$_set_count" ]; do
            eval "_k=\$_set_key_${_i}"
            eval "_v=\$_set_val_${_i}"
            echo "[DRY RUN] set $_k = $_v in $_config_file"
            _i=$(( _i + 1 ))
        done
        return 0
    fi

    # Apply a single key=value to the config file.
    # Replaces the line if the key already exists; appends otherwise.
    _lxc_apply_config_key() {
        local key="$1" value="$2"
        if grep -q "^${key}" "$config_file" 2>/dev/null; then
            sed -i "s|^${key}.*|${key} = ${value}|" "$config_file" || return 1
            debug "lxc_config: updated '${key} = ${value}'"
        else
            printf "%s = %s\n" "$key" "$value" >> "$config_file" || return 1
            debug "lxc_config: appended '${key} = ${value}'"
        fi
    }

    if [ -n "$hostname" ]; then
        _lxc_apply_config_key "lxc.uts.name" "$hostname" || {
            error "lxc_config: failed to set hostname"
            return 3
        }
    fi

    if [ -n "$memory" ]; then
        _lxc_apply_config_key "lxc.cgroup2.memory.max" "${memory}M" || {
            error "lxc_config: failed to set memory limit"
            return 3
        }
    fi

    if [ -n "$cores" ]; then
        _lxc_apply_config_key "lxc.cgroup2.cpuset.cpus" "0-$(( cores - 1 ))" || {
            error "lxc_config: failed to set CPU cores"
            return 3
        }
    fi

    local _i=1
    while [ "$_i" -le "$_set_count" ]; do
        eval "_k=\$_set_key_${_i}"
        eval "_v=\$_set_val_${_i}"
        _lxc_apply_config_key "$_k" "$_v" || {
            error "lxc_config: failed to set '$_k'"
            return 3
        }
        _i=$(( _i + 1 ))
    done

    info "Container '$name' configuration updated."
    return 0
}
