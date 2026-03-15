#!/usr/bin/env bash

# Shared constants and helpers for GPU detection — used by gpu_list, gpu_select, gpu_install.

# lspci filter pattern covering all GPU controller classes.
readonly _GPU_LSPCI_FILTER='VGA compatible controller|3D controller|Display controller'

# _gpu_vendor_from_desc
# Prints the canonical lowercase vendor name for a GPU description string.
# Returns: nvidia | amd | intel | generic
# Not part of the public API.
_gpu_vendor_from_desc() {
    local desc="$1"
    if [[ "$desc" =~ [Nn][Vv][Ii][Dd][Ii][Aa] ]]; then
        echo "nvidia"
    elif [[ "$desc" =~ ([Aa][Mm][Dd]|[Aa][Tt][Ii]|[Rr][Aa][Dd][Ee][Oo][Nn]) ]]; then
        echo "amd"
    elif [[ "$desc" =~ [Ii][Nn][Tt][Ee][Ll] ]]; then
        echo "intel"
    else
        echo "generic"
    fi
}

# Function: gpu_list
# Description: Lists all GPU devices detected on the host system. Uses lspci to
#              enumerate PCI-attached GPUs (VGA, 3D, and Display controllers) and
#              prints each with its PCI address, detected vendor, and description.
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
    done < <(lspci 2>/dev/null | grep -iE "$_GPU_LSPCI_FILTER")

    if [[ ${#pci_addrs[@]} -eq 0 ]]; then
        warn "gpu_list: no GPU devices detected on this system"
        return 2
    fi

    info "Detected GPU devices:"

    local i vendor display
    for i in "${!pci_addrs[@]}"; do
        desc="${pci_descs[$i]}"
        vendor=$(_gpu_vendor_from_desc "$desc")
        case "$vendor" in
            nvidia)  display="NVIDIA"  ;;
            amd)     display="AMD"     ;;
            intel)   display="Intel"   ;;
            *)       display="Unknown" ;;
        esac
        printf "  [%d] %s  %-8s  %s\n" "$((i + 1))" "${pci_addrs[$i]}" "$display" "$desc"
    done

    if command -v nvidia-smi &>/dev/null; then
        debug "gpu_list: nvidia-smi available — NVIDIA driver is loaded"
    fi

    return 0
}
