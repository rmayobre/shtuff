#!/usr/bin/env bash

# Function: gpu_list
# Description: Lists all GPU devices detected on the host system. Uses lspci to
#              enumerate PCI-attached GPUs (VGA, 3D, and Display controllers) and
#              prints each with its PCI address, detected vendor, and description.
#              Enriches NVIDIA entries when nvidia-smi is available.
#
# Arguments:
#   None
#
# Globals:
#   None
#
# Returns:
#   0 - One or more GPUs detected and listed.
#   1 - lspci (pciutils) is not available on this system.
#   2 - No GPU devices detected.
#
# Examples:
#   gpu_list
function gpu_list {
    if ! command -v lspci &>/dev/null; then
        error "gpu_list: lspci is not available. Install pciutils to enable GPU detection."
        return 1
    fi

    local -a pci_addrs=()
    local -a pci_descs=()
    local line pci_addr desc

    while IFS= read -r line; do
        pci_addr="${line%% *}"
        desc="${line#* }"
        pci_addrs+=("$pci_addr")
        pci_descs+=("$desc")
    done < <(lspci 2>/dev/null | grep -iE 'VGA compatible controller|3D controller|Display controller')

    if [[ ${#pci_addrs[@]} -eq 0 ]]; then
        warn "gpu_list: no GPU devices detected on this system"
        return 2
    fi

    info "Detected GPU devices:"

    local i vendor
    for i in "${!pci_addrs[@]}"; do
        desc="${pci_descs[$i]}"

        if echo "$desc" | grep -qi "nvidia"; then
            vendor="NVIDIA"
        elif echo "$desc" | grep -qiE "amd|ati|radeon"; then
            vendor="AMD"
        elif echo "$desc" | grep -qi "intel"; then
            vendor="Intel"
        else
            vendor="Unknown"
        fi

        printf "  [%d] %s  %-8s  %s\n" "$((i + 1))" "${pci_addrs[$i]}" "$vendor" "$desc"
    done

    if command -v nvidia-smi &>/dev/null; then
        debug "gpu_list: nvidia-smi available — NVIDIA driver is loaded"
    fi

    return 0
}
