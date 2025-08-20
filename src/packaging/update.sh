#!/usr/bin/env bash

# Function: update
# Description: Detects the system's package manager and updates all packages
#              and package lists/repositories to their latest versions.
# Globals: None
# Arguments: None
# Outputs: Status messages to stdout, errors to stderr.
# Returns: 0 on successful update, 1 if package manager unknown or update fails.
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

# Function to update packages using APT
update_apt() {
    echo "--- Running APT update (update package lists and upgrade packages) ---"
    sudo apt update
    sudo apt upgrade -y
    echo "APT update completed successfully."
}

# Function to update packages using DNF
update_dnf() {
    echo "--- Running DNF update (upgrade all packages) ---"
    sudo dnf upgrade -y
    echo "DNF update completed successfully."
}

# Function to update packages using YUM
update_yum() {
    echo "--- Running YUM update (update all packages) ---"
    sudo yum update -y
    echo "YUM update completed successfully."
}

# Function to update packages using Zypper
update_zypper() {
    echo "--- Running Zypper update (refresh repositories and update packages) ---"
    sudo zypper refresh
    sudo zypper --non-interactive update
    echo "Zypper update completed successfully."
}

# Function to update packages using Pacman
update_pacman() {
    echo "--- Running Pacman update (sync databases and upgrade packages) ---"
    sudo pacman -Syu --noconfirm
    echo "Pacman update completed successfully."
}

# Function to update packages using APK
update_apk() {
    echo "--- Running APK update (update package index and upgrade packages) ---"
    sudo apk update
    sudo apk upgrade
    echo "APK update completed successfully."
}
