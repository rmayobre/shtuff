#!/usr/bin/env bash
# shtuff local loader. Source this file; do not execute it.
#
# Detects the running interpreter (bash, zsh, ash/POSIX sh) and OS (linux, mac),
# then sources the modules listed in src/manifest.txt: everything under core/
# plus the directory for the detected OS. Each module may ship per-interpreter
# variants (<name>_bash.sh, <name>_ash.sh, <name>_zsh.sh); the loader prefers
# the variant for the running shell, then the plain <name>.sh.
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

# --- Operating system --------------------------------------------------------
case "$(uname -s 2>/dev/null)" in
    Darwin) SHTUFF_OS=mac ;;
    Linux)  SHTUFF_OS=linux ;;
    *)      SHTUFF_OS=unknown ;;
esac

# --- Project directory -------------------------------------------------------
# bash and zsh can locate this file; plain ash cannot, so it must be preset
# (SHTUFF_DIR=/path/to/shtuff) or sourced from the project root.
if [ -z "${SHTUFF_DIR:-}" ]; then
    case "$SHTUFF_INTERP" in
        bash) SHTUFF_DIR=$(unset CDPATH && cd "$(dirname "${BASH_SOURCE[0]}")" && pwd) ;;
        zsh)  eval 'SHTUFF_DIR=$(unset CDPATH && cd "$(dirname "${(%):-%x}")" && pwd)' ;;
        *)    SHTUFF_DIR=$(pwd) ;;
    esac
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
        core/*|"${SHTUFF_OS}"/*)
            if _sl_file=$(_shtuff_resolve "$_sl_line"); then
                . "$_sl_file"
            else
                SHTUFF_SKIPPED="${SHTUFF_SKIPPED:+$SHTUFF_SKIPPED }$_sl_line"
            fi
            ;;
    esac
done < "${SHTUFF_DIR}/src/manifest.txt"

if [ -n "$SHTUFF_SKIPPED" ] && [ "$SHTUFF_INTERP" != bash ]; then
    echo "shtuff: running under ${SHTUFF_INTERP}; only logging is available." >&2
    echo "shtuff: install bash (Alpine: apk add bash) for the full library." >&2
fi
unset _sl_line _sl_file _sr_base _sr_cand
