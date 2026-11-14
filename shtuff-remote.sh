#!/usr/bin/env bash
# shtuff remote loader. Source this file; do not execute it.
#
#   source <(curl -fsSL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)
#
# On bash 3.2 (macOS) `source <(...)` does not work reliably; use instead:
#   eval "$(curl -fsSL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)"
#
# Detects the interpreter and OS, fetches src/manifest.txt, then fetches and
# evaluates the matching modules (see shtuff.sh for the variant rules).
#
# NOTE: This file is parsed by bash 3.2, zsh and BusyBox ash, so keep it POSIX.

# Base URL for scripts (no trailing slash). Change if this project has been forked.
SHTUFF_BASE_URL="${SHTUFF_BASE_URL:-https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main}"

if [ -n "${BASH_VERSION:-}" ]; then
    SHTUFF_INTERP=bash
elif [ -n "${ZSH_VERSION:-}" ]; then
    SHTUFF_INTERP=zsh
else
    SHTUFF_INTERP=ash
fi

case "$(uname -s 2>/dev/null)" in
    Darwin) SHTUFF_OS=mac ;;
    Linux)  SHTUFF_OS=linux ;;
    *)      SHTUFF_OS=unknown ;;
esac

IS_DRY_RUN=${IS_DRY_RUN:-false}

# Fetch helper: curl preferred, wget fallback. Fails on HTTP errors so an error
# page is never evaluated as code.
if command -v curl >/dev/null 2>&1; then
    _shtuff_fetch() { curl -fsSL "$1"; }
elif command -v wget >/dev/null 2>&1; then
    _shtuff_fetch() { wget -qO- "$1"; }
else
    echo "shtuff: curl or wget is required but neither was found." >&2
    echo "shtuff: Alpine: apk add curl ca-certificates" >&2
    return 1 2>/dev/null || exit 1
fi

_shtuff_manifest=$(_shtuff_fetch "${SHTUFF_BASE_URL}/src/manifest.txt") || {
    echo "shtuff: could not download ${SHTUFF_BASE_URL}/src/manifest.txt" >&2
    echo "shtuff: (BusyBox wget needs ca-certificates and ssl_client for HTTPS)" >&2
    return 1 2>/dev/null || exit 1
}

# Fetches module $1 (interpreter variant first) into _sl_code. Evaluation
# happens at top level (not inside a function) so `declare -r` constants in
# modules stay global.
_shtuff_fetch_module() {
    _sl_code=""
    for _sf_cand in "$1_${SHTUFF_INTERP}" \
                    "$( [ "$SHTUFF_INTERP" = zsh ] && echo "$1_ash" )" \
                    "$( [ "$SHTUFF_INTERP" = bash ] && echo "$1" )"; do
        [ -n "$_sf_cand" ] || continue
        if _sl_code=$(_shtuff_fetch "${SHTUFF_BASE_URL}/src/${_sf_cand}.sh" 2>/dev/null) && [ -n "$_sl_code" ]; then
            return 0
        fi
    done
    _sl_code=""
    return 1
}

SHTUFF_SKIPPED=""
_sl_list=$(printf '%s\n' "$_shtuff_manifest" | while IFS= read -r _l; do
    case "$_l" in
        ''|'#'*) ;;
        core/*|"${SHTUFF_OS}"/*) printf '%s\n' "$_l" ;;
    esac
done)
for _sl_mod in $_sl_list; do
    if _shtuff_fetch_module "$_sl_mod"; then
        eval "$_sl_code"
    else
        SHTUFF_SKIPPED="${SHTUFF_SKIPPED:+$SHTUFF_SKIPPED }$_sl_mod"
    fi
done

if [ -n "$SHTUFF_SKIPPED" ] && [ "$SHTUFF_INTERP" != bash ]; then
    echo "shtuff: running under ${SHTUFF_INTERP}; only logging is available." >&2
    echo "shtuff: install bash (Alpine: apk add bash) for the full library." >&2
fi
unset _shtuff_manifest _sl_code _sf_cand _sl_list _sl_mod
