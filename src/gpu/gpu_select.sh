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
    local line pci_addr desc vendor display

    while IFS= read -r line; do
        pci_addr="${line%% *}"
        desc="${line#* }"
        vendor=$(_gpu_vendor_from_desc "$desc")
        case "$vendor" in
            nvidia)  display="NVIDIA"  ;;
            amd)     display="AMD"     ;;
            intel)   display="Intel"   ;;
            *)       display="GPU"     ;;
        esac
        gpu_addrs+=("$pci_addr")
        gpu_descs+=("$desc")
        gpu_labels+=("${pci_addr}  [${display}]  ${desc}")
    done < <(lspci 2>/dev/null | grep -iE "$_GPU_LSPCI_FILTER")

    if [[ ${#gpu_addrs[@]} -eq 0 ]]; then
        error "gpu_select: no GPU devices detected on this system"
        return 1
    fi

    local prompt="Select a GPU"
    if [[ -n "$container" ]]; then
        prompt="Select a GPU for container '${container}'"
    fi

    local -a opts_args=("$prompt")
    local i
    for i in "${!gpu_labels[@]}"; do
        opts_args+=("--choice" "${gpu_labels[$i]}")
    done

    options "${opts_args[@]}" || return 1

    # Resolve the chosen label back to its array index
    local selected_label="$answer"
    local selected_index=0
    for i in "${!gpu_labels[@]}"; do
        if [[ "${gpu_labels[$i]}" == "$selected_label" ]]; then
            selected_index="$i"
            break
        fi
    done

    local selected_addr="${gpu_addrs[$selected_index]}"
    answer="${selected_addr} ${gpu_descs[$selected_index]}"

    debug "gpu_select: selected pci='${selected_addr}' desc='${gpu_descs[$selected_index]}'"

    if [[ -z "$container" ]]; then
        return 0
    fi

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
    backend=$(_container_backend)

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
            --vmid)     vmid="$2";      shift 2 ;;
            --pci-addr) pci_addr="$2";  shift 2 ;;
            --pcie)     pcie_mode="$2"; shift 2 ;;
            --index)    index="$2";     shift 2 ;;
            --dry-run)  dry_run="$2";   shift 2 ;;
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
# Enumerates all /dev/nvidia[0-9]* devices present on the host so multi-GPU
# systems are fully covered.
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

    # Build the full list of config entries to append
    local -a entries=()
    entries+=("lxc.cgroup2.devices.allow = c 226:* rwm")
    entries+=("lxc.mount.entry = /dev/dri dev/dri none bind,optional,create=dir")

    # Enumerate all NVIDIA GPU device nodes present on the host (nvidia0, nvidia1, …)
    local -a nv_gpu_devs=(/dev/nvidia[0-9]*)
    if [[ -e "${nv_gpu_devs[0]}" ]]; then
        entries+=("lxc.cgroup2.devices.allow = c 195:* rwm")
        local nv_dev
        for nv_dev in "${nv_gpu_devs[@]}"; do
            entries+=("lxc.mount.entry = ${nv_dev} dev/${nv_dev#/dev/} none bind,optional,create=file")
        done
        for nv_dev in /dev/nvidiactl /dev/nvidia-uvm /dev/nvidia-uvm-tools; do
            [[ -e "$nv_dev" ]] || continue
            entries+=("lxc.mount.entry = ${nv_dev} dev/${nv_dev#/dev/} none bind,optional,create=file")
        done
    fi

    local config_file="/var/lib/lxc/${name}/config"

    if [[ "$dry_run" == "true" ]]; then
        echo "[DRY RUN] Append to ${config_file}:"
        local entry
        for entry in "${entries[@]}"; do
            echo "[DRY RUN]   ${entry}"
        done
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
        local entry
        for entry in "${entries[@]}"; do
            printf "%s\n" "$entry"
        done
    } >> "$config_file" || {
        error "_gpu_apply_passthrough_lxc: failed to write GPU config to $config_file"
        return 1
    }

    info "GPU passthrough configured for container '$name'. Restart the container to apply changes."
    return 0
}
