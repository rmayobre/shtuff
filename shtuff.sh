#!/usr/bin/env bash

# Current directory path of this project.
SHTUFF_DIR=$(unset CDPATH && cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# When set to "true", all functions that support --dry-run will print the system
# calls they would execute instead of running them. Can be overridden per-call
# with --dry-run.
IS_DRY_RUN=${IS_DRY_RUN:-false}

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

# Networking
source "${SHTUFF_DIR}/src/networking/download.sh"
source "${SHTUFF_DIR}/src/networking/check_port.sh"
source "${SHTUFF_DIR}/src/networking/wait_for_port.sh"
source "${SHTUFF_DIR}/src/networking/bridge.sh"
source "${SHTUFF_DIR}/src/networking/forward.sh"
source "${SHTUFF_DIR}/src/networking/network.sh"

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

# Forms
source "${SHTUFF_DIR}/src/forms/question.sh"
source "${SHTUFF_DIR}/src/forms/options.sh"
source "${SHTUFF_DIR}/src/forms/confirm.sh"

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
source "${SHTUFF_DIR}/src/containers/pct_next_vmid.sh"
source "${SHTUFF_DIR}/src/containers/lxc_network.sh"
source "${SHTUFF_DIR}/src/containers/pct_network.sh"
source "${SHTUFF_DIR}/src/containers/lxc_shell_script.sh"
source "${SHTUFF_DIR}/src/containers/pct_shell_script.sh"
source "${SHTUFF_DIR}/src/containers/container_prompt.sh"
source "${SHTUFF_DIR}/src/containers/container.sh"
source "${SHTUFF_DIR}/src/containers/container_script.sh"
