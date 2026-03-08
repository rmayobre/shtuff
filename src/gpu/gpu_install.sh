#!/usr/bin/env bash

# Function: gpu_install
# Description: Installs hardware acceleration libraries on the host or inside a
#              container. Auto-detects the GPU vendor via lspci when --vendor is
#              omitted. Supports NVIDIA (CUDA toolkit + container toolkit), AMD
#              (ROCm + OpenCL), Intel (VA-API + OpenCL), and a generic OpenCL
#              fallback. When --container is provided the packages are installed
#              inside the named container via its exec backend.
#
# Arguments:
#   --vendor VENDOR (string, optional, default: auto): GPU vendor to target.
#       Valid values: nvidia, amd, intel, generic.
#       When omitted the vendor is detected via lspci. Falls back to generic
#       if detection fails or produces an ambiguous result.
#   --container NAME (string, optional): Container name or VMID to install
#       libraries inside. When omitted libraries are installed on the host.
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --dry-run (flag, optional): Print the commands that would be run without
#       executing them. Defaults to IS_DRY_RUN if not specified.
#
# Globals:
#   IS_DRY_RUN (read): When "true", enables dry-run mode by default.
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - Libraries installed successfully.
#   1 - Invalid arguments or unsupported vendor specified.
#   2 - Package installation failed.
#   3 - Container not found or exec into container failed.
#
# Examples:
#   gpu_install
#   gpu_install --vendor nvidia
#   gpu_install --vendor amd --style dots
#   gpu_install --vendor intel --container mycontainer
#   gpu_install --container 100 --dry-run
function gpu_install {
    local vendor=""
    local container=""
    local style="${SPINNER_LOADING_STYLE}"
    local dry_run="${IS_DRY_RUN:-false}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vendor)
                vendor="$2"
                shift 2
                ;;
            --container)
                container="$2"
                shift 2
                ;;
            -s|--style)
                style="$2"
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            *)
                error "gpu_install: unknown option: $1"
                return 1
                ;;
        esac
    done

    # Validate vendor if explicitly provided
    if [[ -n "$vendor" ]]; then
        case "$vendor" in
            nvidia|amd|intel|generic) ;;
            *)
                error "gpu_install: unsupported vendor '$vendor'. Valid values: nvidia, amd, intel, generic"
                return 1
                ;;
        esac
    fi

    # Auto-detect vendor from lspci when not specified
    if [[ -z "$vendor" ]]; then
        vendor=$(_gpu_detect_vendor)
        debug "gpu_install: auto-detected vendor='$vendor'"
    fi

    local -a packages=()
    case "$vendor" in
        nvidia)
            packages=(nvidia-cuda-toolkit nvidia-container-toolkit)
            ;;
        amd)
            packages=(rocm-opencl-runtime rocm-hip-runtime)
            ;;
        intel)
            packages=(intel-opencl-icd intel-media-va-driver vainfo)
            ;;
        generic)
            packages=(ocl-icd-opencl-dev clinfo)
            ;;
    esac

    info "gpu_install: installing ${vendor} acceleration libraries: ${packages[*]}"

    if [[ "$dry_run" == "true" ]]; then
        if [[ -n "$container" ]]; then
            echo "[DRY RUN] install inside container '${container}': ${packages[*]}"
        else
            echo "[DRY RUN] install on host: ${packages[*]}"
        fi
        return 0
    fi

    if [[ -n "$container" ]]; then
        _gpu_install_in_container "$container" "$style" "${packages[@]}" || return 3
    else
        _gpu_install_on_host "$style" "${packages[@]}" || return 2
    fi

    return 0
}

# _gpu_detect_vendor
# Prints the detected GPU vendor string (nvidia, amd, intel, or generic) to stdout
# by inspecting lspci output. Prints "generic" when detection is unavailable or
# inconclusive. Not part of the public API.
_gpu_detect_vendor() {
    if ! command -v lspci &>/dev/null; then
        debug "_gpu_detect_vendor: lspci not available — defaulting to generic"
        echo "generic"
        return 0
    fi

    local gpu_line
    gpu_line=$(lspci 2>/dev/null | grep -iE 'VGA compatible controller|3D controller|Display controller' | head -1)

    if [[ -z "$gpu_line" ]]; then
        debug "_gpu_detect_vendor: no GPU found via lspci — defaulting to generic"
        echo "generic"
        return 0
    fi

    if echo "$gpu_line" | grep -qi "nvidia"; then
        echo "nvidia"
    elif echo "$gpu_line" | grep -qiE "amd|ati|radeon"; then
        echo "amd"
    elif echo "$gpu_line" | grep -qi "intel"; then
        echo "intel"
    else
        echo "generic"
    fi
}

# _gpu_install_on_host
# Runs `install` for the given package list on the host, wrapped in a monitor.
_gpu_install_on_host() {
    local style="$1"
    shift
    local -a pkgs=("$@")

    install "${pkgs[@]}" &
    monitor $! \
        --style "$style" \
        --message "Installing GPU acceleration libraries" \
        --success_msg "GPU acceleration libraries installed successfully." \
        --error_msg "Failed to install GPU acceleration libraries." || return 1

    return 0
}

# _gpu_install_in_container
# Runs `install` inside the named container via the appropriate exec backend.
_gpu_install_in_container() {
    local container="$1"
    local style="$2"
    shift 2
    local -a pkgs=("$@")

    local backend
    if command -v pct &>/dev/null; then
        backend="pct"
    else
        backend="lxc"
    fi

    debug "_gpu_install_in_container: backend='$backend' container='$container' pkgs='${pkgs[*]}'"

    if [[ "$backend" == "pct" ]]; then
        if ! pct status "$container" &>/dev/null; then
            error "_gpu_install_in_container: container $container does not exist"
            return 1
        fi

        local install_cmd="apt-get update -qq && apt-get install -y ${pkgs[*]} 2>&1"
        if command -v dnf &>/dev/null; then
            install_cmd="dnf install -y ${pkgs[*]} 2>&1"
        elif command -v pacman &>/dev/null; then
            install_cmd="pacman -Sy --noconfirm ${pkgs[*]} 2>&1"
        fi

        pct exec "$container" -- bash -c "$install_cmd" > >(log_output) 2>&1 &
        monitor $! \
            --style "$style" \
            --message "Installing GPU libraries inside container $container" \
            --success_msg "GPU libraries installed in container $container." \
            --error_msg "Failed to install GPU libraries in container $container." || return 1
    else
        if ! lxc-info -n "$container" &>/dev/null; then
            error "_gpu_install_in_container: container '$container' does not exist"
            return 1
        fi

        local install_cmd="apt-get update -qq && apt-get install -y ${pkgs[*]} 2>&1"
        lxc-attach -n "$container" -- bash -c "$install_cmd" > >(log_output) 2>&1 &
        monitor $! \
            --style "$style" \
            --message "Installing GPU libraries inside container $container" \
            --success_msg "GPU libraries installed in container $container." \
            --error_msg "Failed to install GPU libraries in container $container." || return 1
    fi

    return 0
}
