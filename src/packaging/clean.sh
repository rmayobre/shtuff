#!/usr/bin/env bash

# Function: clean
# Description: Detects the system's package manager and removes unused dependencies and
#              package caches. Runs the cleanup command in the background and displays a
#              loading indicator via monitor while the cleanup is in progress.
#
# Arguments:
#   --message MSG (string, optional, default: "Cleaning packages"): Message shown
#       during the loading indicator.
#   --style STYLE (string, optional, default: DEFAULT_LOADING_STYLE): Loading indicator style.
#   --success_msg MSG (string, optional, default: "Package cleanup complete"): Message shown
#       on successful completion.
#   --error_msg MSG (string, optional, default: "Package cleanup failed"): Message shown
#       on failure.
#
# Globals:
#   DEFAULT_LOADING_STYLE (read): Fallback loading indicator style.
#   VERBOSE_FILE (write): Raw package manager output is appended here.
#
# Returns:
#   0 - Cleanup completed successfully.
#   1 - No supported package manager found or cleanup failed.
#
# Examples:
#   clean
#   clean --message "Removing unused packages" --success_msg "Cleanup done"
clean() {
    local message="Cleaning packages"
    local style="$DEFAULT_LOADING_STYLE"
    local success_msg="Package cleanup complete"
    local error_msg="Package cleanup failed"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m|--message)     message="$2";     shift 2 ;;
            -s|--style)       style="$2";       shift 2 ;;
            -sm|--success_msg) success_msg="$2"; shift 2 ;;
            -e|--error_msg)   error_msg="$2";   shift 2 ;;
            *)
                error "clean: unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &>/dev/null; then
            warn "Not running as root. Package cleanup may fail without elevated privileges."
        else
            warn "Not running as root and 'sudo' is not available. Package cleanup may fail."
        fi
    fi

    if command -v apt &> /dev/null; then
        _clean_apt &
    elif command -v dnf &> /dev/null; then
        _clean_dnf &
    elif command -v yum &> /dev/null; then
        _clean_yum &
    elif command -v zypper &> /dev/null; then
        _clean_zypper &
    elif command -v pacman &> /dev/null; then
        _clean_pacman &
    elif command -v apk &> /dev/null; then
        _clean_apk &
    else
        error "Could not determine the primary package manager."
        error "Cannot proceed with cleaning process."
        return 1
    fi

    monitor $! \
        --style "$style" \
        --message "$message" \
        --success_msg "$success_msg" \
        --error_msg "$error_msg"
}

# Function: _clean_apt
# Description: Removes unused APT dependencies and cleans the package cache.
#
# Arguments:
#   None
#
# Globals:
#   VERBOSE_FILE (write): Raw apt output is appended here.
#
# Returns:
#   0 - Cleanup completed successfully.
#   1 - apt autoremove or autoclean failed.
#
# Examples:
#   _clean_apt
_clean_apt() {
    apt autoremove -y >> "$VERBOSE_FILE" 2>&1 || return 1
    apt autoclean -y >> "$VERBOSE_FILE" 2>&1 || return 1
}

# Function: _clean_dnf
# Description: Removes unused DNF dependencies and cleans all DNF caches.
#
# Arguments:
#   None
#
# Globals:
#   VERBOSE_FILE (write): Raw dnf output is appended here.
#
# Returns:
#   0 - Cleanup completed successfully.
#   1 - dnf autoremove or dnf clean failed.
#
# Examples:
#   _clean_dnf
_clean_dnf() {
    dnf autoremove -y >> "$VERBOSE_FILE" 2>&1 || return 1
    dnf clean all >> "$VERBOSE_FILE" 2>&1 || return 1
}

# Function: _clean_yum
# Description: Cleans all YUM caches and optionally removes orphaned packages via package-cleanup.
#
# Arguments:
#   None
#
# Globals:
#   VERBOSE_FILE (write): Raw yum and package-cleanup output is appended here.
#
# Returns:
#   0 - Cleanup completed successfully.
#   1 - yum clean failed.
#
# Examples:
#   _clean_yum
_clean_yum() {
    yum clean all >> "$VERBOSE_FILE" 2>&1 || return 1
    if command -v package-cleanup &> /dev/null; then
        package-cleanup --orphans -y >> "$VERBOSE_FILE" 2>&1 || return 1
    fi
}

# Function: _clean_zypper
# Description: Cleans all Zypper package caches.
#
# Arguments:
#   None
#
# Globals:
#   VERBOSE_FILE (write): Raw zypper output is appended here.
#
# Returns:
#   0 - Cleanup completed successfully.
#   1 - zypper clean failed.
#
# Examples:
#   _clean_zypper
_clean_zypper() {
    zypper clean --all >> "$VERBOSE_FILE" 2>&1 || return 1
}

# Function: _clean_pacman
# Description: Removes orphaned Pacman packages and cleans the package cache.
#
# Arguments:
#   None
#
# Globals:
#   VERBOSE_FILE (write): Raw pacman output is appended here.
#
# Returns:
#   0 - Cleanup completed successfully.
#   1 - pacman orphan removal or cache clean failed.
#
# Examples:
#   _clean_pacman
_clean_pacman() {
    if pacman -Qtdq &> /dev/null; then
        pacman -Rns --noconfirm "$(pacman -Qtdq)" >> "$VERBOSE_FILE" 2>&1 || return 1
    fi
    pacman -Sc --noconfirm >> "$VERBOSE_FILE" 2>&1 || return 1
}

# Function: _clean_apk
# Description: Cleans the APK package cache.
#
# Arguments:
#   None
#
# Globals:
#   VERBOSE_FILE (write): Raw apk output is appended here.
#
# Returns:
#   0 - Cleanup completed successfully.
#   1 - apk cache clean failed.
#
# Examples:
#   _clean_apk
_clean_apk() {
    apk cache clean >> "$VERBOSE_FILE" 2>&1 || return 1
}
