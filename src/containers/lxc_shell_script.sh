#!/usr/bin/env bash

# Function: lxc_shell_script
# Description: Creates an executable shell script file inside an LXC container by
#              writing the provided content to a temporary file on the host, pushing
#              it into the container's rootfs, setting executable permissions, and
#              cleaning up the temporary file. Works whether the container is running
#              or stopped.
#
# Arguments:
#   --name NAME       (string, required): Name of the target LXC container.
#   --content CONTENT (string, required): The shell script content to write into the file.
#   --path PATH       (string, required): Absolute destination path inside the container
#                     (e.g. /usr/local/bin/myscript.sh).
#   --style STYLE     (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --dry-run         (flag, optional): Print the system calls that would be executed
#                     without running them. Defaults to IS_DRY_RUN if not specified.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#   IS_DRY_RUN            (read): When "true", enables dry-run mode by default.
#
# Returns:
#   0 - Script created successfully.
#   1 - Invalid or missing arguments, or LXC not installed.
#   2 - Container does not exist, or rootfs not found.
#   3 - Push or chmod operation failed.
#
# Examples:
#   lxc_shell_script --name mycontainer --content '#!/bin/bash\necho hello' --path /usr/local/bin/hello.sh
#   lxc_shell_script --name webserver --content "$(cat setup.sh)" --path /opt/setup.sh --style dots
function lxc_shell_script {
    local name=""
    local content=""
    local dest_path=""
    local style="${SPINNER_LOADING_STYLE}"
    local dry_run="${IS_DRY_RUN:-false}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            -c|--content)
                content="$2"
                shift 2
                ;;
            -p|--path)
                dest_path="$2"
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
                error "lxc_shell_script: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "lxc_shell_script: --name is required"
        return 1
    fi

    if [[ -z "$content" ]]; then
        error "lxc_shell_script: --content is required"
        return 1
    fi

    if [[ -z "$dest_path" ]]; then
        error "lxc_shell_script: --path is required"
        return 1
    fi

    local tmp_file="/tmp/shtuff_shell_script_$$.sh"
    local rootfs="/var/lib/lxc/${name}/rootfs"
    local full_dest="${rootfs}${dest_path}"

    if [[ "$dry_run" == "true" ]]; then
        echo "[DRY RUN] printf '%s' <content> > \"$tmp_file\""
        echo "[DRY RUN] cp \"$tmp_file\" \"$full_dest\""
        echo "[DRY RUN] chmod 0755 \"$full_dest\""
        echo "[DRY RUN] rm -f \"$tmp_file\""
        return 0
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "lxc_shell_script: not running as root — writing to container rootfs may fail without elevated privileges"
    fi

    if ! command -v lxc-info &>/dev/null; then
        error "lxc_shell_script: LXC is not installed. Run lxc_create first or install lxc manually."
        return 1
    fi

    if ! lxc-info -n "$name" &>/dev/null; then
        error "lxc_shell_script: container '$name' does not exist"
        return 2
    fi

    if [[ ! -d "$rootfs" ]]; then
        error "lxc_shell_script: rootfs not found for container '$name' (expected: $rootfs)"
        return 2
    fi

    debug "lxc_shell_script: writing content to temp file '$tmp_file'"
    printf '%s' "$content" > "$tmp_file" || {
        error "lxc_shell_script: failed to write temporary file '$tmp_file'"
        return 3
    }

    lxc_push "$tmp_file" "$dest_path" \
        --name "$name" \
        --style "$style" \
        --message "Creating shell script in container '$name'" || {
        rm -f "$tmp_file"
        return 3
    }

    debug "lxc_shell_script: setting executable permissions on '$full_dest'"
    chmod 0755 "$full_dest" || {
        error "lxc_shell_script: failed to set executable permissions on '$full_dest'"
        rm -f "$tmp_file"
        return 3
    }

    rm -f "$tmp_file"
    debug "lxc_shell_script: completed successfully"
    return 0
}
