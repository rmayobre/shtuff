#!/usr/bin/env bash

# Function: dependencies
# Description: Updates system packages, then installs one or more packages individually.
#              Each package is installed with its own loading indicator, and every package
#              is attempted even if an earlier one fails. By default any failure (the
#              system update or a package install) makes the function return non-zero after
#              all packages were attempted, with every failed package listed. Pass
#              --skip-failures to treat the packages as optional: failures are warned about
#              and the function still returns 0. When more than one package is specified,
#              an overall progress bar is pinned above the per-item output.
#
# Arguments:
#   $@ - packages (string, optional): Package names to install. At least one package or
#        --group is required.
#   --group NAME (string, optional, repeatable): Also install the members of a group defined
#        with group, resolved to the names for this system's package manager.
#   --skip-failures (flag, optional): Warn about and skip packages (and a failed system
#        update) instead of returning non-zero.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Loading style used for monitor indicators.
#   GREEN (read): ANSI color applied to the filled bar segment via progress.
#   RESET_COLOR (read): ANSI reset sequence used by progress and monitor.
#   SHTUFF_GROUPS (read): Group definitions used by --group.
#   _GROUP_RESOLVED (write): Scratch result of group resolution.
#
# Returns:
#   0 - Every package installed, or --skip-failures was given and failures were only warned about.
#   1 - No packages specified, unknown option, unknown group, system update failed, or one
#       or more packages failed to install (without --skip-failures).
#
# Examples:
#   dependencies curl nodejs npm unzip || exit 1
#   dependencies --group webserver curl || exit 1
#   dependencies --skip-failures htop ncdu
dependencies() {
    local -a packages=()
    local -a groups=()
    local -a failed=()
    local skip_failures=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -g|--group)
                if [[ $# -lt 2 ]]; then
                    error "dependencies: $1 requires a value"
                    return 1
                fi
                groups+=("$2"); shift 2 ;;
            --skip-failures)
                skip_failures=true; shift ;;
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
        error "Usage: dependencies <package1> [package2...] [--group NAME] [--skip-failures]"
        return 1
    fi

    local total=${#packages[@]}

    if ! update \
        --style "$SPINNER_LOADING_STYLE" \
        --message "Updating system packages" \
        --success_msg "System packages updated" \
        --error_msg "Failed to update system packages"; then
        if [[ "$skip_failures" == true ]]; then
            warn "System update failed, continuing."
        else
            error "System update failed; not installing dependencies."
            return 1
        fi
    fi

    if (( total > 1 )); then
        progress --current 0 --total "$total" --message "Installing dependencies"
        printf "\n"
    fi

    local i pkg
    for (( i = 0; i < total; i++ )); do
        pkg="${packages[$i]}"

        install "$pkg" \
            --style "$SPINNER_LOADING_STYLE" \
            --message "Installing $pkg" \
            --success_msg "$pkg installed" \
            --error_msg "Failed to install $pkg" || {
            failed+=("$pkg")
            if [[ "$skip_failures" == true ]]; then
                warn "Package '$pkg' could not be installed, skipping."
            fi
        }

        if (( total > 1 )); then
            progress --current $(( i + 1 )) --total "$total" --message "Installing dependencies" \
                --lines-above $(( i + 2 ))
        fi
    done

    if [[ ${#failed[@]} -gt 0 && "$skip_failures" == false ]]; then
        error "Failed to install: ${failed[*]}"
        return 1
    fi

    return 0
}
