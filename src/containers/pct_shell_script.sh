#!/usr/bin/env bash

# Function: pct_shell_script
# Description: Creates an executable shell script file inside a Proxmox CT container
#              by writing the provided content to a temporary file on the host, pushing
#              it into the container with 0755 permissions, and cleaning up the temporary
#              file. The container does not need to be running for file transfers.
#
# Arguments:
#   --vmid VMID       (integer, required): Numeric ID of the target container.
#   --content CONTENT (string, optional): The shell script content to write into the file.
#                     Defaults to the value of the $script variable when omitted.
#   --path PATH       (string, required): Absolute destination path inside the container
#                     (e.g. /usr/local/bin/myscript.sh).
#   --style STYLE     (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --dry-run         (flag, optional): Print the system calls that would be executed
#                     without running them. Defaults to IS_DRY_RUN if not specified.
#
# Globals:
#   script                (read): Fallback script content used when --content is omitted.
#   SPINNER_LOADING_STYLE (read): Default loading style constant.
#   IS_DRY_RUN            (read): When "true", enables dry-run mode by default.
#
# Returns:
#   0 - Script created successfully.
#   1 - Invalid or missing arguments, or PCT not available on this system.
#   2 - Container does not exist.
#   3 - Push operation failed.
#
# Examples:
#   pct_shell_script --vmid 100 --content '#!/bin/bash\necho hello' --path /usr/local/bin/hello.sh
#   pct_shell_script --vmid 101 --content "$(cat setup.sh)" --path /opt/setup.sh --style dots
function pct_shell_script {
    local vmid=""
    local content=""
    local dest_path=""
    local style="${SPINNER_LOADING_STYLE}"
    local dry_run="${IS_DRY_RUN:-false}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vmid)
                vmid="$2"
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
                error "pct_shell_script: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$vmid" ]]; then
        error "pct_shell_script: --vmid is required"
        return 1
    fi

    if [[ -z "$content" ]]; then
        content="${script:-}"
    fi

    if [[ -z "$content" ]]; then
        error "pct_shell_script: --content is required, or set the \$script variable"
        return 1
    fi

    if [[ -z "$dest_path" ]]; then
        error "pct_shell_script: --path is required"
        return 1
    fi

    local tmp_file="/tmp/shtuff_shell_script_$$.sh"

    if [[ "$dry_run" == "true" ]]; then
        echo "[DRY RUN] printf '%s' <content> > \"$tmp_file\""
        echo "[DRY RUN] pct push $vmid \"$tmp_file\" \"$dest_path\" --perms 0755"
        echo "[DRY RUN] rm -f \"$tmp_file\""
        return 0
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "pct_shell_script: not running as root — PCT operations may fail without elevated privileges"
    fi

    if ! command -v pct &>/dev/null; then
        error "pct_shell_script: pct is not available. PCT is part of Proxmox VE and cannot be installed on non-Proxmox systems."
        return 1
    fi

    if ! pct status "$vmid" &>/dev/null; then
        error "pct_shell_script: container $vmid does not exist"
        return 2
    fi

    debug "pct_shell_script: writing content to temp file '$tmp_file'"
    printf '%s' "$content" > "$tmp_file" || {
        error "pct_shell_script: failed to write temporary file '$tmp_file'"
        return 3
    }

    pct_push "$tmp_file" "$dest_path" \
        --vmid "$vmid" \
        --perms 0755 \
        --style "$style" \
        --message "Creating shell script in container $vmid" || {
        rm -f "$tmp_file"
        return 3
    }

    rm -f "$tmp_file"
    debug "pct_shell_script: completed successfully"
    return 0
}
