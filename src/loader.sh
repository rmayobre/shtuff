# shtuff shared local loader. Sourced by shtuff-core.sh and shtuff-linux.sh;
# do not source it directly.
#
# Inputs (set by the entry point):
#   SHTUFF_DIR        Project root (directory holding src/).
#   SHTUFF_PLATFORMS  Space-separated module directories to load, e.g. "core linux".
#
# Detects the running interpreter (bash, zsh, ash/POSIX sh), then sources the
# modules listed in src/manifest.txt whose first path component is in
# SHTUFF_PLATFORMS. Each module may ship per-interpreter variants
# (<name>_bash.sh, <name>_ash.sh, <name>_zsh.sh); the loader prefers the variant
# for the running shell, then the plain <name>.sh (bash only).
#
# NOTE: This file is parsed by bash 3.2, zsh and BusyBox ash, so keep it POSIX.

# --- Interpreter -------------------------------------------------------------
if [ -n "${BASH_VERSION:-}" ]; then
    SHTUFF_INTERP=bash
    if [ "${BASH_VERSINFO:-0}" -lt 3 ]; then
        echo "shtuff: bash 3.2 or newer is required." >&2
        return 1 2>/dev/null || exit 1
    fi
elif [ -n "${ZSH_VERSION:-}" ]; then
    SHTUFF_INTERP=zsh
else
    SHTUFF_INTERP=ash
fi

# --- Project directory -------------------------------------------------------
if [ -z "${SHTUFF_DIR:-}" ] || [ -z "${SHTUFF_PLATFORMS:-}" ]; then
    echo "shtuff: source shtuff-core.sh or shtuff-linux.sh instead of the loader." >&2
    return 1 2>/dev/null || exit 1
fi
if [ ! -f "${SHTUFF_DIR}/src/manifest.txt" ]; then
    echo "shtuff: cannot find src/manifest.txt under '${SHTUFF_DIR}'. Set SHTUFF_DIR." >&2
    return 1 2>/dev/null || exit 1
fi

# When set to "true", all functions that support --dry-run will print the system
# calls they would execute instead of running them. Can be overridden per-call
# with --dry-run.
IS_DRY_RUN=${IS_DRY_RUN:-false}

# Prints the file to source for module $1, preferring the interpreter variant.
# Modules without a variant are written in bash, so none is returned under ash
# and zsh. Sourcing happens at top level (not inside a function) so `declare -r`
# constants in modules stay global.
_shtuff_resolve() {
    _sr_base="${SHTUFF_DIR}/src/$1"
    for _sr_cand in "${_sr_base}_${SHTUFF_INTERP}.sh" \
                    "$( [ "$SHTUFF_INTERP" = zsh ] && echo "${_sr_base}_ash.sh" )" \
                    "$( [ "$SHTUFF_INTERP" = bash ] && echo "${_sr_base}.sh" )"; do
        if [ -n "$_sr_cand" ] && [ -f "$_sr_cand" ]; then
            printf '%s\n' "$_sr_cand"
            return 0
        fi
    done
    return 1
}

SHTUFF_SKIPPED=""
while IFS= read -r _sl_line || [ -n "$_sl_line" ]; do
    case "$_sl_line" in
        ''|'#'*) continue ;;
        */*)
          case " ${SHTUFF_PLATFORMS} " in
            *" ${_sl_line%%/*} "*)
            if _sl_file=$(_shtuff_resolve "$_sl_line"); then
                . "$_sl_file"
            else
                SHTUFF_SKIPPED="${SHTUFF_SKIPPED:+$SHTUFF_SKIPPED }$_sl_line"
            fi
            ;;
          esac
          ;;
    esac
done < "${SHTUFF_DIR}/src/manifest.txt"

if [ -n "$SHTUFF_SKIPPED" ] && [ "$SHTUFF_INTERP" != bash ]; then
    echo "shtuff: running under ${SHTUFF_INTERP}; only logging is available." >&2
    echo "shtuff: install bash (Alpine: apk add bash) for the full library." >&2
fi
unset _sl_line _sl_file _sr_base _sr_cand
