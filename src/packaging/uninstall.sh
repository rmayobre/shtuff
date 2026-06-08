#!/usr/bin/env bash

# Function: uninstall
# Description: Detects the system's package manager and removes one or more installed packages.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to remove, separated by spaces.
#
# Globals:
#   None
#
# Returns:
#   0 - All packages removed successfully.
#   1 - No packages specified, or no supported package manager found.
#
# Examples:
#   uninstall nginx
#   uninstall nodejs npm
uninstall() {
    if [ "$#" -eq 0 ]; then
        error "Usage: uninstall <package1> [package2...]"
        return 1
    fi

    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &>/dev/null; then
            warn "Not running as root. Package removal may fail without elevated privileges."
        else
            warn "Not running as root and 'sudo' is not available. Package removal may fail."
        fi
    fi

    local dependencies=("$@")

    if command -v apt &> /dev/null; then
        uninstall_apt "${dependencies[@]}"
    elif command -v dnf &> /dev/null; then
        uninstall_dnf "${dependencies[@]}"
    elif command -v yum &> /dev/null; then
        uninstall_yum "${dependencies[@]}"
    elif command -v zypper &> /dev/null; then
        uninstall_zypper "${dependencies[@]}"
    elif command -v pacman &> /dev/null; then
        uninstall_pacman "${dependencies[@]}"
    elif command -v apk &> /dev/null; then
        uninstall_apk "${dependencies[@]}"
    else
        error "Could not determine the primary package manager."
        error "Cannot proceed with dependency removal."
        return 1
    fi
}

# Function: uninstall_apt
# Description: Removes one or more packages using APT.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to remove.
#
# Globals:
#   None
#
# Returns:
#   0 - All packages removed successfully.
#   1 - No packages specified.
#
# Examples:
#   uninstall_apt nginx
uninstall_apt() {
    if [ "$#" -eq 0 ]; then
        error "Usage: uninstall_apt <package1> [package2...]"
        return 1
    fi
    info "Uninstalling packages with APT: $*"
    apt remove -y "$@"
}

# Function: uninstall_dnf
# Description: Removes one or more packages using DNF.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to remove.
#
# Globals:
#   None
#
# Returns:
#   0 - All packages removed successfully.
#   1 - No packages specified.
#
# Examples:
#   uninstall_dnf nginx
uninstall_dnf() {
    if [ "$#" -eq 0 ]; then
        error "Usage: uninstall_dnf <package1> [package2...]"
        return 1
    fi
    info "Uninstalling packages with DNF: $*"
    dnf remove -y "$@"
}

# Function: uninstall_yum
# Description: Removes one or more packages using YUM.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to remove.
#
# Globals:
#   None
#
# Returns:
#   0 - All packages removed successfully.
#   1 - No packages specified.
#
# Examples:
#   uninstall_yum nginx
uninstall_yum() {
    if [ "$#" -eq 0 ]; then
        error "Usage: uninstall_yum <package1> [package2...]"
        return 1
    fi
    info "Uninstalling packages with YUM: $*"
    yum remove -y "$@"
}

# Function: uninstall_zypper
# Description: Removes one or more packages using Zypper in non-interactive mode.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to remove.
#
# Globals:
#   None
#
# Returns:
#   0 - All packages removed successfully.
#   1 - No packages specified.
#
# Examples:
#   uninstall_zypper nginx
uninstall_zypper() {
    if [ "$#" -eq 0 ]; then
        error "Usage: uninstall_zypper <package1> [package2...]"
        return 1
    fi
    info "Uninstalling packages with Zypper: $*"
    zypper --non-interactive remove "$@"
}

# Function: uninstall_pacman
# Description: Removes one or more packages and their unique dependencies using Pacman.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to remove.
#
# Globals:
#   None
#
# Returns:
#   0 - All packages removed successfully.
#   1 - No packages specified.
#
# Examples:
#   uninstall_pacman nginx
uninstall_pacman() {
    if [ "$#" -eq 0 ]; then
        error "Usage: uninstall_pacman <package1> [package2...]"
        return 1
    fi
    info "Uninstalling packages with Pacman: $*"
    pacman -Rs --noconfirm "$@"
}

# Function: uninstall_apk
# Description: Removes one or more packages using APK.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to remove.
#
# Globals:
#   None
#
# Returns:
#   0 - All packages removed successfully.
#   1 - No packages specified.
#
# Examples:
#   uninstall_apk nginx
uninstall_apk() {
    if [ "$#" -eq 0 ]; then
        error "Usage: uninstall_apk <package1> [package2...]"
        return 1
    fi
    info "Uninstalling packages with APK: $*"
    apk del "$@"
}
