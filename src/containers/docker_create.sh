#!/usr/bin/env bash

# Function: docker_create
# Description: Creates a Docker container from an image without starting it, installing
#              Docker first if it is not present. Supports repeated --port, --volume,
#              and --env flags to attach multiple mappings.
#
# Arguments:
#   --name NAME (string, required): Name to assign to the container.
#   --image IMAGE (string, required): Docker image to create the container from.
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
#   2 - Docker installation failed.
#   3 - Container creation failed.
#
# Examples:
#   docker_create --name myapp --image nginx:latest
#   docker_create --name webserver --image nginx:latest \
#       --port 80:80 --port 443:443 \
#       --volume /opt/html:/usr/share/nginx/html \
#       --env NGINX_PORT=80 \
#       --restart unless-stopped
function docker_create {
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
                error "docker_create: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "docker_create: --name is required"
        return 1
    fi

    if [[ -z "$image" ]]; then
        error "docker_create: --image is required"
        return 1
    fi

    # Ensure Docker is installed
    if ! command -v docker &>/dev/null; then
        info "Docker not found — installing..."
        install docker.io &
        monitor $! \
            --style "$style" \
            --message "Installing Docker" \
            --success_msg "Docker installed." \
            --error_msg "Docker installation failed." || return 2
    fi

    # Build docker create arguments
    local docker_args=(--name "$name" --restart "$restart")

    for port in "${ports[@]}"; do
        docker_args+=(-p "$port")
    done

    for vol in "${volumes[@]}"; do
        docker_args+=(-v "$vol")
    done

    for env in "${envs[@]}"; do
        docker_args+=(-e "$env")
    done

    if [[ -n "$network" ]]; then
        docker_args+=(--network "$network")
    fi

    debug "docker_create: name='$name' image='$image' args='${docker_args[*]}'"
    info "Creating Docker container '$name' from image '$image'"

    docker create "${docker_args[@]}" "$image" >/dev/null 2>&1 &
    monitor $! \
        --style "$style" \
        --message "Creating container '$name'" \
        --success_msg "Container '$name' created." \
        --error_msg "Container '$name' creation failed." || return 3

    debug "docker_create: container '$name' created successfully"
    return 0
}
