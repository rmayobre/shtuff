#!/usr/bin/env bash

# BentoPDF Install Script
#
# Installs BentoPDF as a Docker-based systemd service using shtuff utilities.
# BentoPDF is a privacy-first, client-side PDF toolkit for self-hosting.
#
# Usage:
#   sudo ./install-bentodpf.sh [OPTIONS]
#
# Options:
#   -p, --port PORT     Port to expose BentoPDF on (default: 3000)
#   -h, --help          Show this help message
#
# Requirements:
#   - Root or sudo privileges
#   - curl (for sourcing shtuff utilities)
#   - Internet connection (for Docker image pull)

# Source shtuff utilities
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

# --- Configuration ---
readonly BENTODPF_IMAGE="bentopdf/bentopdf"
readonly BENTODPF_CONTAINER="bentopdf"
readonly BENTODPF_SERVICE="bentopdf"
BENTODPF_PORT="${BENTODPF_PORT:-3000}"

# --- Parse Arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--port)
            BENTODPF_PORT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: sudo $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -p, --port PORT     Port to expose BentoPDF on (default: 3000)"
            echo "  -h, --help          Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  BENTODPF_PORT       Equivalent to --port"
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

info "Starting BentoPDF installation..."
info "BentoPDF will be exposed on port ${BENTODPF_PORT}."

# --- Step 1: Update System ---
info "Updating system packages..."
update &
monitor $! \
    --style "$SPINNER_LOADING_STYLE" \
    --message "Updating system packages" \
    --success_msg "System packages updated" \
    --error_msg "Failed to update system packages" || exit 1

# --- Step 2: Install Docker ---
if ! command -v docker &>/dev/null; then
    info "Docker not found. Installing Docker..."
    install docker.io &
    monitor $! \
        --style "$SPINNER_LOADING_STYLE" \
        --message "Installing Docker" \
        --success_msg "Docker installed" \
        --error_msg "Failed to install Docker" || exit 1
else
    info "Docker is already installed: $(docker --version)"
fi

# --- Step 3: Enable Docker Service ---
info "Enabling Docker service..."
systemctl enable --now docker

# --- Step 4: Pull BentoPDF Image ---
info "Pulling BentoPDF Docker image..."
docker pull "${BENTODPF_IMAGE}" &
monitor $! \
    --style "$BARS_LOADING_STYLE" \
    --message "Pulling BentoPDF image (${BENTODPF_IMAGE})" \
    --success_msg "BentoPDF image pulled successfully" \
    --error_msg "Failed to pull BentoPDF image" || exit 1

# --- Step 5: Create Systemd Service ---
info "Creating BentoPDF systemd service..."
service \
    --name "${BENTODPF_SERVICE}" \
    --description "BentoPDF - Privacy-First PDF Toolkit" \
    --exec-start-pre "-/usr/bin/docker rm -f ${BENTODPF_CONTAINER}" \
    --exec-start "/usr/bin/docker run --name ${BENTODPF_CONTAINER} -p ${BENTODPF_PORT}:3000 ${BENTODPF_IMAGE}" \
    --exec-stop "/usr/bin/docker stop ${BENTODPF_CONTAINER}" \
    --restart "always" \
    --restart-sec "10" || exit 1

# --- Step 6: Enable and Start BentoPDF ---
info "Enabling and starting BentoPDF service..."
systemctl daemon-reload
systemctl enable "${BENTODPF_SERVICE}"
systemctl start "${BENTODPF_SERVICE}" &
monitor $! \
    --style "$SPINNER_LOADING_STYLE" \
    --message "Starting BentoPDF" \
    --success_msg "BentoPDF is running!" \
    --error_msg "Failed to start BentoPDF service" || {
    error "BentoPDF failed to start. Check logs with: journalctl -u ${BENTODPF_SERVICE} -n 50"
    exit 1
}

info "BentoPDF installed and running successfully!"
info "Access BentoPDF at: http://localhost:${BENTODPF_PORT}"
info "Manage the service with: systemctl {start|stop|restart|status} ${BENTODPF_SERVICE}"
