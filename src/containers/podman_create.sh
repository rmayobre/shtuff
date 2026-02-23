#!/usr/bin/env bash

# Function: podman_create
# Description: Creates a Podman container from an image without starting it, installing
#              Podman first if it is not present. Supports repeated --port, --volume,
#              and --env flags to attach multiple mappings.
#
# Arguments:
#   --name NAME (string, required): Name to assign to the container.
#   --image IMAGE (string, required): Podman image to create the container from.
#   --port HOST:CONTAINER (string, optional): Publish a port mapping. May be repeated.
#   --volume HOST:CONTAINER (string, optional): Bind-mount a volume. May be repeated.
#   --env KEY=VALUE (string, optional): Set an environment variable. May be repeated.
#   --network NETWORK (string, optional): Connect the container to a network.
#   --restart POLICY (string, optional, default: "no"): Restart policy.
#       Valid values: no, always, on-failure, unless-stopped.
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#
# Returns:
#   0 - Container created successfully.
#   1 - Invalid or missing arguments.
#   2 - Podman installation failed.
#   3 - Container creation failed.
#
# Examples:
#   podman_create --name myapp --image nginx:latest
#   podman_create --name webserver --image nginx:latest \
#       --port 80:80 --port 443:443 \
#       --volume /opt/html:/usr/share/nginx/html \
#       --env NGINX_PORT=80 \
#       --restart unless-stopped
function podman_create {
    local name=""
    local image=""
    local ports=()
    local volumes=()
    local envs=()
    local network=""
    local restart="no"
    local style="${SPINNER_LOADING_STYLE}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            -i|--image)
                image="$2"
                shift 2
                ;;
            -p|--port)
                ports+=("$2")
                shift 2
                ;;
            -v|--volume)
                volumes+=("$2")
                shift 2
                ;;
            -e|--env)
                envs+=("$2")
                shift 2
                ;;
            --network)
                network="$2"
                shift 2
                ;;
            -r|--restart)
                restart="$2"
                shift 2
                ;;
            -s|--style)
                style="$2"
                shift 2
                ;;
            *)
                error "podman_create: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "podman_create: --name is required"
        return 1
    fi

    if [[ -z "$image" ]]; then
        error "podman_create: --image is required"
        return 1
    fi

    # Ensure Podman is installed
    if ! command -v podman &>/dev/null; then
        info "Podman not found — installing..."
        install podman &
        monitor $! \
            --style "$style" \
            --message "Installing Podman" \
            --success_msg "Podman installed." \
            --error_msg "Podman installation failed." || return 2
    fi

    # Build podman create arguments
    local podman_args=(--name "$name" --restart "$restart")

    for port in "${ports[@]}"; do
        podman_args+=(-p "$port")
    done

    for vol in "${volumes[@]}"; do
        podman_args+=(-v "$vol")
    done

    for env in "${envs[@]}"; do
        podman_args+=(-e "$env")
    done

    if [[ -n "$network" ]]; then
        podman_args+=(--network "$network")
    fi

    debug "podman_create: name='$name' image='$image' args='${podman_args[*]}'"
    info "Creating Podman container '$name' from image '$image'"

    podman create "${podman_args[@]}" "$image" >/dev/null 2>&1 &
    monitor $! \
        --style "$style" \
        --message "Creating container '$name'" \
        --success_msg "Container '$name' created." \
        --error_msg "Container '$name' creation failed." || return 3

    debug "podman_create: container '$name' created successfully"
    return 0
}
