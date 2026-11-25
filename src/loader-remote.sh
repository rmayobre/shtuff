# shtuff shared remote loader. Fetched and evaluated by shtuff-core-remote.sh and
# shtuff-linux-remote.sh; do not source it directly.
#
# Inputs (set by the entry point):
#   SHTUFF_BASE_URL   Raw URL of the repository root, no trailing slash.
#   SHTUFF_PLATFORMS  Space-separated module directories to load, e.g. "core linux".
#   _shtuff_fetch     Function printing the body of a URL (curl or wget).
#
# Fetches src/manifest.txt, then fetches and evaluates each module whose first
# path component is in SHTUFF_PLATFORMS (see loader.sh for the variant rules).
#
# NOTE: This file is parsed by bash 3.2, zsh and BusyBox ash, so keep it POSIX.

# --- Interpreter -------------------------------------------------------------
if [ -n "${BASH_VERSION:-}" ]; then
    SHTUFF_INTERP=bash
elif [ -n "${ZSH_VERSION:-}" ]; then
    SHTUFF_INTERP=zsh
else
    SHTUFF_INTERP=ash
fi

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
                    "$1_posix" \
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
        */*)
            case " ${SHTUFF_PLATFORMS} " in
                *" ${_l%%/*} "*) printf '%s\n' "$_l" ;;
            esac
            ;;
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
    echo "shtuff: running under ${SHTUFF_INTERP}; modules that still need bash were skipped." >&2
    echo "shtuff: install bash (Alpine: apk add bash) for the full library." >&2
fi
unset _shtuff_manifest _sl_code _sf_cand _sl_list _sl_mod
