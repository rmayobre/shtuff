#!/bin/sh

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
        echo "Usage: uninstall <package1> [package2...]"
        return 1
    fi

    if command -v apt >/dev/null 2>&1; then
        uninstall_apt "$@"
    elif command -v dnf >/dev/null 2>&1; then
        uninstall_dnf "$@"
    elif command -v yum >/dev/null 2>&1; then
        uninstall_yum "$@"
    elif command -v zypper >/dev/null 2>&1; then
        uninstall_zypper "$@"
    elif command -v pacman >/dev/null 2>&1; then
        uninstall_pacman "$@"
    elif command -v apk >/dev/null 2>&1; then
        uninstall_apk "$@"
    else
        echo "Error: Could not determine the primary package manager."
        echo "Cannot proceed with dependency removal."
        exit 1
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
        echo "Usage: uninstall_apt <package1> [package2...]"
        return 1
    fi
    echo "Uninstalling packages with APT: $*"
    sudo apt remove -y "$@"
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
        echo "Usage: uninstall_dnf <package1> [package2...]"
        return 1
    fi
    echo "Uninstalling packages with DNF: $*"
    sudo dnf remove -y "$@"
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
        echo "Usage: uninstall_yum <package1> [package2...]"
        return 1
    fi
    echo "Uninstalling packages with YUM: $*"
    sudo yum remove -y "$@"
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
        echo "Usage: uninstall_zypper <package1> [package2...]"
        return 1
    fi
    echo "Uninstalling packages with Zypper: $*"
    sudo zypper --non-interactive remove "$@"
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
        echo "Usage: uninstall_pacman <package1> [package2...]"
        return 1
    fi
    echo "Uninstalling packages with Pacman: $*"
    sudo pacman -Rs --noconfirm "$@"
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
        echo "Usage: uninstall_apk <package1> [package2...]"
        return 1
    fi
    echo "Uninstalling packages with APK: $*"
    sudo apk del "$@"
}
