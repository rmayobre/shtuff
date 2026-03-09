#!/bin/sh

# Current directory path of this project.
SHTUFF_DIR=$(unset CDPATH && cd "$(dirname "$0")" && pwd)

# When set to "true", all functions that support --dry-run will print the system
# calls they would execute instead of running them. Can be overridden per-call
# with --dry-run.
IS_DRY_RUN=${IS_DRY_RUN:-false}

# Globals
. "${SHTUFF_DIR}/src/ash/graphics/colors.sh"

# Logging
. "${SHTUFF_DIR}/src/ash/logging/log.sh"

# Graphical
. "${SHTUFF_DIR}/src/ash/graphics/draw_loading_indicator.sh"

# Package Management
. "${SHTUFF_DIR}/src/ash/packaging/clean.sh"
. "${SHTUFF_DIR}/src/ash/packaging/install.sh"
. "${SHTUFF_DIR}/src/ash/packaging/uninstall.sh"
. "${SHTUFF_DIR}/src/ash/packaging/update.sh"

# Systemd
. "${SHTUFF_DIR}/src/ash/systemd/service.sh"
. "${SHTUFF_DIR}/src/ash/systemd/timer.sh"

# Networking
. "${SHTUFF_DIR}/src/ash/networking/download.sh"
. "${SHTUFF_DIR}/src/ash/networking/check_port.sh"
. "${SHTUFF_DIR}/src/ash/networking/wait_for_port.sh"
. "${SHTUFF_DIR}/src/ash/networking/bridge.sh"
. "${SHTUFF_DIR}/src/ash/networking/forward.sh"
. "${SHTUFF_DIR}/src/ash/networking/network.sh"

# Utilities
. "${SHTUFF_DIR}/src/ash/utils/monitor.sh"
. "${SHTUFF_DIR}/src/ash/utils/stop.sh"
. "${SHTUFF_DIR}/src/ash/utils/progress.sh"
. "${SHTUFF_DIR}/src/ash/utils/copy.sh"
. "${SHTUFF_DIR}/src/ash/utils/move.sh"
. "${SHTUFF_DIR}/src/ash/utils/delete.sh"

# Forms
. "${SHTUFF_DIR}/src/ash/forms/question.sh"
. "${SHTUFF_DIR}/src/ash/forms/options.sh"
. "${SHTUFF_DIR}/src/ash/forms/confirm.sh"
