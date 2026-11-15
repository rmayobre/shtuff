# Homebrew helpers shared by install/update/uninstall/clean.
# Homebrew runs on macOS and Linux, so it lives in core/ rather than mac/.

# Function: _brew
# Description: Runs a brew command, dropping privileges when called as root because
#              Homebrew refuses to run as root.
#
# Arguments:
#   $@ - brew arguments (string, required): Passed through to brew unchanged.
#
# Globals:
#   SUDO_USER (read): Preferred non-root user to run brew as when invoked via sudo.
#
# Returns:
#   0 - brew command succeeded.
#   1 - brew not found, no non-root owner could be determined, or the command failed.
#
# Examples:
#   _brew install jq
_brew() {
    local brew_bin
    brew_bin="$(command -v brew)" || { error "Homebrew (brew) was not found."; return 1; }

    if [[ $EUID -ne 0 ]]; then
        "$brew_bin" "$@"
        return $?
    fi

    local owner="${SUDO_USER:-}"
    if [[ -z "$owner" || "$owner" == "root" ]]; then
        owner="$(ls -ld "$brew_bin" 2>/dev/null | awk '{print $3}')"
    fi
    if [[ -z "$owner" || "$owner" == "root" ]]; then
        error "Homebrew cannot run as root and no non-root owner was found. Re-run as a normal user."
        return 1
    fi
    sudo -u "$owner" "$brew_bin" "$@"
}
