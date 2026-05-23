#!/usr/bin/env bash

# Function: pct_create
# Description: Creates a Proxmox Container Toolkit (PCT) LXC container on a Proxmox VE host.
#              PCT is a Proxmox-specific tool and cannot be installed automatically; this
#              function will error if pct is not found on the system.
#              When --dist and --release are supplied without --template, pveam is used to
#              locate a matching template in local storage and download it if necessary.
#
# Arguments:
#   --vmid VMID (integer, required): Unique numeric ID for the new container (e.g. 100).
#   --template TEMPLATE (string, optional): CT template path as shown by pveam
#       (e.g. "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst").
#       Required unless --dist and --release are provided.
#   --dist DIST (string, optional, default: "debian"): Distribution name used to
#       auto-resolve a template via pveam when --template is not provided.
#   --release RELEASE (string, optional, default: "bookworm"): Distribution release used
#       with --dist to auto-resolve a template via pveam. Accepts either a version number
#       (e.g. "12") or a Debian/Ubuntu codename (e.g. "bookworm", "jammy"); codenames are
#       automatically mapped to their version number before searching pveam.
#   --arch ARCH (string, optional, default: "amd64"): Architecture used to filter
#       templates when auto-resolving via pveam.
#   --hostname HOSTNAME (string, optional): Hostname to assign inside the container.
#   --memory MB (integer, optional, default: 512): Memory limit in megabytes.
#   --cores N (integer, optional, default: 1): Number of CPU cores to allocate.
#   --storage STORAGE (string, optional, default: "local-lvm"): Storage pool for the root disk.
#   --disk-size GB (integer, optional, default: 8): Root disk size in gigabytes.
#   --password PASSWORD (string, optional): Root password for the container.
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.
#
# Globals:
#   IS_DRY_RUN (read): When "true", enables dry-run mode by default.
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - Container created successfully.
#   1 - Invalid or missing arguments, PCT not available, or template resolution failed.
#   3 - Container creation failed.
#
# Examples:
#   pct_create --vmid 100 --template "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
#   pct_create --vmid 101 --dist debian --release bookworm
#   pct_create --vmid 101 \
#       --template "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst" \
#       --hostname mycontainer \
#       --memory 1024 \
#       --cores 2 \
#       --storage local-lvm \
#       --disk-size 16
function pct_create {
    local vmid=""
    local template=""
    local dist=""
    local release="bookworm"
    local arch="amd64"
    local hostname=""
    local memory="512"
    local cores="1"
    local storage="local-lvm"
    local disk_size="8"
    local password=""
    local style="${SPINNER_LOADING_STYLE}"
    local dry_run="${IS_DRY_RUN:-false}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vmid)
                vmid="$2"
                shift 2
                ;;
            -t|--template)
                template="$2"
                shift 2
                ;;
            -d|--dist)
                dist="$2"
                shift 2
                ;;
            -r|--release)
                release="$2"
                shift 2
                ;;
            -a|--arch)
                arch="$2"
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
            --storage)
                storage="$2"
                shift 2
                ;;
            --disk-size)
                disk_size="$2"
                shift 2
                ;;
            -p|--password)
                password="$2"
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
                error "pct_create: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$vmid" ]]; then
        error "pct_create: --vmid is required"
        return 1
    fi

    if [[ -z "$template" && -z "$dist" ]]; then
        error "pct_create: --template is required (or provide --dist and --release to auto-resolve via pveam)"
        return 1
    fi

    if [[ "$dry_run" == "true" ]]; then
        if [[ -z "$template" ]]; then
            echo "[DRY RUN] pveam update"
            echo "[DRY RUN] pveam available  # search for ${dist}-<version-of-${release}> ${arch}"
            echo "[DRY RUN] pveam download local <matched-template>"
            template="local:vztmpl/<${dist}-*-${arch}.tar.*>"
        fi
        local dry_pct_args="$vmid \"$template\" --memory $memory --cores $cores --storage $storage --rootfs ${storage}:${disk_size}"
        [[ -n "$hostname" ]] && dry_pct_args+=" --hostname \"$hostname\""
        [[ -n "$password" ]] && dry_pct_args+=" --password ***"
        echo "[DRY RUN] pct create ${dry_pct_args}"
        return 0
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "pct_create: not running as root — PCT operations may fail without elevated privileges"
    fi

    if ! command -v pct &>/dev/null; then
        error "pct_create: pct is not available. PCT is part of Proxmox VE and cannot be installed on non-Proxmox systems."
        return 1
    fi

    # Auto-resolve template via pveam when --dist is provided without --template
    if [[ -z "$template" ]]; then
        # Map Debian/Ubuntu release codenames to the version numbers used in pveam template names.
        # Users may supply either form; pveam always uses version numbers (e.g. debian-12-*).
        local release_ver="$release"
        case "$release" in
            woody)    release_ver="3"     ;;
            sarge)    release_ver="4"     ;;
            etch)     release_ver="4"     ;;
            lenny)    release_ver="5"     ;;
            squeeze)  release_ver="6"     ;;
            wheezy)   release_ver="7"     ;;
            jessie)   release_ver="8"     ;;
            stretch)  release_ver="9"     ;;
            buster)   release_ver="10"    ;;
            bullseye) release_ver="11"    ;;
            bookworm) release_ver="12"    ;;
            trixie)   release_ver="13"    ;;
            forky)    release_ver="14"    ;;
            focal)    release_ver="20.04" ;;
            jammy)    release_ver="22.04" ;;
            noble)    release_ver="24.04" ;;
            oracular) release_ver="24.10" ;;
            plucky)   release_ver="25.04" ;;
        esac
        [[ "$release_ver" != "$release" ]] && debug "pct_create: mapped release codename '$release' -> '$release_ver'"

        local pattern="${dist}-${release_ver}"
        debug "pct_create: resolving template for dist='$dist' release='$release_ver' arch='$arch'"

        # Search locally cached templates first
        local matched
        matched=$(pveam list local 2>/dev/null | awk '{print $1}' | grep -i "$pattern" | grep "$arch" | head -1)

        if [[ -z "$matched" ]]; then
            debug "pct_create: no local template found for '$pattern', updating pveam..."
            pveam update > >(log_output) 2>&1 &
            monitor $! \
                --style "$style" \
                --message "Updating template list" \
                --success_msg "Template list updated." \
                --error_msg "Failed to update template list." || return 1

            local tpl_name
            tpl_name=$(pveam available 2>/dev/null | awk '{print $2}' | grep -i "$pattern" | grep "$arch" | head -1)
            if [[ -z "$tpl_name" ]]; then
                error "pct_create: no template found for dist='$dist' release='$release' arch='$arch'"
                return 1
            fi

            pveam download local "$tpl_name" > >(log_output) 2>&1 &
            monitor $! \
                --style "$style" \
                --message "Downloading template '$tpl_name'" \
                --success_msg "Template downloaded." \
                --error_msg "Template download failed." || return 1

            template="local:vztmpl/${tpl_name}"
        else
            template="$matched"
        fi

        debug "pct_create: resolved template='$template'"
    fi

    # Build pct create arguments
    local pct_args=(
        "$vmid" "$template"
        --memory "$memory"
        --cores "$cores"
        --storage "$storage"
        --rootfs "${storage}:${disk_size}"
    )

    if [[ -n "$hostname" ]]; then
        pct_args+=(--hostname "$hostname")
    fi

    if [[ -n "$password" ]]; then
        pct_args+=(--password "$password")
    fi

    debug "pct_create: vmid='$vmid' template='$template' args='${pct_args[*]}'"
    info "Creating PCT container $vmid from template '$template'"

    pct create "${pct_args[@]}" > >(log_output) 2>&1 &
    monitor $! \
        --style "$style" \
        --message "Creating container $vmid" \
        --success_msg "Container $vmid created." \
        --error_msg "Container $vmid creation failed." || return 3

    debug "pct_create: container $vmid created successfully"
    return 0
}
