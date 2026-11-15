#!/usr/bin/env bash
# shtuff entry point: core modules only.
# Source this file; do not execute it.
#
#   source ./shtuff-core.sh
#
# NOTE: This file is parsed by bash 3.2, zsh and BusyBox ash, so keep it POSIX.

SHTUFF_PLATFORMS="core"
if [ -z "${SHTUFF_DIR:-}" ]; then
    if [ -n "${BASH_VERSION:-}" ]; then
        SHTUFF_DIR=$(unset CDPATH && cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    elif [ -n "${ZSH_VERSION:-}" ]; then
        eval 'SHTUFF_DIR=$(unset CDPATH && cd "$(dirname "${(%):-%x}")" && pwd)'
    else
        # Plain ash cannot locate this file: preset SHTUFF_DIR or source from the project root.
        SHTUFF_DIR=$(pwd)
    fi
fi
. "${SHTUFF_DIR}/src/loader.sh"
