#!/bin/bash

BASE_URL="https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/"

# Package Managament Scripts
source <(curl -sL "${BASE_URL}/packages/clean.sh")
source <(curl -sL "${BASE_URL}/packages/install.sh")
source <(curl -sL "${BASE_URL}/packages/uninstall.sh")
