#!/usr/bin/env bash

SHTUFF_DIR=$(unset CDPATH && cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Package Managament Scripts
source "${SHTUFF_DIR}/src/packaging/clean.sh"
source "${SHTUFF_DIR}/src/packaging/install.sh"
source "${SHTUFF_DIR}/src/packaging/uninstall.sh"
source "${SHTUFF_DIR}/src/packaging/update.sh"

# Graphical helpers
source "${SHTUFF_DIR}/src/graphics/draw_loading_indicator.sh"

# Utility functions
source "${SHTUFF_DIR}/src/utils/monitor.sh"
source "${SHTUFF_DIR}/src/utils/stop.sh"
