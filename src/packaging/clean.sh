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
        error "Could not determine the primary package manager."
        error "Cannot proceed with cleaning process."
        return 1
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
    info "Running APT cleanup (autoremove and autoclean)"
    sudo apt autoremove -y || return 1
    sudo apt autoclean -y || return 1
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
    info "Running DNF cleanup (autoremove and clean all)"
    sudo dnf autoremove -y || return 1
    sudo dnf clean all || return 1
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
    info "Running YUM cleanup (clean all)"
    sudo yum clean all || return 1
    if command -v package-cleanup &> /dev/null; then
        info "Running package-cleanup --orphans"
        sudo package-cleanup --orphans -y || return 1
    else
        warn "'package-cleanup' not found. Install 'yum-utils' for more thorough dependency cleanup."
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
    info "Running Zypper cleanup (autoremove and clean)"
    info "Zypper automatically removes unused dependencies."
    info "Clearing cache..."
    sudo zypper clean --all || return 1
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
    info "Running Pacman cleanup (orphan removal and cache cleaning)"
    if pacman -Qtdq &> /dev/null; then
        info "Removing orphaned packages with Pacman..."
        sudo pacman -Rns --noconfirm "$(pacman -Qtdq)" || return 1
    else
        info "No orphaned packages found or nothing to remove."
    fi
    info "Cleaning Pacman package cache..."
    sudo pacman -Sc --noconfirm || return 1
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
    info "Running APK cleanup (cache clean)"
    sudo apk cache clean || return 1
}
