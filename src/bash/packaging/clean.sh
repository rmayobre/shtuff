#!/usr/bin/env bash

# Function: clean
# Description: Detects the system's package manager and removes unused dependencies and package caches.
#
# Arguments:
#   None
#
# Globals:
#   None
#
# Returns:
#   0 - Cleanup completed successfully.
#   1 - No supported package manager found.
#
# Examples:
#   clean
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

# Function: clean_apt
# Description: Removes unused APT dependencies and cleans the package cache.
#
# Arguments:
#   None
#
# Globals:
#   None
#
# Returns:
#   0 - Cleanup completed successfully.
#   1 - apt autoremove or autoclean failed.
#
# Examples:
#   clean_apt
clean_apt() {
    echo "--- Running APT cleanup (autoremove and autoclean) ---"
    sudo apt autoremove -y
    sudo apt autoclean -y
}

# Function: clean_dnf
# Description: Removes unused DNF dependencies and cleans all DNF caches.
#
# Arguments:
#   None
#
# Globals:
#   None
#
# Returns:
#   0 - Cleanup completed successfully.
#   1 - dnf autoremove or dnf clean failed.
#
# Examples:
#   clean_dnf
clean_dnf() {
    echo "--- Running DNF cleanup (autoremove and clean all) ---"
    sudo dnf autoremove -y
    sudo dnf clean all
}

# Function: clean_yum
# Description: Cleans all YUM caches and optionally removes orphaned packages via package-cleanup.
#
# Arguments:
#   None
#
# Globals:
#   None
#
# Returns:
#   0 - Cleanup completed successfully.
#   1 - yum clean failed.
#
# Examples:
#   clean_yum
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

# Function: clean_zypper
# Description: Cleans all Zypper package caches; orphaned dependencies are handled automatically by Zypper.
#
# Arguments:
#   None
#
# Globals:
#   None
#
# Returns:
#   0 - Cleanup completed successfully.
#   1 - zypper clean failed.
#
# Examples:
#   clean_zypper
clean_zypper() {
    echo "--- Running Zypper cleanup (autoremove and clean) ---"
    echo "zypper automically removes unused dependencies."
    echo "clearing cache..."
    sudo zypper clean --all
}

# Function: clean_pacman
# Description: Removes orphaned Pacman packages and cleans the package cache.
#
# Arguments:
#   None
#
# Globals:
#   None
#
# Returns:
#   0 - Cleanup completed successfully.
#   1 - pacman orphan removal or cache clean failed.
#
# Examples:
#   clean_pacman
clean_pacman() {
    echo "--- Running Pacman cleanup (orphan removal and cache cleaning) ---"
    if pacman -Qtdq &> /dev/null; then
        echo "Removing orphaned packages with Pacman..."
        sudo pacman -Rns --noconfirm "$(pacman -Qtdq)"
    else
        echo "No orphaned packages found or nothing to remove."
    fi
    echo "Cleaning Pacman package cache..."
    sudo pacman -Sc --noconfirm
}

# Function: clean_apk
# Description: Cleans the APK package cache.
#
# Arguments:
#   None
#
# Globals:
#   None
#
# Returns:
#   0 - Cleanup completed successfully.
#   1 - apk cache clean failed.
#
# Examples:
#   clean_apk
clean_apk() {
    echo "--- Running APK cleanup (cache clean) ---"
    sudo apk cache clean
}
