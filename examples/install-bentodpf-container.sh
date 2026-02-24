#!/usr/bin/env bash

# BentoPDF Container Install Script (No Docker)
#
# Creates a Debian Trixie LXC or Proxmox CT container and installs BentoPDF
# inside it using the native (non-Docker) installer. Automatically detects
# whether Proxmox Container Toolkit (PCT) or LXC is available and uses the
# appropriate backend. After installation, drops into an interactive session
# inside the container.
#
# Usage:
#   sudo ./install-bentodpf-container.sh [OPTIONS]
#
# Options:
#   -n, --name NAME         Container name (LXC) or numeric VMID (PCT).
#                           (default: bentopdf for LXC / 200 for PCT)
#   -p, --port PORT         Port BentoPDF will be served on inside the container.
#                           (default: 3000)
#   -d, --dir DIR           Directory inside the container where BentoPDF is installed.
#                           (default: /var/www/bentopdf)
#   -t, --template TEMPLATE PCT Debian 13 template path. Only used on Proxmox VE.
#                           Run 'pveam available | grep debian-13' to find the exact
#                           template name, then download it first with
#                           'pveam download local <template-name>'.
#                           (default: local:vztmpl/debian-13-standard_13.x-1_amd64.tar.zst)
#   -h, --help              Show this help message
#
# Requirements:
#   - Root or sudo privileges
#   - curl (for sourcing shtuff utilities)
#   - PCT (Proxmox VE) or LXC; LXC will be installed automatically if missing
#   - Internet access from within the container (for downloading BentoPDF)
#   - On PCT: Debian 13 template must be downloaded before running this script

# Source shtuff utilities
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

# --- Configuration ---
readonly BENTOPDF_SERVICE="bentopdf"
CONTAINER_NAME="${CONTAINER_NAME:-bentopdf}"
CONTAINER_VMID="${CONTAINER_VMID:-200}"
PCT_TEMPLATE="${PCT_TEMPLATE:-local:vztmpl/debian-13-standard_13.x-1_amd64.tar.zst}"
BENTOPDF_PORT="${BENTOPDF_PORT:-3000}"
BENTOPDF_DIR="${BENTOPDF_DIR:-/var/www/bentopdf}"

# --- Parse Arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--name)
            CONTAINER_NAME="$2"
            CONTAINER_VMID="$2"
            shift 2
            ;;
        -p|--port)
            BENTOPDF_PORT="$2"
            shift 2
            ;;
        -d|--dir)
            BENTOPDF_DIR="$2"
            shift 2
            ;;
        -t|--template)
            PCT_TEMPLATE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: sudo $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -n, --name NAME         Container name (LXC) or VMID (PCT) (default: bentopdf / 200)"
            echo "  -p, --port PORT         Port to serve BentoPDF on (default: 3000)"
            echo "  -d, --dir DIR           BentoPDF install directory inside container (default: /var/www/bentopdf)"
            echo "  -t, --template TEMPLATE PCT Debian 13 template path (PCT only)"
            echo "  -h, --help              Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  CONTAINER_NAME   Container name — equivalent to --name (LXC)"
            echo "  CONTAINER_VMID   Container VMID  — equivalent to --name (PCT)"
            echo "  PCT_TEMPLATE     Equivalent to --template"
            echo "  BENTOPDF_PORT    Equivalent to --port"
            echo "  BENTOPDF_DIR     Equivalent to --dir"
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

# --- Detect Backend ---
# Mirrors the logic inside container() — check for pct, fall back to lxc.
if command -v pct &>/dev/null; then
    BACKEND="pct"
    CONTAINER_ID="$CONTAINER_VMID"
    info "Detected Proxmox VE — using PCT backend (VMID: ${CONTAINER_ID})"
else
    BACKEND="lxc"
    CONTAINER_ID="$CONTAINER_NAME"
    info "Using LXC backend (container name: ${CONTAINER_ID})"
fi

info "Starting BentoPDF container installation (Debian Trixie, no Docker)..."

# --- Step 1: Create Debian Trixie Container ---
# PCT and LXC use different arguments to specify the base image, so each
# backend gets its own create call with the appropriate flags.
if [[ "$BACKEND" == "pct" ]]; then
    container create \
        --name "${CONTAINER_ID}" \
        --template "${PCT_TEMPLATE}" \
        --hostname "${BENTOPDF_SERVICE}" \
        --memory 1024 \
        --cores 2 \
        --disk-size 16 \
        --style "$SPINNER_LOADING_STYLE" || exit 1
else
    container create \
        --name "${CONTAINER_ID}" \
        --dist debian \
        --release trixie \
        --arch amd64 \
        --style "$SPINNER_LOADING_STYLE" || exit 1
fi

# --- Step 2: Start Container ---
if [[ "$BACKEND" == "pct" ]]; then
    pct start "${CONTAINER_ID}" &
else
    lxc-start -n "${CONTAINER_ID}" &
fi
monitor $! \
    --style "$SPINNER_LOADING_STYLE" \
    --message "Starting container '${CONTAINER_ID}'" \
    --success_msg "Container '${CONTAINER_ID}' is running." \
    --error_msg "Failed to start container '${CONTAINER_ID}'." || exit 1

# --- Step 3: Install curl Inside Container ---
# Debian minimal images ship without curl. Install it before running the
# BentoPDF installer, which sources shtuff remotely via curl.
if [[ "$BACKEND" == "pct" ]]; then
    pct exec "${CONTAINER_ID}" -- bash -c "apt-get update -qq && apt-get install -y curl" &
else
    lxc-attach -n "${CONTAINER_ID}" -- bash -c "apt-get update -qq && apt-get install -y curl" &
fi
monitor $! \
    --style "$SPINNER_LOADING_STYLE" \
    --message "Preparing container environment" \
    --success_msg "Container environment ready." \
    --error_msg "Failed to prepare container environment." || exit 1

# --- Step 4: Install BentoPDF Inside Container ---
# Runs the native BentoPDF installer (no Docker) directly inside the container.
# The install script is sourced remotely and handles all remaining steps:
# package updates, Node.js installation, release download, and systemd service
# setup. Output is shown in full so progress is visible during this long step.
info "Installing BentoPDF inside container '${CONTAINER_ID}'..."
INSTALL_CMD="bash <(curl -sL 'https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/examples/install-bentodpf-native.sh') --port ${BENTOPDF_PORT} --dir ${BENTOPDF_DIR}"
if [[ "$BACKEND" == "pct" ]]; then
    pct exec "${CONTAINER_ID}" -- bash -c "${INSTALL_CMD}" || exit 1
else
    lxc-attach -n "${CONTAINER_ID}" -- bash -c "${INSTALL_CMD}" || exit 1
fi

# --- Done ---
info "BentoPDF installed successfully inside container '${CONTAINER_ID}'."
info "Access BentoPDF at: http://localhost:${BENTOPDF_PORT}"
info "Manage the service inside the container: systemctl {start|stop|restart|status} ${BENTOPDF_SERVICE}"
info ""
info "Entering container '${CONTAINER_ID}'..."
container enter --name "${CONTAINER_ID}"
