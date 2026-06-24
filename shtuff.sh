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
source "${SHTUFF_DIR}/src/packaging/dependencies.sh"

# Systemd
source "${SHTUFF_DIR}/src/systemd/service.sh"
source "${SHTUFF_DIR}/src/systemd/timer.sh"

# Networking
source "${SHTUFF_DIR}/src/networking/scan.sh"
source "${SHTUFF_DIR}/src/networking/poll.sh"
source "${SHTUFF_DIR}/src/networking/bridge.sh"
source "${SHTUFF_DIR}/src/networking/forward.sh"
source "${SHTUFF_DIR}/src/networking/network.sh"

# Utilities
source "${SHTUFF_DIR}/src/utils/download.sh"
source "${SHTUFF_DIR}/src/utils/copy.sh"
source "${SHTUFF_DIR}/src/utils/delete.sh"
source "${SHTUFF_DIR}/src/utils/monitor.sh"
source "${SHTUFF_DIR}/src/utils/move.sh"
source "${SHTUFF_DIR}/src/utils/progress.sh"
source "${SHTUFF_DIR}/src/utils/stop.sh"

# Prompts
source "${SHTUFF_DIR}/src/prompts/question.sh"
source "${SHTUFF_DIR}/src/prompts/options.sh"
source "${SHTUFF_DIR}/src/prompts/selections.sh"
source "${SHTUFF_DIR}/src/prompts/confirm.sh"

# GPU
source "${SHTUFF_DIR}/src/gpu/gpu_list.sh"
source "${SHTUFF_DIR}/src/gpu/gpu_select.sh"
source "${SHTUFF_DIR}/src/gpu/gpu_install.sh"

# Containers
# System
source "${SHTUFF_DIR}/src/system/locale.sh"

# Containers - LXC
source "${SHTUFF_DIR}/src/containers/lxc/lxc_config.sh"
source "${SHTUFF_DIR}/src/containers/lxc/lxc_create.sh"
source "${SHTUFF_DIR}/src/containers/lxc/lxc_delete.sh"
source "${SHTUFF_DIR}/src/containers/lxc/lxc_enter.sh"
source "${SHTUFF_DIR}/src/containers/lxc/lxc_exec.sh"
source "${SHTUFF_DIR}/src/containers/lxc/lxc_push.sh"
source "${SHTUFF_DIR}/src/containers/lxc/lxc_pull.sh"
source "${SHTUFF_DIR}/src/containers/lxc/lxc_start.sh"
source "${SHTUFF_DIR}/src/containers/lxc/lxc_network.sh"
source "${SHTUFF_DIR}/src/containers/lxc/lxc_network_show.sh"
source "${SHTUFF_DIR}/src/containers/lxc/lxc_shell_script.sh"

# Containers - PCT
source "${SHTUFF_DIR}/src/containers/pct/pct_config.sh"
source "${SHTUFF_DIR}/src/containers/pct/pct_create.sh"
source "${SHTUFF_DIR}/src/containers/pct/pct_delete.sh"
source "${SHTUFF_DIR}/src/containers/pct/pct_enter.sh"
source "${SHTUFF_DIR}/src/containers/pct/pct_exec.sh"
source "${SHTUFF_DIR}/src/containers/pct/pct_push.sh"
source "${SHTUFF_DIR}/src/containers/pct/pct_pull.sh"
source "${SHTUFF_DIR}/src/containers/pct/pct_start.sh"
source "${SHTUFF_DIR}/src/containers/pct/pct_next_vmid.sh"
source "${SHTUFF_DIR}/src/containers/pct/pct_network.sh"
source "${SHTUFF_DIR}/src/containers/pct/pct_network_show.sh"
source "${SHTUFF_DIR}/src/containers/pct/pct_shell_script.sh"
source "${SHTUFF_DIR}/src/containers/pct/pct_find_vmid.sh"

# Containers - Shared
source "${SHTUFF_DIR}/src/containers/container_network_prompt.sh"
source "${SHTUFF_DIR}/src/containers/container_prompt.sh"
source "${SHTUFF_DIR}/src/containers/container.sh"
source "${SHTUFF_DIR}/src/containers/container_script.sh"
