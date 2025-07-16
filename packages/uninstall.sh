#!/bin/bash

# Function: uninstall
# Usage: uninstall <package1> [package2...]
# Description: Detects the system's package manager and removes the desired
#              packages from the host system..
# Globals: None
# Arguments: Array of package names to be removed - separated by space.
# Outputs: Status messages to stdout, errors to stderr.
# Returns: 0 on successful cleanup, 1 if package manager unknown or cleanup fails.
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

# Function to uninstall packages using APT
uninstall_apt() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: uninstall_apt <package1> [package2...]"
        return 1
    fi
    echo "Uninstalling packages with APT: $*"
    sudo apt remove -y "$@"
    # Consider `sudo apt autoremove -y` after removal for orphaned dependencies
}

# Function to uninstall packages using DNF
uninstall_dnf() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: uninstall_dnf <package1> [package2...]"
        return 1
    fi
    echo "Uninstalling packages with DNF: $*"
    sudo dnf remove -y "$@"
    # Consider `sudo dnf autoremove -y` after removal for orphaned dependencies
}

# Function to uninstall packages using YUM
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

# Function to uninstall packages using Zypper
uninstall_zypper() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: uninstall_zypper <package1> [package2...]"
        return 1
    fi
    echo "Uninstalling packages with Zypper: $*"
    sudo zypper --non-interactive remove "$@"
    # Note: Zypper automatically handles orphaned dependencies on remove.
}

# Function to uninstall packages using Pacman
uninstall_pacman() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: uninstall_pacman <package1> [package2...]"
        return 1
    fi
    echo "Uninstalling packages with Pacman: $*"
    # -Rs: Removes package and its dependencies that are not required by other packages.
    sudo pacman -Rs --noconfirm "$@"
}

# Function to uninstall packages using APK
uninstall_apk() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: uninstall_apk <package1> [package2...]"
        return 1
    fi
    echo "Uninstalling packages with APK: $*"
    sudo apk del "$@"
}
