#!/usr/bin/env bash

# Function: update
# Description: Detects the system's package manager and upgrades all installed packages
#              to their latest versions. Runs the package manager command in the background
#              and displays a loading indicator via monitor while the update is in progress.
#
# Arguments:
#   --message MSG (string, optional, default: "Updating system packages"): Message shown
#       during the loading indicator.
#   --style STYLE (string, optional, default: DEFAULT_LOADING_STYLE): Loading indicator style.
#   --success_msg MSG (string, optional, default: "System packages updated"): Message shown
#       on successful completion.
#   --error_msg MSG (string, optional, default: "Failed to update system packages"): Message
#       shown on failure.
#
# Globals:
#   DEFAULT_LOADING_STYLE (read): Fallback loading indicator style.
#   VERBOSE_FILE (write): Raw package manager output is appended here.
#
# Returns:
#   0 - System update completed successfully.
#   1 - No supported package manager found or update failed.
#
# Examples:
#   update
#   update --message "Updating packages" --success_msg "All packages updated"
update() {
    local message="Updating system packages"
    local style="$DEFAULT_LOADING_STYLE"
    local success_msg="System packages updated"
    local error_msg="Failed to update system packages"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m|--message)     message="$2";     shift 2 ;;
            -s|--style)       style="$2";       shift 2 ;;
            -sm|--success_msg) success_msg="$2"; shift 2 ;;
            -e|--error_msg)   error_msg="$2";   shift 2 ;;
            *)
                error "update: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &>/dev/null; then
            warn "Not running as root. Package updates may fail without elevated privileges."
        else
            warn "Not running as root and 'sudo' is not available. Package updates may fail."
        fi
    fi

    if command -v apt &> /dev/null; then
        _update_apt &
    elif command -v dnf &> /dev/null; then
        _update_dnf &
    elif command -v yum &> /dev/null; then
        _update_yum &
    elif command -v zypper &> /dev/null; then
        _update_zypper &
    elif command -v pacman &> /dev/null; then
        _update_pacman &
    elif command -v apk &> /dev/null; then
        _update_apk &
    else
        error "Could not determine the primary package manager."
        error "Cannot proceed with system update."
        return 1
    fi

    monitor $! \
        --style "$style" \
        --message "$message" \
        --success_msg "$success_msg" \
        --error_msg "$error_msg"
}

# Function: _update_apt
# Description: Refreshes APT package lists and upgrades all installed packages.
#
# Arguments:
#   None
#
# Globals:
#   VERBOSE_FILE (write): Raw apt output is appended here.
#
# Returns:
#   0 - Update completed successfully.
#   1 - apt update or apt upgrade failed.
#
# Examples:
#   _update_apt
_update_apt() {
    apt update >> "$VERBOSE_FILE" 2>&1
    apt upgrade -y >> "$VERBOSE_FILE" 2>&1
}

# Function: _update_dnf
# Description: Upgrades all installed packages using DNF.
#
# Arguments:
#   None
#
# Globals:
#   VERBOSE_FILE (write): Raw dnf output is appended here.
#
# Returns:
#   0 - Update completed successfully.
#   1 - dnf upgrade failed.
#
# Examples:
#   _update_dnf
_update_dnf() {
    dnf upgrade -y >> "$VERBOSE_FILE" 2>&1
}

# Function: _update_yum
# Description: Updates all installed packages using YUM.
#
# Arguments:
#   None
#
# Globals:
#   VERBOSE_FILE (write): Raw yum output is appended here.
#
# Returns:
#   0 - Update completed successfully.
#   1 - yum update failed.
#
# Examples:
#   _update_yum
_update_yum() {
    yum update -y >> "$VERBOSE_FILE" 2>&1
}

# Function: _update_zypper
# Description: Refreshes Zypper repositories and upgrades all installed packages.
#
# Arguments:
#   None
#
# Globals:
#   VERBOSE_FILE (write): Raw zypper output is appended here.
#
# Returns:
#   0 - Update completed successfully.
#   1 - zypper refresh or zypper update failed.
#
# Examples:
#   _update_zypper
_update_zypper() {
    zypper refresh >> "$VERBOSE_FILE" 2>&1
    zypper --non-interactive update >> "$VERBOSE_FILE" 2>&1
}

# Function: _update_pacman
# Description: Synchronizes Pacman databases and upgrades all installed packages.
#
# Arguments:
#   None
#
# Globals:
#   VERBOSE_FILE (write): Raw pacman output is appended here.
#
# Returns:
#   0 - Update completed successfully.
#   1 - pacman -Syu failed.
#
# Examples:
#   _update_pacman
_update_pacman() {
    pacman -Syu --noconfirm >> "$VERBOSE_FILE" 2>&1
}

# Function: _update_apk
# Description: Updates the APK package index and upgrades all installed packages.
#
# Arguments:
#   None
#
# Globals:
#   VERBOSE_FILE (write): Raw apk output is appended here.
#
# Returns:
#   0 - Update completed successfully.
#   1 - apk update or apk upgrade failed.
#
# Examples:
#   _update_apk
_update_apk() {
    apk update >> "$VERBOSE_FILE" 2>&1
    apk upgrade >> "$VERBOSE_FILE" 2>&1
}
