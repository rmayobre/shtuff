#!/bin/bash

SHTUFF_DIR=$(unset CDPATH && cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Package Managament Scripts
source "${SHTUFF_DIR}/packages/clean.sh"
source "${SHTUFF_DIR}/packages/install.sh"
source "${SHTUFF_DIR}/packages/uninstall.sh"
