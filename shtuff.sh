#!/usr/bin/env bash

SHTUFF_DIR=$(unset CDPATH && cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)


# Graphical helpers
source "${SHTUFF_DIR}/src/graphics/colors.sh"
source "${SHTUFF_DIR}/src/graphics/draw_loading_indicator.sh"

# Operations
source "${SHTUFF_DIR}/src/operations/copy_file.sh"

# Package Managament Scripts
source "${SHTUFF_DIR}/src/packaging/clean.sh"
source "${SHTUFF_DIR}/src/packaging/install.sh"
source "${SHTUFF_DIR}/src/packaging/uninstall.sh"

# Utility functions
source "${SHTUFF_DIR}/src/utils/monitor.sh"
source "${SHTUFF_DIR}/src/utils/size.sh"
source "${SHTUFF_DIR}/src/utils/stop.sh"
