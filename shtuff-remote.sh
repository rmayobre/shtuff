#!/usr/bin/env bash

# Base URL for scripts. Change if this project has been forked.
BASE_URL="https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/"

# When set to "true", all functions that support --dry-run will print the system
# calls they would execute instead of running them. Can be overridden per-call
# with --dry-run.
IS_DRY_RUN=${IS_DRY_RUN:-false}

# Determine fetch command (prefer curl, fall back to wget)
if command -v curl &>/dev/null; then
    _fetch() { curl -sL "$1"; }
elif command -v wget &>/dev/null; then
    _fetch() { wget -qO- "$1"; }
else
    echo "shtuff: curl or wget is required but neither was found." >&2
    return 1
fi

# Globals
source <(_fetch "${BASE_URL}/src/graphics/colors.sh")

# Logging
source <(_fetch "${BASE_URL}/src/logging/log.sh")

# Terminal
source <(_fetch "${BASE_URL}/src/terminal/zones.sh")

# Graphical
source <(_fetch "${BASE_URL}/src/graphics/draw_loading_indicator.sh")

# Package Managament
source <(_fetch "${BASE_URL}/src/packaging/clean.sh")
source <(_fetch "${BASE_URL}/src/packaging/install.sh")
source <(_fetch "${BASE_URL}/src/packaging/uninstall.sh")
source <(_fetch "${BASE_URL}/src/packaging/update.sh")

# Systemd
source <(_fetch "${BASE_URL}/src/systemd/service.sh")
source <(_fetch "${BASE_URL}/src/systemd/timer.sh")

# Networking
source <(_fetch "${BASE_URL}/src/networking/download.sh")
source <(_fetch "${BASE_URL}/src/networking/check_port.sh")
source <(_fetch "${BASE_URL}/src/networking/wait_for_port.sh")
source <(_fetch "${BASE_URL}/src/networking/bridge.sh")
source <(_fetch "${BASE_URL}/src/networking/forward.sh")
source <(_fetch "${BASE_URL}/src/networking/network.sh")

# Utilities
source <(_fetch "${BASE_URL}/src/utils/copy.sh")
source <(_fetch "${BASE_URL}/src/utils/delete.sh")
source <(_fetch "${BASE_URL}/src/utils/monitor.sh")
source <(_fetch "${BASE_URL}/src/utils/move.sh")
source <(_fetch "${BASE_URL}/src/utils/progress.sh")
source <(_fetch "${BASE_URL}/src/utils/stop.sh")

# Forms
source <(_fetch "${BASE_URL}/src/forms/question.sh")
source <(_fetch "${BASE_URL}/src/forms/options.sh")
source <(_fetch "${BASE_URL}/src/forms/selections.sh")
source <(_fetch "${BASE_URL}/src/forms/confirm.sh")

# GPU
source <(_fetch "${BASE_URL}/src/gpu/gpu_list.sh")
source <(_fetch "${BASE_URL}/src/gpu/gpu_select.sh")
source <(_fetch "${BASE_URL}/src/gpu/gpu_install.sh")

# Containers
source <(_fetch "${BASE_URL}/src/containers/lxc_config.sh")
source <(_fetch "${BASE_URL}/src/containers/lxc_create.sh")
source <(_fetch "${BASE_URL}/src/containers/lxc_delete.sh")
source <(_fetch "${BASE_URL}/src/containers/lxc_enter.sh")
source <(_fetch "${BASE_URL}/src/containers/lxc_exec.sh")
source <(_fetch "${BASE_URL}/src/containers/lxc_push.sh")
source <(_fetch "${BASE_URL}/src/containers/lxc_pull.sh")
source <(_fetch "${BASE_URL}/src/containers/lxc_start.sh")
source <(_fetch "${BASE_URL}/src/containers/pct_config.sh")
source <(_fetch "${BASE_URL}/src/containers/pct_create.sh")
source <(_fetch "${BASE_URL}/src/containers/pct_delete.sh")
source <(_fetch "${BASE_URL}/src/containers/pct_enter.sh")
source <(_fetch "${BASE_URL}/src/containers/pct_exec.sh")
source <(_fetch "${BASE_URL}/src/containers/pct_push.sh")
source <(_fetch "${BASE_URL}/src/containers/pct_pull.sh")
source <(_fetch "${BASE_URL}/src/containers/pct_start.sh")
source <(_fetch "${BASE_URL}/src/containers/pct_next_vmid.sh")
source <(_fetch "${BASE_URL}/src/containers/lxc_network.sh")
source <(_fetch "${BASE_URL}/src/containers/pct_network.sh")
source <(_fetch "${BASE_URL}/src/containers/lxc_network_show.sh")
source <(_fetch "${BASE_URL}/src/containers/pct_network_show.sh")
source <(_fetch "${BASE_URL}/src/containers/container_network_prompt.sh")
source <(_fetch "${BASE_URL}/src/containers/lxc_shell_script.sh")
source <(_fetch "${BASE_URL}/src/containers/pct_shell_script.sh")
source <(_fetch "${BASE_URL}/src/containers/container_prompt.sh")
source <(_fetch "${BASE_URL}/src/containers/pct_find_vmid.sh")
source <(_fetch "${BASE_URL}/src/containers/container.sh")
source <(_fetch "${BASE_URL}/src/containers/container_script.sh")
