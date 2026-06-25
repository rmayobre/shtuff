#!/usr/bin/env bash

# Function: uninstall
# Description: Detects the system's package manager and removes one or more installed packages.
#              Runs the package manager command in the background and displays a loading
#              indicator via monitor while the removal is in progress.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to remove, separated by spaces.
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
#   0 - All packages removed successfully.
#   1 - No packages specified, unknown option, or no supported package manager found.
#
# Examples:
#   uninstall nginx
#   uninstall nodejs npm
#   uninstall nginx --message "Removing nginx" --success_msg "nginx removed"
uninstall() {
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
                error "uninstall: unknown option: $1"
                return 1
                ;;
            *)
                packages+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#packages[@]} -eq 0 ]]; then
        error "Usage: uninstall <package1> [package2...] [--message MSG] [--style STYLE]"
        return 1
    fi

    [[ -z "$message" ]] && message="Uninstalling ${packages[*]}"
    [[ -z "$success_msg" ]] && success_msg="Packages removed"
    [[ -z "$error_msg" ]] && error_msg="Failed to remove packages"

    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &>/dev/null; then
            warn "Not running as root. Package removal may fail without elevated privileges."
        else
            warn "Not running as root and 'sudo' is not available. Package removal may fail."
        fi
    fi

    if command -v apt &> /dev/null; then
        _uninstall_apt "${packages[@]}" &
    elif command -v dnf &> /dev/null; then
        _uninstall_dnf "${packages[@]}" &
    elif command -v yum &> /dev/null; then
        _uninstall_yum "${packages[@]}" &
    elif command -v zypper &> /dev/null; then
        _uninstall_zypper "${packages[@]}" &
    elif command -v pacman &> /dev/null; then
        _uninstall_pacman "${packages[@]}" &
    elif command -v apk &> /dev/null; then
        _uninstall_apk "${packages[@]}" &
    else
        error "Could not determine the primary package manager."
        error "Cannot proceed with dependency removal."
        return 1
    fi

    monitor $! \
        --style "$style" \
        --message "$message" \
        --success_msg "$success_msg" \
        --error_msg "$error_msg"
}

# Function: _uninstall_apt
# Description: Removes one or more packages using APT.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to remove.
#
# Globals:
#   VERBOSE_FILE (write): Raw apt output is appended here.
#
# Returns:
#   0 - All packages removed successfully.
#   1 - apt remove failed.
#
# Examples:
#   _uninstall_apt nginx
_uninstall_apt() {
    apt remove -y "$@" >> "$VERBOSE_FILE" 2>&1
}

# Function: _uninstall_dnf
# Description: Removes one or more packages using DNF.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to remove.
#
# Globals:
#   VERBOSE_FILE (write): Raw dnf output is appended here.
#
# Returns:
#   0 - All packages removed successfully.
#   1 - dnf remove failed.
#
# Examples:
#   _uninstall_dnf nginx
_uninstall_dnf() {
    dnf remove -y "$@" >> "$VERBOSE_FILE" 2>&1
}

# Function: _uninstall_yum
# Description: Removes one or more packages using YUM.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to remove.
#
# Globals:
#   VERBOSE_FILE (write): Raw yum output is appended here.
#
# Returns:
#   0 - All packages removed successfully.
#   1 - yum remove failed.
#
# Examples:
#   _uninstall_yum nginx
_uninstall_yum() {
    yum remove -y "$@" >> "$VERBOSE_FILE" 2>&1
}

# Function: _uninstall_zypper
# Description: Removes one or more packages using Zypper in non-interactive mode.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to remove.
#
# Globals:
#   VERBOSE_FILE (write): Raw zypper output is appended here.
#
# Returns:
#   0 - All packages removed successfully.
#   1 - zypper remove failed.
#
# Examples:
#   _uninstall_zypper nginx
_uninstall_zypper() {
    zypper --non-interactive remove "$@" >> "$VERBOSE_FILE" 2>&1
}

# Function: _uninstall_pacman
# Description: Removes one or more packages and their unique dependencies using Pacman.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to remove.
#
# Globals:
#   VERBOSE_FILE (write): Raw pacman output is appended here.
#
# Returns:
#   0 - All packages removed successfully.
#   1 - pacman remove failed.
#
# Examples:
#   _uninstall_pacman nginx
_uninstall_pacman() {
    pacman -Rs --noconfirm "$@" >> "$VERBOSE_FILE" 2>&1
}

# Function: _uninstall_apk
# Description: Removes one or more packages using APK.
#
# Arguments:
#   $@ - packages (string, required): One or more package names to remove.
#
# Globals:
#   VERBOSE_FILE (write): Raw apk output is appended here.
#
# Returns:
#   0 - All packages removed successfully.
#   1 - apk del failed.
#
# Examples:
#   _uninstall_apk nginx
_uninstall_apk() {
    apk del "$@" >> "$VERBOSE_FILE" 2>&1
}
