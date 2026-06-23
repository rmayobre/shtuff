#!/usr/bin/env bash

# Function: dependencies
# Description: Updates system packages, then installs one or more packages individually
#              with graceful per-package failure handling. Each package is installed in
#              the background with its own loading indicator via monitor. Packages that
#              fail to install are skipped with a warning rather than aborting the entire
#              operation. When more than one package is specified, an overall progress bar
#              is pinned above the per-item output.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to install.
#
# Globals:
#   SPINNER_LOADING_STYLE (read): Loading style used for monitor indicators.
#   GREEN (read): ANSI color applied to the filled bar segment via progress.
#   RESET_COLOR (read): ANSI reset sequence used by progress and monitor.
#
# Returns:
#   0 - Function completed. Individual package failures are warned but do not
#       cause a non-zero return.
#   1 - No packages specified.
#
# Examples:
#   dependencies curl nodejs npm unzip
#   dependencies apache2 httpd curl
dependencies() {
    if [ "$#" -eq 0 ]; then
        error "Usage: dependencies <package1> [package2...]"
        return 1
    fi

    local -a packages=("$@")
    local total=${#packages[@]}

    update &
    monitor $! \
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

        install "$pkg" &
        monitor $! \
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
