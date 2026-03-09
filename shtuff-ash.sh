#!/bin/sh

# Current directory path of this project.
SHTUFF_DIR=$(unset CDPATH && cd "$(dirname "$0")" && pwd)

# When set to "true", all functions that support --dry-run will print the system
# calls they would execute instead of running them. Can be overridden per-call
# with --dry-run.
IS_DRY_RUN=${IS_DRY_RUN:-false}

# Globals
. "${SHTUFF_DIR}/ash/graphics/colors.sh"

# Logging
. "${SHTUFF_DIR}/ash/logging/log.sh"

# Graphical
. "${SHTUFF_DIR}/ash/graphics/draw_loading_indicator.sh"

# Package Management
. "${SHTUFF_DIR}/ash/packaging/clean.sh"
. "${SHTUFF_DIR}/ash/packaging/install.sh"
. "${SHTUFF_DIR}/ash/packaging/uninstall.sh"
. "${SHTUFF_DIR}/ash/packaging/update.sh"

# Systemd
. "${SHTUFF_DIR}/ash/systemd/service.sh"
. "${SHTUFF_DIR}/ash/systemd/timer.sh"

# Networking
. "${SHTUFF_DIR}/ash/networking/download.sh"
. "${SHTUFF_DIR}/ash/networking/check_port.sh"
. "${SHTUFF_DIR}/ash/networking/wait_for_port.sh"
. "${SHTUFF_DIR}/ash/networking/bridge.sh"
. "${SHTUFF_DIR}/ash/networking/forward.sh"
. "${SHTUFF_DIR}/ash/networking/network.sh"

# Utilities
. "${SHTUFF_DIR}/ash/utils/monitor.sh"
. "${SHTUFF_DIR}/ash/utils/stop.sh"
. "${SHTUFF_DIR}/ash/utils/progress.sh"
. "${SHTUFF_DIR}/ash/utils/copy.sh"
. "${SHTUFF_DIR}/ash/utils/move.sh"
. "${SHTUFF_DIR}/ash/utils/delete.sh"

# Forms
. "${SHTUFF_DIR}/ash/forms/question.sh"
. "${SHTUFF_DIR}/ash/forms/options.sh"
. "${SHTUFF_DIR}/ash/forms/confirm.sh"
