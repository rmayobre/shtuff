#!/usr/bin/env bash

# Function: _container_prompt
# Description: Interactively prompts the user for all container creation
#              configuration options, then delegates to 'container create'.
#              Each option is first checked against a corresponding environment
#              variable; if the variable is already set the prompt for that
#              field is skipped and the environment value is used directly.
#
# Arguments:
#   None
#
# Globals:
#   CONTAINER_NAME (read): Container name. Skips name prompt if set.
#   CONTAINER_HOSTNAME (read): Hostname inside the container. Skips hostname prompt if set.
#   CONTAINER_MEMORY (read): Memory limit in megabytes. Skips memory prompt if set.
#   CONTAINER_CORES (read): Number of CPU cores. Skips cores prompt if set.
#   CONTAINER_STORAGE (read): Storage pool (PCT) or backing store (LXC). Skips storage prompt if set.
#   CONTAINER_DISK_SIZE (read): Root disk size in gigabytes. Skips disk-size prompt if set.
#   CONTAINER_PASSWORD (read): Root password. Skips password prompt if set.
#   CONTAINER_TEMPLATE (read): Template path (PCT) or template name (LXC). Skips template prompt if set.
#   CONTAINER_DIST (read, LXC only): Distribution name. Skips dist prompt if set.
#   CONTAINER_RELEASE (read, LXC only): Distribution release. Skips release prompt if set.
#   CONTAINER_ARCH (read, LXC only): Architecture. Skips arch prompt if set.
#   answer (write): Overwritten by each internal form call.
#
# Returns:
#   0 - Container created successfully, or the user cancelled at the confirmation prompt.
#   1 - A required field was left empty.
#   N - Exit code propagated from 'container create' on failure.
#
# Examples:
#   container prompt
#   CONTAINER_NAME=myapp CONTAINER_MEMORY=1024 container prompt
function _container_prompt {
    local backend
    backend=$(_container_backend)
    debug "_container_prompt: backend='$backend'"

    local name="${CONTAINER_NAME:-}"
    local hostname="${CONTAINER_HOSTNAME:-}"
    local memory="${CONTAINER_MEMORY:-}"
    local cores="${CONTAINER_CORES:-}"
    local storage="${CONTAINER_STORAGE:-}"
    local disk_size="${CONTAINER_DISK_SIZE:-}"
    local password="${CONTAINER_PASSWORD:-}"
    local template="${CONTAINER_TEMPLATE:-}"
    local dist="${CONTAINER_DIST:-}"
    local release="${CONTAINER_RELEASE:-}"
    local arch="${CONTAINER_ARCH:-}"

    # --- name ---
    if [[ -n "$name" ]]; then
        info "Using CONTAINER_NAME='$name'"
    else
        question "Container name:"
        name="$answer"
        if [[ -z "$name" ]]; then
            error "_container_prompt: container name is required"
            return 1
        fi
    fi

    # --- template / dist / release / arch ---
    if [[ "$backend" == "pct" ]]; then
        if [[ -n "$template" ]]; then
            info "Using CONTAINER_TEMPLATE='$template'"
        else
            question "Template path (e.g. local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst):"
            template="$answer"
            if [[ -z "$template" ]]; then
                error "_container_prompt: --template is required for PCT"
                return 1
            fi
        fi
    else
        # LXC backend: template name, then download-specific fields
        if [[ -n "$template" ]]; then
            info "Using CONTAINER_TEMPLATE='$template'"
        else
            question "Template name (leave blank for 'download'):"
            template="${answer:-download}"
        fi

        if [[ "$template" == "download" ]]; then
            if [[ -n "$dist" ]]; then
                info "Using CONTAINER_DIST='$dist'"
            else
                question "Distribution (leave blank for 'debian'):"
                dist="${answer:-debian}"
            fi

            if [[ -n "$release" ]]; then
                info "Using CONTAINER_RELEASE='$release'"
            else
                question "Release (leave blank for 'trixie'):"
                release="${answer:-trixie}"
            fi

            if [[ -n "$arch" ]]; then
                info "Using CONTAINER_ARCH='$arch'"
            else
                options "Architecture:" \
                    --choice "amd64" \
                    --choice "arm64" \
                    --choice "armhf" \
                    --choice "i386"
                arch="$answer"
            fi
        fi
    fi

    # --- hostname ---
    if [[ -n "$hostname" ]]; then
        info "Using CONTAINER_HOSTNAME='$hostname'"
    else
        question "Hostname inside container (leave blank to use container name):"
        hostname="${answer:-}"
    fi

    # --- memory ---
    if [[ -n "$memory" ]]; then
        info "Using CONTAINER_MEMORY='${memory}MB'"
    else
        local mem_default
        [[ "$backend" == "pct" ]] && mem_default="512" || mem_default=""
        local mem_prompt="Memory limit in MB"
        [[ -n "$mem_default" ]] && mem_prompt+=" (leave blank for ${mem_default}MB)"
        mem_prompt+=":"
        question "$mem_prompt"
        memory="${answer:-}"
    fi

    # --- cores ---
    if [[ -n "$cores" ]]; then
        info "Using CONTAINER_CORES='$cores'"
    else
        local cores_default
        [[ "$backend" == "pct" ]] && cores_default="1" || cores_default=""
        local cores_prompt="Number of CPU cores"
        [[ -n "$cores_default" ]] && cores_prompt+=" (leave blank for ${cores_default})"
        cores_prompt+=":"
        question "$cores_prompt"
        cores="${answer:-}"
    fi

    # --- storage ---
    if [[ -n "$storage" ]]; then
        info "Using CONTAINER_STORAGE='$storage'"
    else
        if [[ "$backend" == "pct" ]]; then
            question "Storage pool (leave blank for 'local-lvm'):"
            storage="${answer:-}"
        else
            options "Storage backing store:" \
                --choice "dir" \
                --choice "btrfs" \
                --choice "zfs" \
                --choice "overlayfs" \
                --choice "best"
            storage="$answer"
        fi
    fi

    # --- disk-size ---
    if [[ -n "$disk_size" ]]; then
        info "Using CONTAINER_DISK_SIZE='${disk_size}GB'"
    else
        local disk_default
        [[ "$backend" == "pct" ]] && disk_default="8" || disk_default=""
        local disk_prompt="Root disk size in GB"
        [[ -n "$disk_default" ]] && disk_prompt+=" (leave blank for ${disk_default}GB)"
        disk_prompt+=":"
        question "$disk_prompt"
        disk_size="${answer:-}"
    fi

    # --- password ---
    if [[ -n "$password" ]]; then
        info "Using CONTAINER_PASSWORD from environment"
    else
        question "Root password (leave blank to skip):"
        password="${answer:-}"
    fi

    # --- confirmation summary ---
    info "Container configuration summary:"
    info "  Backend:  $backend"
    info "  Name:     $name"
    if [[ "$backend" == "pct" ]]; then
        info "  Template: $template"
    else
        info "  Template: $template"
        [[ "$template" == "download" ]] && info "  Dist / Release / Arch: ${dist} / ${release} / ${arch}"
    fi
    [[ -n "$hostname"  ]] && info "  Hostname: $hostname"
    [[ -n "$memory"    ]] && info "  Memory:   ${memory}MB"
    [[ -n "$cores"     ]] && info "  Cores:    $cores"
    [[ -n "$storage"   ]] && info "  Storage:  $storage"
    [[ -n "$disk_size" ]] && info "  Disk:     ${disk_size}GB"
    [[ -n "$password"  ]] && info "  Password: (set)"

    if ! confirm "Create this container?"; then
        info "container prompt: cancelled."
        return 0
    fi

    # Build create args and delegate to the unified container create command
    local create_args=(--name "$name")
    [[ -n "$template"  ]] && create_args+=(--template "$template")
    [[ -n "$hostname"  ]] && create_args+=(--hostname "$hostname")
    [[ -n "$memory"    ]] && create_args+=(--memory "$memory")
    [[ -n "$cores"     ]] && create_args+=(--cores "$cores")
    [[ -n "$storage"   ]] && create_args+=(--storage "$storage")
    [[ -n "$disk_size" ]] && create_args+=(--disk-size "$disk_size")
    [[ -n "$password"  ]] && create_args+=(--password "$password")

    # LXC download-template specific args
    if [[ "$backend" == "lxc" && "$template" == "download" ]]; then
        [[ -n "$dist"    ]] && create_args+=(--dist "$dist")
        [[ -n "$release" ]] && create_args+=(--release "$release")
        [[ -n "$arch"    ]] && create_args+=(--arch "$arch")
    fi

    debug "_container_prompt: delegating to container create ${create_args[*]}"
    container create "${create_args[@]}"
}
