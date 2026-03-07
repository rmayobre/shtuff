#!/usr/bin/env sh

# Detect shell and resolve the directory of this file.
if [ -n "${BASH_VERSION:-}" ]; then
    SHTUFF_DIR=$(unset CDPATH && cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    _SHTUFF_SRC="${SHTUFF_DIR}/src"
else
    SHTUFF_DIR=$(unset CDPATH && cd "$(dirname "$0")" && pwd)
    _SHTUFF_SRC="${SHTUFF_DIR}/ash"
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

# Containers
. "${_SHTUFF_SRC}/containers/lxc_config.sh"
. "${_SHTUFF_SRC}/containers/lxc_create.sh"
. "${_SHTUFF_SRC}/containers/lxc_delete.sh"
. "${_SHTUFF_SRC}/containers/lxc_enter.sh"
. "${_SHTUFF_SRC}/containers/lxc_exec.sh"
. "${_SHTUFF_SRC}/containers/lxc_push.sh"
. "${_SHTUFF_SRC}/containers/lxc_pull.sh"
. "${_SHTUFF_SRC}/containers/lxc_start.sh"
. "${_SHTUFF_SRC}/containers/pct_config.sh"
. "${_SHTUFF_SRC}/containers/pct_create.sh"
. "${_SHTUFF_SRC}/containers/pct_delete.sh"
. "${_SHTUFF_SRC}/containers/pct_enter.sh"
. "${_SHTUFF_SRC}/containers/pct_exec.sh"
. "${_SHTUFF_SRC}/containers/pct_push.sh"
. "${_SHTUFF_SRC}/containers/pct_pull.sh"
. "${_SHTUFF_SRC}/containers/pct_start.sh"
. "${_SHTUFF_SRC}/containers/pct_next_vmid.sh"
. "${_SHTUFF_SRC}/containers/lxc_network.sh"
. "${_SHTUFF_SRC}/containers/pct_network.sh"
. "${_SHTUFF_SRC}/containers/container.sh"
