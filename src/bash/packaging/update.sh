#!/usr/bin/env bash

# Function: update
# Description: Detects the system's package manager and upgrades all installed packages to their latest versions.
#
# Arguments:
#   None
#
# Globals:
#   None
#
# Returns:
#   0 - System update completed successfully.
#   1 - No supported package manager found.
#
# Examples:
#   update
update() {
    if command -v apt &> /dev/null; then
        update_apt
    elif command -v dnf &> /dev/null; then
        update_dnf
    elif command -v yum &> /dev/null; then
        update_yum
    elif command -v zypper &> /dev/null; then
        update_zypper
    elif command -v pacman &> /dev/null; then
        update_pacman
    elif command -v apk &> /dev/null; then
        update_apk
    else
        echo "Error: Could not determine the primary package manager."
        echo "Cannot proceed with system update."
        exit 1
    fi
}

# Function: update_apt
# Description: Refreshes APT package lists and upgrades all installed packages.
#
# Arguments:
#   None
#
# Globals:
#   None
#
# Returns:
#   0 - Update completed successfully.
#   1 - apt update or apt upgrade failed.
#
# Examples:
#   update_apt
update_apt() {
    echo "--- Running APT update (update package lists and upgrade packages) ---"
    sudo apt update
    sudo apt upgrade -y
    echo "APT update completed successfully."
}

# Function: update_dnf
# Description: Upgrades all installed packages using DNF.
#
# Arguments:
#   None
#
# Globals:
#   None
#
# Returns:
#   0 - Update completed successfully.
#   1 - dnf upgrade failed.
#
# Examples:
#   update_dnf
update_dnf() {
    echo "--- Running DNF update (upgrade all packages) ---"
    sudo dnf upgrade -y
    echo "DNF update completed successfully."
}

# Function: update_yum
# Description: Updates all installed packages using YUM.
#
# Arguments:
#   None
#
# Globals:
#   None
#
# Returns:
#   0 - Update completed successfully.
#   1 - yum update failed.
#
# Examples:
#   update_yum
update_yum() {
    echo "--- Running YUM update (update all packages) ---"
    sudo yum update -y
    echo "YUM update completed successfully."
}

# Function: update_zypper
# Description: Refreshes Zypper repositories and upgrades all installed packages.
#
# Arguments:
#   None
#
# Globals:
#   None
#
# Returns:
#   0 - Update completed successfully.
#   1 - zypper refresh or zypper update failed.
#
# Examples:
#   update_zypper
update_zypper() {
    echo "--- Running Zypper update (refresh repositories and update packages) ---"
    sudo zypper refresh
    sudo zypper --non-interactive update
    echo "Zypper update completed successfully."
}

# Function: update_pacman
# Description: Synchronizes Pacman databases and upgrades all installed packages.
#
# Arguments:
#   None
#
# Globals:
#   None
#
# Returns:
#   0 - Update completed successfully.
#   1 - pacman -Syu failed.
#
# Examples:
#   update_pacman
update_pacman() {
    echo "--- Running Pacman update (sync databases and upgrade packages) ---"
    sudo pacman -Syu --noconfirm
    echo "Pacman update completed successfully."
}

# Function: update_apk
# Description: Updates the APK package index and upgrades all installed packages.
#
# Arguments:
#   None
#
# Globals:
#   None
#
# Returns:
#   0 - Update completed successfully.
#   1 - apk update or apk upgrade failed.
#
# Examples:
#   update_apk
update_apk() {
    echo "--- Running APK update (update package index and upgrade packages) ---"
    sudo apk update
    sudo apk upgrade
    echo "APK update completed successfully."
}
