#!/usr/bin/env bash

# Function: _require_systemd
# Description: Verifies that systemd is available, printing an error that names the calling function
#              and, on OpenRC systems such as Alpine, says that OpenRC is not supported yet.
#
# Arguments:
#   $1 - caller (string, optional, default: "This function"): Name shown in the error message.
#
# Returns:
#   0 - systemctl was found.
#   1 - systemd is not available on this system.
#
# Examples:
#   _require_systemd "service" || return 1
_require_systemd() {
    local caller="${1:-This function}"

    if command -v systemctl >/dev/null 2>&1; then
        return 0
    fi

    error "${caller} requires systemd, but 'systemctl' was not found on this system."
    if command -v rc-service >/dev/null 2>&1 || [[ -x /sbin/openrc ]]; then
        error "OpenRC was detected (Alpine and similar). OpenRC is not supported yet; use systemd or manage the service with rc-service."
    fi
    return 1
}
