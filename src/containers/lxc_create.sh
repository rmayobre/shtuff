#!/usr/bin/env bash

# Function: lxc_create
# Description: Creates a new LXC container, installing LXC tooling first if not present.
#
# Arguments:
#   --name NAME (string, required): Name for the new container.
#   --template TEMPLATE (string, optional, default: "download"): LXC template to use.
#   --dist DIST (string, optional, default: "ubuntu"): Distribution name (used with "download" template).
#   --release RELEASE (string, optional, default: "22.04"): Distribution release (used with "download" template).
#   --arch ARCH (string, optional, default: "amd64"): Architecture (used with "download" template).
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - Container created successfully.
#   1 - Invalid or missing arguments.
#   2 - LXC installation failed.
#   3 - Container creation failed.
#
# Examples:
#   lxc_create --name mycontainer
#   lxc_create --name webserver --dist debian --release 12 --arch amd64
#   lxc_create --name mycontainer --template download --style dots
function lxc_create {
    local name=""
    local template="download"
    local dist="ubuntu"
    local release="22.04"
    local arch="amd64"
    local style="${SPINNER_LOADING_STYLE}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
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
            -s|--style)
                style="$2"
                shift 2
                ;;
            *)
                error "lxc_create: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "lxc_create: --name is required"
        return 1
    fi

    # Ensure LXC is installed
    if ! command -v lxc-create &>/dev/null; then
        info "LXC not found — installing..."
        install lxc lxc-utils &
        monitor $! \
            --style "$style" \
            --message "Installing LXC" \
            --success_msg "LXC installed." \
            --error_msg "LXC installation failed." || return 2
    fi

    debug "lxc_create: name='$name' template='$template' dist='$dist' release='$release' arch='$arch'"

    if [[ "$template" == "download" ]]; then
        info "Creating LXC container '$name' ($dist/$release/$arch)"
        lxc-create -n "$name" -t download -- \
            --dist "$dist" \
            --release "$release" \
            --arch "$arch" \
            >/dev/null 2>&1 &
    else
        info "Creating LXC container '$name' using template '$template'"
        lxc-create -n "$name" -t "$template" >/dev/null 2>&1 &
    fi

    monitor $! \
        --style "$style" \
        --message "Creating container '$name'" \
        --success_msg "Container '$name' created." \
        --error_msg "Container '$name' creation failed." || return 3

    debug "lxc_create: container '$name' created successfully"
    return 0
}
