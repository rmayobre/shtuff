#!/usr/bin/env bash

# Function: uninstall
# Description: Detects the system's package manager and removes one or more installed packages.
#              Runs the package manager command in the background and displays a loading
#              indicator via monitor while the removal is in progress.
#
# Arguments:
#   $@ - packages (string, optional): Package names to remove, separated by spaces. At least
#        one package or --group is required.
#   --group NAME (string, optional, repeatable): Also remove the members of a group defined
#        with group, resolved to the names for this system's package manager. Members that
#        another defined group still lists are kept. On success the group's definition is
#        discarded, so a package shared by two groups is removed once both are uninstalled.
#   --force (flag, optional): Remove group members even if another group still lists them.
#   --message MSG (string, optional): Message shown during the loading indicator.
#   --style STYLE (string, optional, default: DEFAULT_LOADING_STYLE): Loading indicator style.
#   --success_msg MSG (string, optional): Message shown on successful completion.
#   --error_msg MSG (string, optional): Message shown on failure.
#
# Globals:
#   DEFAULT_LOADING_STYLE (read): Fallback loading indicator style.
#   VERBOSE_FILE (write): Raw package manager output is appended here.
#   SHTUFF_GROUPS (write): Group definitions; uninstalled groups are discarded.
#   _GROUP_RESOLVED (write): Scratch result of group resolution.
#
# Returns:
#   0 - All packages removed successfully, or nothing was left to remove.
#   1 - No packages specified, unknown option, unknown group, or no supported package manager found.
#
# Examples:
#   uninstall nginx
#   uninstall nodejs npm
#   uninstall --group webserver
#   uninstall nginx --message "Removing nginx" --success_msg "nginx removed"
uninstall() {
    local message=""
    local style="$DEFAULT_LOADING_STYLE"
    local success_msg=""
    local error_msg=""
    local force=false
    local -a packages=()
    local -a groups=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -g|--group)
                if [[ $# -lt 2 ]]; then
                    error "uninstall: $1 requires a value"
                    return 1
                fi
                groups+=("$2"); shift 2 ;;
            -f|--force)       force=true;       shift ;;
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

    local g p
    if [[ ${#groups[@]} -gt 0 ]]; then
        local -a members=()
        for g in "${groups[@]}"; do
            _group_resolve "$g" || return 1
            members+=("${_GROUP_RESOLVED[@]}")
        done

        if [[ "$force" == false ]]; then
            local -A held=()
            _group_resolve_others "${groups[@]}" || return 1
            for p in "${_GROUP_RESOLVED[@]}"; do
                held[$p]=1
            done
            for p in "${members[@]}"; do
                if [[ -n "${held[$p]+x}" ]]; then
                    warn "Keeping '$p': another group still requires it."
                else
                    packages+=("$p")
                fi
            done
        else
            packages+=("${members[@]}")
        fi

        if [[ ${#packages[@]} -eq 0 ]]; then
            warn "Nothing to remove for: ${groups[*]}"
            for g in "${groups[@]}"; do unset "SHTUFF_GROUPS[$g]"; done
            return 0
        fi
    fi

    if [[ ${#packages[@]} -eq 0 ]]; then
        error "Usage: uninstall <package1> [package2...] [--group NAME] [--force] [--message MSG] [--style STYLE]"
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
    local rc=$?

    if [[ $rc -eq 0 ]]; then
        for g in "${groups[@]}"; do unset "SHTUFF_GROUPS[$g]"; done
    fi
    return $rc
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
