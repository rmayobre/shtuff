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
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &>/dev/null; then
            warn "Not running as root. Package updates may fail without elevated privileges."
        else
            warn "Not running as root and 'sudo' is not available. Package updates may fail."
        fi
    fi

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
        error "Could not determine the primary package manager."
        error "Cannot proceed with system update."
        return 1
    fi
}

# Function: update_apt
# Description: Refreshes APT package lists and upgrades all installed packages.
#
# Arguments:
#   None
#
# Globals:
#   VERBOSE_FILE (write): Raw apt output is appended here via log_output.
#   VERBOSE_LOGS (read): Public alias for VERBOSE_FILE.
#
# Returns:
#   0 - Update completed successfully.
#   1 - apt update or apt upgrade failed.
#
# Examples:
#   update_apt
update_apt() {
    info "Running APT update (update package lists and upgrade packages)"
    apt update > >(log_output) 2>&1
    apt upgrade -y > >(log_output) 2>&1
    info "APT update completed successfully."
}

# Function: update_dnf
# Description: Upgrades all installed packages using DNF.
#
# Arguments:
#   None
#
# Globals:
#   VERBOSE_FILE (write): Raw dnf output is appended here via log_output.
#   VERBOSE_LOGS (read): Public alias for VERBOSE_FILE.
#
# Returns:
#   0 - Update completed successfully.
#   1 - dnf upgrade failed.
#
# Examples:
#   update_dnf
update_dnf() {
    info "Running DNF update (upgrade all packages)"
    dnf upgrade -y > >(log_output) 2>&1
    info "DNF update completed successfully."
}

# Function: update_yum
# Description: Updates all installed packages using YUM.
#
# Arguments:
#   None
#
# Globals:
#   VERBOSE_FILE (write): Raw yum output is appended here via log_output.
#   VERBOSE_LOGS (read): Public alias for VERBOSE_FILE.
#
# Returns:
#   0 - Update completed successfully.
#   1 - yum update failed.
#
# Examples:
#   update_yum
update_yum() {
    info "Running YUM update (update all packages)"
    yum update -y > >(log_output) 2>&1
    info "YUM update completed successfully."
}

# Function: update_zypper
# Description: Refreshes Zypper repositories and upgrades all installed packages.
#
# Arguments:
#   None
#
# Globals:
#   VERBOSE_FILE (write): Raw zypper output is appended here via log_output.
#   VERBOSE_LOGS (read): Public alias for VERBOSE_FILE.
#
# Returns:
#   0 - Update completed successfully.
#   1 - zypper refresh or zypper update failed.
#
# Examples:
#   update_zypper
update_zypper() {
    info "Running Zypper update (refresh repositories and update packages)"
    zypper refresh > >(log_output) 2>&1
    zypper --non-interactive update > >(log_output) 2>&1
    info "Zypper update completed successfully."
}

# Function: update_pacman
# Description: Synchronizes Pacman databases and upgrades all installed packages.
#
# Arguments:
#   None
#
# Globals:
#   VERBOSE_FILE (write): Raw pacman output is appended here via log_output.
#   VERBOSE_LOGS (read): Public alias for VERBOSE_FILE.
#
# Returns:
#   0 - Update completed successfully.
#   1 - pacman -Syu failed.
#
# Examples:
#   update_pacman
update_pacman() {
    info "Running Pacman update (sync databases and upgrade packages)"
    pacman -Syu --noconfirm > >(log_output) 2>&1
    info "Pacman update completed successfully."
}

# Function: update_apk
# Description: Updates the APK package index and upgrades all installed packages.
#
# Arguments:
#   None
#
# Globals:
#   VERBOSE_FILE (write): Raw apk output is appended here via log_output.
#   VERBOSE_LOGS (read): Public alias for VERBOSE_FILE.
#
# Returns:
#   0 - Update completed successfully.
#   1 - apk update or apk upgrade failed.
#
# Examples:
#   update_apk
update_apk() {
    info "Running APK update (update package index and upgrade packages)"
    apk update > >(log_output) 2>&1
    apk upgrade > >(log_output) 2>&1
    info "APK update completed successfully."
}
