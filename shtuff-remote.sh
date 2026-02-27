#!/usr/bin/env bash

# Base URL for scripts. Change if this project has been forked.
BASE_URL="https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/"

# Globals
source <(curl -sL "${BASE_URL}/src/graphics/colors.sh")

# Logging
source <(curl -sL "${BASE_URL}/src/logging/log.sh")

# Graphical
source <(curl -sL "${BASE_URL}/src/graphics/draw_loading_indicator.sh")

# Package Managament
source <(curl -sL "${BASE_URL}/src/packaging/clean.sh")
source <(curl -sL "${BASE_URL}/src/packaging/install.sh")
source <(curl -sL "${BASE_URL}/src/packaging/uninstall.sh")
source <(curl -sL "${BASE_URL}/src/packaging/update.sh")

# Systemd
source <(curl -sL "${BASE_URL}/src/systemd/service.sh")
source <(curl -sL "${BASE_URL}/src/systemd/timer.sh")

# Networking
source <(curl -sL "${BASE_URL}/src/networking/download.sh")

# Utilities
source <(curl -sL "${BASE_URL}/src/utils/copy.sh")
source <(curl -sL "${BASE_URL}/src/utils/delete.sh")
source <(curl -sL "${BASE_URL}/src/utils/monitor.sh")
source <(curl -sL "${BASE_URL}/src/utils/move.sh")
source <(curl -sL "${BASE_URL}/src/utils/progress.sh")
source <(curl -sL "${BASE_URL}/src/utils/stop.sh")
source <(curl -sL "${BASE_URL}/src/utils/copy.sh")
source <(curl -sL "${BASE_URL}/src/utils/move.sh")
source <(curl -sL "${BASE_URL}/src/utils/delete.sh")

# Forms
source <(curl -sL "${BASE_URL}/src/forms/question.sh")
source <(curl -sL "${BASE_URL}/src/forms/options.sh")
source <(curl -sL "${BASE_URL}/src/forms/confirm.sh")

# Containers
source <(curl -sL "${BASE_URL}/src/containers/lxc_config.sh")
source <(curl -sL "${BASE_URL}/src/containers/lxc_create.sh")
source <(curl -sL "${BASE_URL}/src/containers/lxc_delete.sh")
source <(curl -sL "${BASE_URL}/src/containers/lxc_enter.sh")
source <(curl -sL "${BASE_URL}/src/containers/lxc_exec.sh")
source <(curl -sL "${BASE_URL}/src/containers/lxc_push.sh")
source <(curl -sL "${BASE_URL}/src/containers/lxc_pull.sh")
source <(curl -sL "${BASE_URL}/src/containers/lxc_start.sh")
source <(curl -sL "${BASE_URL}/src/containers/pct_config.sh")
source <(curl -sL "${BASE_URL}/src/containers/pct_create.sh")
source <(curl -sL "${BASE_URL}/src/containers/pct_delete.sh")
source <(curl -sL "${BASE_URL}/src/containers/pct_enter.sh")
source <(curl -sL "${BASE_URL}/src/containers/pct_exec.sh")
source <(curl -sL "${BASE_URL}/src/containers/pct_push.sh")
source <(curl -sL "${BASE_URL}/src/containers/pct_pull.sh")
source <(curl -sL "${BASE_URL}/src/containers/pct_start.sh")
source <(curl -sL "${BASE_URL}/src/containers/container.sh")
