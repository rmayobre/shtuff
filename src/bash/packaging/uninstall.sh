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
        echo "Usage: uninstall <package1> [package2...]"
        return 1
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
    # Consider `sudo apt autoremove -y` after removal for orphaned dependencies
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
    # Consider `sudo dnf autoremove -y` after removal for orphaned dependencies
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
    # Note: Yum doesn't have a direct `autoremove` equivalent like apt/dnf,
    # but `package-cleanup --orphans` can help with cleanup.
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
    # Note: Zypper automatically handles orphaned dependencies on remove.
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
    # -Rs: Removes package and its dependencies that are not required by other packages.
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
