#!/usr/bin/env bash

# Function: install
# Description: Detects the system's package manager and installs one or more packages.
#              Runs the package manager command in the background and displays a loading
#              indicator via monitor while the installation is in progress.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to install, separated by spaces.
#   --message MSG (string, optional): Message shown during the loading indicator.
#   --style STYLE (string, optional, default: DEFAULT_LOADING_STYLE): Loading indicator style.
#   --success_msg MSG (string, optional): Message shown on successful completion.
#   --error_msg MSG (string, optional): Message shown on failure.
#
# Globals:
#   DEFAULT_LOADING_STYLE (read): Fallback loading indicator style.
#   VERBOSE_FILE (write): Raw package manager output is appended here.
#
# Returns:
#   0 - All packages installed successfully.
#   1 - No packages specified, unknown option, or no supported package manager found.
#
# Examples:
#   install curl
#   install nodejs npm unzip
#   install nodejs npm --message "Installing Node.js" --success_msg "Node.js installed"
install() {
    local message=""
    local style="$DEFAULT_LOADING_STYLE"
    local success_msg=""
    local error_msg=""
    local -a packages=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m|--message)     message="$2";     shift 2 ;;
            -s|--style)       style="$2";       shift 2 ;;
            -sm|--success_msg) success_msg="$2"; shift 2 ;;
            -e|--error_msg)   error_msg="$2";   shift 2 ;;
            -*)
                error "install: unknown option: $1"
                return 1
                ;;
            *)
                packages+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#packages[@]} -eq 0 ]]; then
        error "Usage: install <package1> [package2...] [--message MSG] [--style STYLE]"
        return 1
    fi

    [[ -z "$message" ]] && message="Installing ${packages[*]}"
    [[ -z "$success_msg" ]] && success_msg="Packages installed"
    [[ -z "$error_msg" ]] && error_msg="Failed to install packages"

    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &>/dev/null; then
            warn "Not running as root. Package installation may fail without elevated privileges."
        else
            warn "Not running as root and 'sudo' is not available. Package installation may fail."
        fi
    fi

    if command -v apt &> /dev/null; then
        _install_apt "${packages[@]}" &
    elif command -v dnf &> /dev/null; then
        _install_dnf "${packages[@]}" &
    elif command -v yum &> /dev/null; then
        _install_yum "${packages[@]}" &
    elif command -v zypper &> /dev/null; then
        _install_zypper "${packages[@]}" &
    elif command -v pacman &> /dev/null; then
        _install_pacman "${packages[@]}" &
    elif command -v apk &> /dev/null; then
        _install_apk "${packages[@]}" &
    else
        error "Could not determine the primary package manager."
        error "Cannot proceed with installation."
        return 1
    fi

    monitor $! \
        --style "$style" \
        --message "$message" \
        --success_msg "$success_msg" \
        --error_msg "$error_msg"
}

# Function: _install_apt
# Description: Installs one or more packages using APT after refreshing the package lists.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to install.
#
# Globals:
#   VERBOSE_FILE (write): Raw apt output is appended here.
#
# Returns:
#   0 - All packages installed successfully.
#   1 - apt update or apt install failed.
#
# Examples:
#   _install_apt curl git
_install_apt() {
    apt update >> "$VERBOSE_FILE" 2>&1
    apt install -y "$@" >> "$VERBOSE_FILE" 2>&1
}

# Function: _install_dnf
# Description: Installs one or more packages using DNF.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to install.
#
# Globals:
#   VERBOSE_FILE (write): Raw dnf output is appended here.
#
# Returns:
#   0 - All packages installed successfully.
#   1 - dnf install failed.
#
# Examples:
#   _install_dnf curl git
_install_dnf() {
    dnf install -y "$@" >> "$VERBOSE_FILE" 2>&1
}

# Function: _install_yum
# Description: Installs one or more packages using YUM.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to install.
#
# Globals:
#   VERBOSE_FILE (write): Raw yum output is appended here.
#
# Returns:
#   0 - All packages installed successfully.
#   1 - yum install failed.
#
# Examples:
#   _install_yum curl git
_install_yum() {
    yum install -y "$@" >> "$VERBOSE_FILE" 2>&1
}

# Function: _install_zypper
# Description: Installs one or more packages using Zypper in non-interactive mode.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to install.
#
# Globals:
#   VERBOSE_FILE (write): Raw zypper output is appended here.
#
# Returns:
#   0 - All packages installed successfully.
#   1 - zypper install failed.
#
# Examples:
#   _install_zypper curl git
_install_zypper() {
    zypper --non-interactive install "$@" >> "$VERBOSE_FILE" 2>&1
}

# Function: _install_pacman
# Description: Installs one or more packages using Pacman, syncing the database first.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to install.
#
# Globals:
#   VERBOSE_FILE (write): Raw pacman output is appended here.
#
# Returns:
#   0 - All packages installed successfully.
#   1 - pacman install failed.
#
# Examples:
#   _install_pacman curl git
_install_pacman() {
    pacman -Sy --noconfirm "$@" >> "$VERBOSE_FILE" 2>&1
}

# Function: _install_apk
# Description: Installs one or more packages using APK.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to install.
#
# Globals:
#   VERBOSE_FILE (write): Raw apk output is appended here.
#
# Returns:
#   0 - All packages installed successfully.
#   1 - apk add failed.
#
# Examples:
#   _install_apk curl git
_install_apk() {
    apk add "$@" >> "$VERBOSE_FILE" 2>&1
}
