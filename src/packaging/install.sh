#!/usr/bin/env bash

# Function: install
# Usage: install <package1> [package2...]
# Description: Detects the system's package manager and installs desired
#              packages to the host system.
# Globals: None
# Arguments: Array of package names to be installed - separated by space.
# Outputs: Status messages to stdout, errors to stderr.
# Returns: 0 on successful cleanup, 1 if package manager unknown or cleanup fails.
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

# Function to install packages using APT
install_apt() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: install_apt <package1> [package2...]"
        return 1
    fi
    echo "Installing packages with APT: $*"
    sudo apt update
    sudo apt install -y "$@"
}

# Function to install packages using DNF
install_dnf() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: install_dnf <package1> [package2...]"
        return 1
    fi
    echo "Installing packages with DNF: $*"
    sudo dnf install -y "$@"
}

# Function to install packages using YUM
install_yum() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: install_yum <package1> [package2...]"
        return 1
    fi
    echo "Installing packages with YUM: $*"
    sudo yum install -y "$@"
}

# Function to install packages using Zypper
install_zypper() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: install_zypper <package1> [package2...]"
        return 1
    fi
    echo "Installing packages with Zypper: $*"
    sudo zypper --non-interactive install "$@"
}

# Function to install packages using Pacman
install_pacman() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: install_pacman <package1> [package2...]"
        return 1
    fi
    echo "Installing packages with Pacman: $*"
    sudo pacman -Sy --noconfirm "$@"
}

# Function to install packages using APK
install_apk() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: install_apk <package1> [package2...]"
        return 1
    fi
    echo "Installing packages with APK: $*"
    sudo apk add "$@"
}
