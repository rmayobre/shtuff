#!/usr/bin/env bash

# Function: gpu_select
# Description: Interactively prompts the user to choose a GPU from the host's
#              detected PCI GPU devices. When --container is provided the selected
#              GPU is automatically configured for passthrough into that container
#              using the appropriate backend (PCT hostpci or LXC cgroup/mount).
#              The selected GPU descriptor is always stored in the global variable
#              'answer' regardless of whether --container is given.
#
# Arguments:
#   --container NAME (string, optional): Container name or VMID to configure GPU
#       passthrough for after the user makes a selection.
#   --index N (integer, optional, default: 0): hostpci slot index to use when
#       configuring PCT passthrough. Ignored for LXC backends.
#   --pcie (flag, optional): Enable PCIe passthrough mode (pcie=1) for PCT. Has
#       no effect on LXC backends.
#   --dry-run (flag, optional): Print the passthrough commands that would be
#       executed without applying them. Defaults to IS_DRY_RUN if not specified.
#
# Globals:
#   answer (write): Set to the full GPU descriptor string of the selected GPU,
#       e.g. "01:00.0 NVIDIA Corporation GA102 [GeForce RTX 3090] (rev a1)".
#   IS_DRY_RUN (read): When "true", enables dry-run mode by default.
#
# Returns:
#   0 - Selection made (and passthrough configured if --container was provided).
#   1 - lspci not available, no GPUs found, or invalid arguments.
#   2 - Container not found or passthrough configuration failed.
#
# Examples:
#   gpu_select
#   echo "You selected: $answer"
#
#   gpu_select --container mycontainer
#   gpu_select --container 100 --pcie
#   gpu_select --container 101 --index 1 --pcie --dry-run
function gpu_select {
    local container=""
    local pcie_mode="false"
    local hostpci_index="0"
    local dry_run="${IS_DRY_RUN:-false}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --container)
                container="$2"
                shift 2
                ;;
            --index)
                hostpci_index="$2"
                shift 2
                ;;
            --pcie)
                pcie_mode="true"
                shift
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            *)
                error "gpu_select: unknown option: $1"
                return 1
                ;;
        esac
    done

    if ! command -v lspci &>/dev/null; then
        error "gpu_select: lspci is not available. Install pciutils to detect GPU devices."
        return 1
    fi

    local -a gpu_addrs=()
    local -a gpu_descs=()
    local -a gpu_labels=()
    local line pci_addr desc vendor

    while IFS= read -r line; do
        pci_addr="${line%% *}"
        desc="${line#* }"

        if echo "$desc" | grep -qi "nvidia"; then
            vendor="NVIDIA"
        elif echo "$desc" | grep -qiE "amd|ati|radeon"; then
            vendor="AMD"
        elif echo "$desc" | grep -qi "intel"; then
            vendor="Intel"
        else
            vendor="GPU"
        fi

        gpu_addrs+=("$pci_addr")
        gpu_descs+=("$desc")
        gpu_labels+=("${pci_addr}  [${vendor}]  ${desc}")
    done < <(lspci 2>/dev/null | grep -iE 'VGA compatible controller|3D controller|Display controller')

    if [[ ${#gpu_addrs[@]} -eq 0 ]]; then
        error "gpu_select: no GPU devices detected on this system"
        return 1
    fi

    local prompt="Select a GPU"
    if [[ -n "$container" ]]; then
        prompt="Select a GPU for container '${container}'"
    fi

    # Build options call args
    local -a opts_args=("$prompt")
    local i
    for i in "${!gpu_labels[@]}"; do
        opts_args+=("--choice" "${gpu_labels[$i]}")
    done

    options "${opts_args[@]}" || return 1

    # answer is now set to the chosen label; extract the PCI address from it
    local selected_label="$answer"
    local selected_addr="${selected_label%%  *}"
    local selected_index=0
    for i in "${!gpu_labels[@]}"; do
        if [[ "${gpu_labels[$i]}" == "$selected_label" ]]; then
            selected_index="$i"
            break
        fi
    done

    # Store the full descriptor in answer (addr + description)
    answer="${gpu_addrs[$selected_index]} ${gpu_descs[$selected_index]}"

    debug "gpu_select: selected pci='${selected_addr}' desc='${gpu_descs[$selected_index]}'"

    if [[ -z "$container" ]]; then
        return 0
    fi

    # Apply passthrough to the container
    _gpu_apply_passthrough \
        --container "$container" \
        --pci-addr "$selected_addr" \
        --pcie "$pcie_mode" \
        --index "$hostpci_index" \
        --dry-run "$dry_run" || return 2

    return 0
}

# _gpu_apply_passthrough
# Internal helper — applies GPU passthrough configuration to a container using
# the detected backend (PCT or LXC). Not part of the public API.
_gpu_apply_passthrough() {
    local container=""
    local pci_addr=""
    local pcie_mode="false"
    local hostpci_index="0"
    local dry_run="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --container)  container="$2";     shift 2 ;;
            --pci-addr)   pci_addr="$2";      shift 2 ;;
            --pcie)       pcie_mode="$2";     shift 2 ;;
            --index)      hostpci_index="$2"; shift 2 ;;
            --dry-run)    dry_run="$2";       shift 2 ;;
            *) shift ;;
        esac
    done

    local backend
    if command -v pct &>/dev/null; then
        backend="pct"
    else
        backend="lxc"
    fi

    debug "_gpu_apply_passthrough: backend='$backend' container='$container' pci='$pci_addr'"

    if [[ "$backend" == "pct" ]]; then
        _gpu_apply_passthrough_pct \
            --vmid "$container" \
            --pci-addr "$pci_addr" \
            --pcie "$pcie_mode" \
            --index "$hostpci_index" \
            --dry-run "$dry_run"
    else
        _gpu_apply_passthrough_lxc \
            --name "$container" \
            --pci-addr "$pci_addr" \
            --dry-run "$dry_run"
    fi
}

