#!/usr/bin/env bash
# shtuff remote entry point: core plus Linux modules.
# Source this file; do not execute it.
#
#   source <(curl -fsSL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-linux-remote.sh)
#   source <(wget -qO- https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-linux-remote.sh)
#
# On bash 3.2 (macOS) `source <(...)` does not work reliably; use instead:
#   eval "$(curl -fsSL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-linux-remote.sh)"
#
# NOTE: This file is parsed by bash 3.2, zsh and BusyBox ash, so keep it POSIX.

# Base URL of the repository root (no trailing slash). Change if this project has been forked.
SHTUFF_BASE_URL="${SHTUFF_BASE_URL:-https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main}"
SHTUFF_PLATFORMS="core linux"

# Fetch helper: curl preferred, wget fallback. -f makes HTTP errors fail so an
# error page is never evaluated as code.
if command -v curl >/dev/null 2>&1; then
    _shtuff_fetch() { curl -fsSL "$1"; }
elif command -v wget >/dev/null 2>&1; then
    _shtuff_fetch() { wget -qO- "$1"; }
else
    echo "shtuff: curl or wget is required but neither was found." >&2
    echo "shtuff: Alpine: apk add curl ca-certificates" >&2
    return 1 2>/dev/null || exit 1
fi

_shtuff_loader=$(_shtuff_fetch "${SHTUFF_BASE_URL}/src/loader-remote.sh") || {
    echo "shtuff: could not download ${SHTUFF_BASE_URL}/src/loader-remote.sh" >&2
    echo "shtuff: (BusyBox wget needs ca-certificates and ssl_client for HTTPS)" >&2
    return 1 2>/dev/null || exit 1
}
eval "$_shtuff_loader"
unset _shtuff_loader
