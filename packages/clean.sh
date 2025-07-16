#!/bin/bash

# Function: clean
# Description: Detects the system's package manager and performs a cleanup
#              operation to remove unused dependencies and clear caches.
# Globals: None
# Arguments: None
# Outputs: Status messages to stdout, errors to stderr.
# Returns: 0 on successful cleanup, 1 if package manager unknown or cleanup fails.
clean() {
    if command -v apt &> /dev/null; then
        clean_apt
    elif command -v dnf &> /dev/null; then
        clean_dnf
    elif command -v yum &> /dev/null; then
        clean_yum
    elif command -v zypper &> /dev/null; then
        clean_zypper
    elif command -v pacman &> /dev/null; then
        clean_pacman
    elif command -v apk &> /dev/null; then
        clean_apk
    else
        echo "Error: Could not determine the primary package manager."
        echo "Cannot proceed with cleaning process."
        exit 1
    fi
}

# Function to clean packages using APT
clean_apt() {
    echo "--- Running APT cleanup (autoremove and autoclean) ---"
    sudo apt autoremove -y
    sudo apt autoclean -y
}

# Function to clean packages using DNF
clean_dnf() {
    echo "--- Running DNF cleanup (autoremove and clean all) ---"
    sudo dnf autoremove -y
    sudo dnf clean all
}

# Function to clean packages using YUM
clean_yum() {
    echo "--- Running YUM cleanup (clean all) ---"
    sudo yum clean all
    if command -v package-cleanup &> /dev/null; then
        echo "--- Running package-cleanup --orphans (might require yum-utils) ---"
        sudo package-cleanup --orphans -y
    else
        echo "Note: 'package-cleanup' not found. Install 'yum-utils' for more thorough dependency cleanup."
    fi
}

# Function to clean packages using Zypper
clean_zypper() {
    echo "--- Running Zypper cleanup (autoremove and clean) ---"
    echo "zypper automically removes unused dependencies."
    echo "clearing cache..."
    sudo zypper clean --all
}

# Function to clean packages using Pacman
clean_pacman() {
    echo "--- Running Pacman cleanup (orphan removal and cache cleaning) ---"
    if pacman -Qtdq &> /dev/null; then
        echo "Removing orphaned packages with Pacman..."
        sudo pacman -Rns --noconfirm $(pacman -Qtdq)
    else
        echo "No orphaned packages found or nothing to remove."
    fi
    echo "Cleaning Pacman package cache..."
    sudo pacman -Sc --noconfirm
}

# Function to clean packages using APK
clean_apk() {
    echo "--- Running APK cleanup (cache clean) ---"
    sudo apk cache clean
}
