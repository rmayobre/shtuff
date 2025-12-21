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

# Utilities
source <(curl -sL "${BASE_URL}/src/utils/monitor.sh")
source <(curl -sL "${BASE_URL}/src/utils/stop.sh")
