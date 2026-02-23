#!/usr/bin/env bash

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
source "${SHTUFF_DIR}/src/utils/monitor.sh"
source "${SHTUFF_DIR}/src/utils/stop.sh"
source "${SHTUFF_DIR}/src/utils/copy.sh"
source "${SHTUFF_DIR}/src/utils/move.sh"
source "${SHTUFF_DIR}/src/utils/delete.sh"

# Containers
source "${SHTUFF_DIR}/src/containers/lxc_create.sh"
source "${SHTUFF_DIR}/src/containers/lxc_enter.sh"
source "${SHTUFF_DIR}/src/containers/lxc_push.sh"
source "${SHTUFF_DIR}/src/containers/lxc_pull.sh"
source "${SHTUFF_DIR}/src/containers/docker_create.sh"
source "${SHTUFF_DIR}/src/containers/docker_enter.sh"
source "${SHTUFF_DIR}/src/containers/docker_push.sh"
source "${SHTUFF_DIR}/src/containers/docker_pull.sh"
source "${SHTUFF_DIR}/src/containers/podman_create.sh"
source "${SHTUFF_DIR}/src/containers/podman_enter.sh"
source "${SHTUFF_DIR}/src/containers/podman_push.sh"
source "${SHTUFF_DIR}/src/containers/podman_pull.sh"
source "${SHTUFF_DIR}/src/containers/pct_create.sh"
source "${SHTUFF_DIR}/src/containers/pct_enter.sh"
source "${SHTUFF_DIR}/src/containers/pct_push.sh"
source "${SHTUFF_DIR}/src/containers/pct_pull.sh"

timer -h
