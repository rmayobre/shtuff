#!/usr/bin/env sh

# Detect shell and resolve the directory of this file.
if [ -n "${BASH_VERSION:-}" ]; then
    SHTUFF_DIR=$(unset CDPATH && cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    _SHTUFF_SRC="${SHTUFF_DIR}/src/bash"
else
    SHTUFF_DIR=$(unset CDPATH && cd "$(dirname "$0")" && pwd)
    _SHTUFF_SRC="${SHTUFF_DIR}/src/ash"
fi

# When set to "true", all functions that support --dry-run will print the system
# calls they would execute instead of running them. Can be overridden per-call
# with --dry-run.
IS_DRY_RUN=${IS_DRY_RUN:-false}

# Globals
. "${_SHTUFF_SRC}/graphics/colors.sh"

# Logging
. "${_SHTUFF_SRC}/logging/log.sh"

# Graphical
. "${_SHTUFF_SRC}/graphics/draw_loading_indicator.sh"

# Package Management
. "${_SHTUFF_SRC}/packaging/clean.sh"
. "${_SHTUFF_SRC}/packaging/install.sh"
. "${_SHTUFF_SRC}/packaging/uninstall.sh"
. "${_SHTUFF_SRC}/packaging/update.sh"

# Systemd
. "${_SHTUFF_SRC}/systemd/service.sh"
. "${_SHTUFF_SRC}/systemd/timer.sh"

# Networking
. "${_SHTUFF_SRC}/networking/download.sh"
. "${_SHTUFF_SRC}/networking/check_port.sh"
. "${_SHTUFF_SRC}/networking/wait_for_port.sh"
. "${_SHTUFF_SRC}/networking/bridge.sh"
. "${_SHTUFF_SRC}/networking/forward.sh"
. "${_SHTUFF_SRC}/networking/network.sh"

# Utilities
. "${_SHTUFF_SRC}/utils/monitor.sh"
. "${_SHTUFF_SRC}/utils/stop.sh"
. "${_SHTUFF_SRC}/utils/progress.sh"
. "${_SHTUFF_SRC}/utils/copy.sh"
. "${_SHTUFF_SRC}/utils/move.sh"
. "${_SHTUFF_SRC}/utils/delete.sh"

# Forms
. "${_SHTUFF_SRC}/forms/question.sh"
. "${_SHTUFF_SRC}/forms/options.sh"
. "${_SHTUFF_SRC}/forms/confirm.sh"
