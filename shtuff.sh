#!/usr/bin/env bash

# Version of this shtuff release. Replaced by the release workflow for tagged builds.
SHTUFF_VERSION="dev"

# Current directory path of this project.
SHTUFF_DIR=$(unset CDPATH && cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Globals
source "${SHTUFF_DIR}/src/graphics/colors.sh"

# Logging
source "${SHTUFF_DIR}/src/logging/log.sh"

# Graphical
source "${SHTUFF_DIR}/src/graphics/draw_loading_indicator.sh"

# Package Managament
source "${SHTUFF_DIR}/src/packaging/clean.sh"
source "${SHTUFF_DIR}/src/packaging/install.sh"
source "${SHTUFF_DIR}/src/packaging/uninstall.sh"
source "${SHTUFF_DIR}/src/packaging/update.sh"

# Systemd
source "${SHTUFF_DIR}/src/systemd/service.sh"
source "${SHTUFF_DIR}/src/systemd/timer.sh"

# Utilities
source "${SHTUFF_DIR}/src/utils/copy.sh"
source "${SHTUFF_DIR}/src/utils/delete.sh"
source "${SHTUFF_DIR}/src/utils/monitor.sh"
source "${SHTUFF_DIR}/src/utils/move.sh"
source "${SHTUFF_DIR}/src/utils/progress.sh"
source "${SHTUFF_DIR}/src/utils/stop.sh"
source "${SHTUFF_DIR}/src/utils/copy.sh"
source "${SHTUFF_DIR}/src/utils/move.sh"
source "${SHTUFF_DIR}/src/utils/delete.sh"

# Containers
source "${SHTUFF_DIR}/src/containers/lxc_config.sh"
source "${SHTUFF_DIR}/src/containers/lxc_create.sh"
source "${SHTUFF_DIR}/src/containers/lxc_delete.sh"
source "${SHTUFF_DIR}/src/containers/lxc_enter.sh"
source "${SHTUFF_DIR}/src/containers/lxc_exec.sh"
source "${SHTUFF_DIR}/src/containers/lxc_push.sh"
source "${SHTUFF_DIR}/src/containers/lxc_pull.sh"
source "${SHTUFF_DIR}/src/containers/lxc_start.sh"
source "${SHTUFF_DIR}/src/containers/pct_config.sh"
source "${SHTUFF_DIR}/src/containers/pct_create.sh"
source "${SHTUFF_DIR}/src/containers/pct_delete.sh"
source "${SHTUFF_DIR}/src/containers/pct_enter.sh"
source "${SHTUFF_DIR}/src/containers/pct_exec.sh"
source "${SHTUFF_DIR}/src/containers/pct_push.sh"
source "${SHTUFF_DIR}/src/containers/pct_pull.sh"
source "${SHTUFF_DIR}/src/containers/pct_start.sh"
source "${SHTUFF_DIR}/src/containers/container.sh"