# _gpu_apply_passthrough_pct
# Configures PCT hostpci passthrough for the selected GPU.
_gpu_apply_passthrough_pct() {
    local vmid=""
    local pci_addr=""
    local pcie_mode="false"
    local index="0"
    local dry_run="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vmid)     vmid="$2";     shift 2 ;;
            --pci-addr) pci_addr="$2"; shift 2 ;;
            --pcie)     pcie_mode="$2"; shift 2 ;;
            --index)    index="$2";    shift 2 ;;
            --dry-run)  dry_run="$2";  shift 2 ;;
            *) shift ;;
        esac
    done

    local hostpci_value="${pci_addr}"
    if [[ "$pcie_mode" == "true" ]]; then
        hostpci_value="${pci_addr},pcie=1"
    fi

    if [[ "$dry_run" == "true" ]]; then
        echo "[DRY RUN] pct set ${vmid} --hostpci${index} ${hostpci_value}"
        return 0
    fi

    if ! command -v pct &>/dev/null; then
        error "_gpu_apply_passthrough_pct: pct is not available on this system"
        return 1
    fi

    if ! pct status "$vmid" &>/dev/null; then
        error "_gpu_apply_passthrough_pct: container $vmid does not exist"
        return 1
    fi

    debug "_gpu_apply_passthrough_pct: pct set $vmid --hostpci${index} ${hostpci_value}"
    pct set "$vmid" "--hostpci${index}" "${hostpci_value}" > >(log_output) 2>&1 &
    monitor $! \
        --style "$SPINNER_LOADING_STYLE" \
        --message "Configuring GPU passthrough for container $vmid" \
        --success_msg "GPU passthrough configured for container $vmid." \
        --error_msg "Failed to configure GPU passthrough for container $vmid." || return 1

    return 0
}

# _gpu_apply_passthrough_lxc
# Configures LXC GPU passthrough by adding cgroup device access rules and
# bind-mounting DRI and NVIDIA device nodes into the container config.
_gpu_apply_passthrough_lxc() {
    local name=""
    local pci_addr=""
    local dry_run="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name)     name="$2";     shift 2 ;;
            --pci-addr) pci_addr="$2"; shift 2 ;;
            --dry-run)  dry_run="$2";  shift 2 ;;
            *) shift ;;
        esac
    done

    if ! command -v lxc-info &>/dev/null; then
        error "_gpu_apply_passthrough_lxc: LXC is not installed"
        return 1
    fi

    local config_file="/var/lib/lxc/${name}/config"

    if [[ "$dry_run" == "true" ]]; then
        echo "[DRY RUN] Append to ${config_file}:"
        echo "[DRY RUN]   lxc.cgroup2.devices.allow = c 226:* rwm"
        echo "[DRY RUN]   lxc.mount.entry = /dev/dri dev/dri none bind,optional,create=dir"
        if [[ -d /dev/nvidia0 ]] || [[ -e /dev/nvidia0 ]]; then
            echo "[DRY RUN]   lxc.cgroup2.devices.allow = c 195:* rwm"
            echo "[DRY RUN]   lxc.mount.entry = /dev/nvidia0 dev/nvidia0 none bind,optional,create=file"
            echo "[DRY RUN]   lxc.mount.entry = /dev/nvidiactl dev/nvidiactl none bind,optional,create=file"
            echo "[DRY RUN]   lxc.mount.entry = /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file"
            echo "[DRY RUN]   lxc.mount.entry = /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file"
        fi
        return 0
    fi

    if ! lxc-info -n "$name" &>/dev/null; then
        error "_gpu_apply_passthrough_lxc: container '$name' does not exist"
        return 1
    fi

    if [[ ! -f "$config_file" ]]; then
        error "_gpu_apply_passthrough_lxc: config file not found: $config_file"
        return 1
    fi

    debug "_gpu_apply_passthrough_lxc: appending GPU config to $config_file"

    {
        printf "\n# GPU passthrough — %s\n" "$pci_addr"
        printf "lxc.cgroup2.devices.allow = c 226:* rwm\n"
        printf "lxc.mount.entry = /dev/dri dev/dri none bind,optional,create=dir\n"
    } >> "$config_file" || {
        error "_gpu_apply_passthrough_lxc: failed to write DRI config to $config_file"
        return 1
    }

    if [[ -e /dev/nvidia0 ]]; then
        debug "_gpu_apply_passthrough_lxc: NVIDIA devices detected — adding nvidia mount entries"
        {
            printf "lxc.cgroup2.devices.allow = c 195:* rwm\n"
            printf "lxc.mount.entry = /dev/nvidia0 dev/nvidia0 none bind,optional,create=file\n"
            printf "lxc.mount.entry = /dev/nvidiactl dev/nvidiactl none bind,optional,create=file\n"
            printf "lxc.mount.entry = /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file\n"
            printf "lxc.mount.entry = /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file\n"
        } >> "$config_file" || {
            error "_gpu_apply_passthrough_lxc: failed to write NVIDIA config to $config_file"
            return 1
        }
    fi

    info "GPU passthrough configured for container '$name'. Restart the container to apply changes."
    return 0
}
