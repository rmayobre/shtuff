#!/bin/sh

# Base URL for scripts. Change if this project has been forked.
BASE_URL="https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/"

# When set to "true", all functions that support --dry-run will print the system
# calls they would execute instead of running them. Can be overridden per-call
# with --dry-run.
IS_DRY_RUN=${IS_DRY_RUN:-false}

# Helper: download a remote file to a temp path and source it.
_ash_source_url() {
    _ast=$(mktemp)
    curl -sL "$1" > "$_ast"
    . "$_ast"
    rm -f "$_ast"
}

# Globals
_ash_source_url "${BASE_URL}/ash/graphics/colors.sh"

# Logging
_ash_source_url "${BASE_URL}/ash/logging/log.sh"

# Graphical
_ash_source_url "${BASE_URL}/ash/graphics/draw_loading_indicator.sh"

# Package Management
_ash_source_url "${BASE_URL}/ash/packaging/clean.sh"
_ash_source_url "${BASE_URL}/ash/packaging/install.sh"
_ash_source_url "${BASE_URL}/ash/packaging/uninstall.sh"
_ash_source_url "${BASE_URL}/ash/packaging/update.sh"

# Systemd
_ash_source_url "${BASE_URL}/ash/systemd/service.sh"
_ash_source_url "${BASE_URL}/ash/systemd/timer.sh"

# Networking
_ash_source_url "${BASE_URL}/ash/networking/download.sh"
_ash_source_url "${BASE_URL}/ash/networking/check_port.sh"
_ash_source_url "${BASE_URL}/ash/networking/wait_for_port.sh"
_ash_source_url "${BASE_URL}/ash/networking/bridge.sh"
_ash_source_url "${BASE_URL}/ash/networking/forward.sh"
_ash_source_url "${BASE_URL}/ash/networking/network.sh"

# Utilities
_ash_source_url "${BASE_URL}/ash/utils/monitor.sh"
_ash_source_url "${BASE_URL}/ash/utils/stop.sh"
_ash_source_url "${BASE_URL}/ash/utils/progress.sh"
_ash_source_url "${BASE_URL}/ash/utils/copy.sh"
_ash_source_url "${BASE_URL}/ash/utils/move.sh"
_ash_source_url "${BASE_URL}/ash/utils/delete.sh"

# Forms
_ash_source_url "${BASE_URL}/ash/forms/question.sh"
_ash_source_url "${BASE_URL}/ash/forms/options.sh"
_ash_source_url "${BASE_URL}/ash/forms/confirm.sh"

# Containers
_ash_source_url "${BASE_URL}/ash/containers/lxc_config.sh"
_ash_source_url "${BASE_URL}/ash/containers/lxc_create.sh"
_ash_source_url "${BASE_URL}/ash/containers/lxc_delete.sh"
_ash_source_url "${BASE_URL}/ash/containers/lxc_enter.sh"
_ash_source_url "${BASE_URL}/ash/containers/lxc_exec.sh"
_ash_source_url "${BASE_URL}/ash/containers/lxc_push.sh"
_ash_source_url "${BASE_URL}/ash/containers/lxc_pull.sh"
_ash_source_url "${BASE_URL}/ash/containers/lxc_start.sh"
_ash_source_url "${BASE_URL}/ash/containers/pct_config.sh"
_ash_source_url "${BASE_URL}/ash/containers/pct_create.sh"
_ash_source_url "${BASE_URL}/ash/containers/pct_delete.sh"
_ash_source_url "${BASE_URL}/ash/containers/pct_enter.sh"
_ash_source_url "${BASE_URL}/ash/containers/pct_exec.sh"
_ash_source_url "${BASE_URL}/ash/containers/pct_push.sh"
_ash_source_url "${BASE_URL}/ash/containers/pct_pull.sh"
_ash_source_url "${BASE_URL}/ash/containers/pct_start.sh"
_ash_source_url "${BASE_URL}/ash/containers/pct_next_vmid.sh"
_ash_source_url "${BASE_URL}/ash/containers/lxc_network.sh"
_ash_source_url "${BASE_URL}/ash/containers/pct_network.sh"
_ash_source_url "${BASE_URL}/ash/containers/container.sh"
