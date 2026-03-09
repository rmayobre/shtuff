#!/usr/bin/env bash

# Function: install
# Description: Detects the system's package manager and installs one or more packages.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to install, separated by spaces.
#
# Globals:
#   None
#
# Returns:
#   0 - All packages installed successfully.
#   1 - No packages specified, or no supported package manager found.
#
# Examples:
#   install curl
#   install nodejs npm unzip
install() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: install <package1> [package2...]"
        return 1
    fi

    local dependencies=("$@")

    if command -v apt &> /dev/null; then
        install_apt "${dependencies[@]}"
    elif command -v dnf &> /dev/null; then
        install_dnf "${dependencies[@]}"
    elif command -v yum &> /dev/null; then
        install_yum "${dependencies[@]}"
    elif command -v zypper &> /dev/null; then
        install_zypper "${dependencies[@]}"
    elif command -v pacman &> /dev/null; then
        install_pacman "${dependencies[@]}"
    elif command -v apk &> /dev/null; then
        install_apk "${dependencies[@]}"
    else
        echo "Error: Could not determine the primary package manager."
        echo "Cannot proceed with installation."
        exit 1
    fi
}

# Function: install_apt
# Description: Installs one or more packages using APT after refreshing the package lists.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to install.
#
# Globals:
#   None
#
# Returns:
#   0 - All packages installed successfully.
#   1 - No packages specified.
#
# Examples:
#   install_apt curl git
install_apt() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: install_apt <package1> [package2...]"
        return 1
    fi
    echo "Installing packages with APT: $*"
    sudo apt update
    sudo apt install -y "$@"
}

# Function: install_dnf
# Description: Installs one or more packages using DNF.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to install.
#
# Globals:
#   None
#
# Returns:
#   0 - All packages installed successfully.
#   1 - No packages specified.
#
# Examples:
#   install_dnf curl git
install_dnf() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: install_dnf <package1> [package2...]"
        return 1
    fi
    echo "Installing packages with DNF: $*"
    sudo dnf install -y "$@"
}

# Function: install_yum
# Description: Installs one or more packages using YUM.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to install.
#
# Globals:
#   None
#
# Returns:
#   0 - All packages installed successfully.
#   1 - No packages specified.
#
# Examples:
#   install_yum curl git
install_yum() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: install_yum <package1> [package2...]"
        return 1
    fi
    echo "Installing packages with YUM: $*"
    sudo yum install -y "$@"
}

# Function: install_zypper
# Description: Installs one or more packages using Zypper in non-interactive mode.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to install.
#
# Globals:
#   None
#
# Returns:
#   0 - All packages installed successfully.
#   1 - No packages specified.
#
# Examples:
#   install_zypper curl git
install_zypper() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: install_zypper <package1> [package2...]"
        return 1
    fi
    echo "Installing packages with Zypper: $*"
    sudo zypper --non-interactive install "$@"
}

# Function: install_pacman
# Description: Installs one or more packages using Pacman, syncing the database first.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to install.
#
# Globals:
#   None
#
# Returns:
#   0 - All packages installed successfully.
#   1 - No packages specified.
#
# Examples:
#   install_pacman curl git
install_pacman() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: install_pacman <package1> [package2...]"
        return 1
    fi
    echo "Installing packages with Pacman: $*"
    sudo pacman -Sy --noconfirm "$@"
}

# Function: install_apk
# Description: Installs one or more packages using APK.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to install.
#
# Globals:
#   None
#
# Returns:
#   0 - All packages installed successfully.
#   1 - No packages specified.
#
# Examples:
#   install_apk curl git
install_apk() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: install_apk <package1> [package2...]"
        return 1
    fi
    echo "Installing packages with APK: $*"
    sudo apk add "$@"
}
