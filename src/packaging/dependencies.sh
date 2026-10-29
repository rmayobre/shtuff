#!/usr/bin/env bash

# Function: dependencies
# Description: Updates system packages, then installs one or more packages individually
#              with graceful per-package failure handling. Each package is installed with
#              its own loading indicator. Packages that fail to install are skipped with
#              a warning rather than aborting the entire operation. When more than one
#              package is specified, an overall progress bar is pinned above the per-item
#              output.
#
# Arguments:
#   $@ - packages (string, optional): Package names to install. At least one package or
#        --group is required.
#   --group NAME (string, optional, repeatable): Also install the members of a group defined
#        with group, resolved to the names for this system's package manager.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Loading style used for monitor indicators.
#   GREEN (read): ANSI color applied to the filled bar segment via progress.
#   RESET_COLOR (read): ANSI reset sequence used by progress and monitor.
#   SHTUFF_GROUPS (read): Group definitions used by --group.
#   _GROUP_RESOLVED (write): Scratch result of group resolution.
#
# Returns:
#   0 - Function completed. Individual package failures are warned but do not
#       cause a non-zero return.
#   1 - No packages specified, unknown option, or unknown group.
#
# Examples:
#   dependencies curl nodejs npm unzip
#   dependencies apache2 httpd curl
#   dependencies --group webserver curl
dependencies() {
    local -a packages=()
    local -a groups=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -g|--group)
                if [[ $# -lt 2 ]]; then
                    error "dependencies: $1 requires a value"
                    return 1
                fi
                groups+=("$2"); shift 2 ;;
            -*)
                error "dependencies: unknown option: $1"
                return 1
                ;;
            *)
                packages+=("$1"); shift ;;
        esac
    done

    local g
    for g in "${groups[@]}"; do
        _group_resolve "$g" || return 1
        packages+=("${_GROUP_RESOLVED[@]}")
    done

    if [ "${#packages[@]}" -eq 0 ]; then
        error "Usage: dependencies <package1> [package2...] [--group NAME]"
        return 1
    fi

    local total=${#packages[@]}

    update \
        --style "$SPINNER_LOADING_STYLE" \
        --message "Updating system packages" \
        --success_msg "System packages updated" \
        --error_msg "Failed to update system packages"

    if (( total > 1 )); then
        progress --current 0 --total "$total" --message "Installing dependencies"
        printf "\n"
    fi

    for (( i = 0; i < total; i++ )); do
        local pkg="${packages[$i]}"

        install "$pkg" \
            --style "$SPINNER_LOADING_STYLE" \
            --message "Installing $pkg" \
            --success_msg "$pkg installed" \
            --error_msg "Failed to install $pkg (skipping)" || {
            warn "Package '$pkg' could not be installed, skipping."
        }

        if (( total > 1 )); then
            progress --current $(( i + 1 )) --total "$total" --message "Installing dependencies" \
                --lines-above $(( i + 2 ))
        fi
    done

    return 0
}
