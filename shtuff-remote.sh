#!/usr/bin/env bash

BASE_URL="https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/"

# Package Managament Scripts
source <(curl -sL "${BASE_URL}/src/packaging/clean.sh")
source <(curl -sL "${BASE_URL}/src/packaging/install.sh")
source <(curl -sL "${BASE_URL}/src/packaging/uninstall.sh")

# Graphical helpers
source <(curl -sL "${BASE_URL}/src/graphics/draw_loading_indicator.sh")

# Utility functions
source <(curl -sL "${BASE_URL}/src/utils/monitor.sh")
source <(curl -sL "${BASE_URL}/src/utils/stop.sh")
