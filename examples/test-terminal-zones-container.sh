#!/usr/bin/env bash

# Terminal Output Zones — Container Test Script
#
# Creates a Debian 13 (trixie) container, pushes a simulated update script
# into it, and executes it — all while terminal zones keep log messages and
# loading indicators separated. Tests display_pipe routing of container
# output into the log zone while spinners animate in the status zone.
#
# Usage:
#   sudo bash examples/test-terminal-zones-container.sh
#
# Options:
#   -n, --name NAME   Container name (default: shtuff-zones-test)
#   -h, --help        Show this help message
#
# Requirements:
#   - Root or sudo privileges
#   - LXC or Proxmox host (auto-detected)
#   - Network access (to download Debian 13 template on first run)

SCRIPT_DIR=$(unset CDPATH && cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${SCRIPT_DIR}/shtuff.sh"

# --- Configuration ---
CONTAINER_NAME="${CONTAINER_NAME:-shtuff-zones-test}"

# --- Parse Arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--name)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: sudo $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -n, --name NAME   Container name (default: shtuff-zones-test)"
            echo "  -h, --help        Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  CONTAINER_NAME    Equivalent to --name"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# --- Root Check ---
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root or with sudo."
    exit 1
fi

# --- Initialize Display Zones ---
init_display --status-lines 3

info "=== Terminal Zones — Container Test ==="
info "Container name: ${CONTAINER_NAME}"
sleep 1

# --- Step 1: Create Container ---
info "Creating Debian 13 (trixie) container..."

container create \
    --name "$CONTAINER_NAME" \
    --dist debian \
    --release trixie \
    --memory 512 \
    --cores 1 &
monitor $! \
    --style "$SPINNER_LOADING_STYLE" \
    --message "Creating container ${CONTAINER_NAME}" \
    --success_msg "Container created" \
    --error_msg "Failed to create container" || exit 1

# --- Step 2: Start Container ---
info "Starting container..."

container start --name "$CONTAINER_NAME" &
monitor $! \
    --style "$DOTS_LOADING_STYLE" \
    --message "Starting ${CONTAINER_NAME}" \
    --success_msg "Container started" \
    --error_msg "Failed to start container" || exit 1

sleep 2
info "Waiting for container to settle..."
sleep 3

# --- Step 3: Push Simulated Update Script ---
info "Pushing simulated update script to container..."

CONTAINER_SCRIPT
#!/bin/bash

echo "=== Simulating apt update ==="
sleep 0.3
echo "Hit:1 http://deb.debian.org/debian trixie InRelease"
sleep 0.2
echo "Get:2 http://deb.debian.org/debian trixie-updates InRelease [52.1 kB]"
sleep 0.4
echo "Get:3 http://security.debian.org/debian-security trixie-security InRelease [44.2 kB]"
sleep 0.3
echo "Get:4 http://deb.debian.org/debian trixie-updates/main amd64 Packages [12.8 kB]"
sleep 0.5
echo "Get:5 http://security.debian.org/debian-security trixie-security/main amd64 Packages [68.4 kB]"
sleep 0.3
echo "Fetched 177 kB in 2s (88.5 kB/s)"
sleep 0.2
echo "Reading package lists..."
sleep 0.8
echo "Building dependency tree..."
sleep 0.6
echo "Reading state information..."
sleep 0.4
echo "All packages are up to date."
sleep 0.5

echo ""
echo "=== Simulating apt install curl wget ==="
sleep 0.3
echo "Reading package lists..."
sleep 0.5
echo "Building dependency tree..."
sleep 0.4
echo "Reading state information..."
sleep 0.3
echo "The following additional packages will be installed:"
echo "  ca-certificates libcurl4t64 libnghttp2-14 libpsl5t64 librtmp1"
echo "  libssh2-1t64 openssl publicsuffix wget"
sleep 0.2
echo "Suggested packages:"
echo "  libcurl4-doc"
sleep 0.2
echo "The following NEW packages will be installed:"
echo "  ca-certificates curl libcurl4t64 libnghttp2-14 libpsl5t64"
echo "  librtmp1 libssh2-1t64 openssl publicsuffix wget"
sleep 0.3
echo "0 upgraded, 10 newly installed, 0 to remove and 0 not upgraded."
echo "Need to get 3,847 kB of archives."
echo "After this operation, 11.2 MB of additional disk space will be used."
sleep 0.5
echo "Get:1 http://deb.debian.org/debian trixie/main amd64 openssl amd64 3.4.1-1 [1,372 kB]"
sleep 0.3
echo "Get:2 http://deb.debian.org/debian trixie/main amd64 ca-certificates all 20241223 [165 kB]"
sleep 0.2
echo "Get:3 http://deb.debian.org/debian trixie/main amd64 libnghttp2-14 amd64 1.64.0-1 [77.0 kB]"
sleep 0.2
echo "Get:4 http://deb.debian.org/debian trixie/main amd64 libpsl5t64 amd64 0.21.2-1.1 [58.7 kB]"
sleep 0.2
echo "Get:5 http://deb.debian.org/debian trixie/main amd64 libcurl4t64 amd64 8.12.1-3 [429 kB]"
sleep 0.3
echo "Get:6 http://deb.debian.org/debian trixie/main amd64 curl amd64 8.12.1-3 [254 kB]"
sleep 0.2
echo "Get:7 http://deb.debian.org/debian trixie/main amd64 wget amd64 1.25.0-2 [1,058 kB]"
sleep 0.4
echo "Fetched 3,847 kB in 3s (1,282 kB/s)"
sleep 0.3
echo "Selecting previously unselected package openssl."
sleep 0.1
echo "Preparing to unpack .../openssl_3.4.1-1_amd64.deb ..."
sleep 0.1
echo "Unpacking openssl (3.4.1-1) ..."
sleep 0.2
echo "Selecting previously unselected package ca-certificates."
sleep 0.1
echo "Preparing to unpack .../ca-certificates_20241223_all.deb ..."
sleep 0.1
echo "Unpacking ca-certificates (20241223) ..."
sleep 0.3
echo "Selecting previously unselected package curl."
sleep 0.1
echo "Preparing to unpack .../curl_8.12.1-3_amd64.deb ..."
sleep 0.1
echo "Unpacking curl (8.12.1-3) ..."
sleep 0.2
echo "Selecting previously unselected package wget."
sleep 0.1
echo "Preparing to unpack .../wget_1.25.0-2_amd64.deb ..."
sleep 0.1
echo "Unpacking wget (1.25.0-2) ..."
sleep 0.3
echo "Setting up openssl (3.4.1-1) ..."
sleep 0.2
echo "Setting up ca-certificates (20241223) ..."
sleep 0.3
echo "Updating certificates in /etc/ssl/certs..."
sleep 0.5
echo "1 added, 0 removed; done."
sleep 0.2
echo "Setting up curl (8.12.1-3) ..."
sleep 0.2
echo "Setting up wget (1.25.0-2) ..."
sleep 0.2
echo "Processing triggers for man-db (2.13.0-1) ..."
sleep 0.3
echo "Processing triggers for ca-certificates (20241223) ..."
sleep 0.2
echo "Updating certificates in /etc/ssl/certs..."
sleep 0.4
echo "0 added, 0 removed; done."
sleep 0.2
echo "Running hooks in /etc/ca-certificates/update.d..."
sleep 0.3
echo "done."
sleep 0.2

echo ""
echo "=== Simulated update complete ==="
CONTAINER_SCRIPT_EOD

container shell-script \
    --name "$CONTAINER_NAME" \
    --path /opt/simulate-update.sh &
monitor $! \
    --style "$BARS_LOADING_STYLE" \
    --message "Pushing update script to container" \
    --success_msg "Script pushed" \
    --error_msg "Failed to push script" || exit 1

# --- Step 4: Execute the Script ---
info "Running simulated update inside container..."
info "Container output will stream into the log zone via display_pipe."
sleep 0.5

container exec --name "$CONTAINER_NAME" -- bash /opt/simulate-update.sh \
    > >(display_pipe) 2>&1 &
monitor $! \
    --style "$SPINNER_LOADING_STYLE" \
    --message "Running update inside ${CONTAINER_NAME}" \
    --success_msg "Update script finished" \
    --error_msg "Update script failed" || exit 1

sleep 1

# --- Step 5: Cleanup ---
info "Cleaning up container..."

container delete --name "$CONTAINER_NAME" --force &
monitor $! \
    --style "$ARROWS_LOADING_STYLE" \
    --message "Deleting ${CONTAINER_NAME}" \
    --success_msg "Container deleted" \
    --error_msg "Failed to delete container" || exit 1

info "=== Container test completed ==="
info "Terminal will be restored in 2 seconds..."
sleep 2
