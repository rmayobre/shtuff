#!/usr/bin/env bash

# BentoPDF Docker Update Script
#
# Pulls the latest BentoPDF Docker image and restarts the systemd service.
#
# Usage:
#   sudo ./update-bentodpf-docker.sh
#
# Requirements:
#   - Root or sudo privileges
#   - BentoPDF installed via install-bentodpf-docker.sh
#   - curl (for sourcing shtuff utilities)
#   - Internet connection

# Source shtuff utilities
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

# --- Configuration ---
readonly BENTODPF_IMAGE="bentopdf/bentopdf"
readonly BENTODPF_SERVICE="bentopdf"

# --- Root Check ---
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root or with sudo."
    exit 1
fi

# --- Verify Service Exists ---
if ! systemctl list-unit-files "${BENTODPF_SERVICE}.service" &>/dev/null; then
    error "BentoPDF service '${BENTODPF_SERVICE}' not found."
    error "Install it first with: sudo ./install-bentodpf-docker.sh"
    exit 1
fi

info "Updating BentoPDF (Docker)..."

# --- Step 1: Pull Latest Image ---
info "Pulling latest BentoPDF Docker image..."
docker pull "${BENTODPF_IMAGE}" &
monitor $! \
    --style "$BARS_LOADING_STYLE" \
    --message "Pulling latest BentoPDF image (${BENTODPF_IMAGE})" \
    --success_msg "Latest image pulled successfully" \
    --error_msg "Failed to pull latest BentoPDF image" || exit 1

# --- Step 2: Restart Service ---
info "Restarting BentoPDF service..."
systemctl restart "${BENTODPF_SERVICE}" &
monitor $! \
    --style "$SPINNER_LOADING_STYLE" \
    --message "Restarting BentoPDF" \
    --success_msg "BentoPDF restarted successfully!" \
    --error_msg "Failed to restart BentoPDF service" || {
    error "BentoPDF failed to restart. Check logs with: journalctl -u ${BENTODPF_SERVICE} -n 50"
    exit 1
}

info "BentoPDF updated successfully!"
info "Manage the service with: systemctl {start|stop|restart|status} ${BENTODPF_SERVICE}"
