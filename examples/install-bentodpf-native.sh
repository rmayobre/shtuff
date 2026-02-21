#!/usr/bin/env bash

# BentoPDF Native Install Script (No Docker)
#
# Downloads the latest BentoPDF pre-built release from GitHub and serves it
# via Node.js (npx serve) as a systemd service using shtuff utilities.
#
# Usage:
#   sudo ./install-bentodpf-native.sh [OPTIONS]
#
# Options:
#   -p, --port PORT     Port to serve BentoPDF on (default: 3000)
#   -d, --dir DIR       Directory to install BentoPDF files (default: /var/www/bentopdf)
#   -h, --help          Show this help message
#
# Requirements:
#   - Root or sudo privileges
#   - curl (for sourcing shtuff utilities and downloading the release)
#   - Internet connection

# Source shtuff utilities
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

# --- Configuration ---
readonly BENTODPF_REPO="alam00000/bentopdf"
readonly BENTODPF_SERVICE="bentopdf"
BENTODPF_PORT="${BENTODPF_PORT:-3000}"
BENTODPF_DIR="${BENTODPF_DIR:-/var/www/bentopdf}"

# --- Parse Arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--port)
            BENTODPF_PORT="$2"
            shift 2
            ;;
        -d|--dir)
            BENTODPF_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: sudo $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -p, --port PORT     Port to serve BentoPDF on (default: 3000)"
            echo "  -d, --dir DIR       Install directory (default: /var/www/bentopdf)"
            echo "  -h, --help          Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  BENTODPF_PORT       Equivalent to --port"
            echo "  BENTODPF_DIR        Equivalent to --dir"
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

info "Starting BentoPDF native installation (no Docker)..."
info "BentoPDF will be served on port ${BENTODPF_PORT} from ${BENTODPF_DIR}."

# --- Step 1: Update System ---
info "Updating system packages..."
update &
monitor $! \
    --style "$SPINNER_LOADING_STYLE" \
    --message "Updating system packages" \
    --success_msg "System packages updated" \
    --error_msg "Failed to update system packages" || exit 1

# --- Step 2: Install Dependencies ---
info "Installing required packages (nodejs, npm, curl, unzip)..."
install nodejs npm curl unzip &
monitor $! \
    --style "$SPINNER_LOADING_STYLE" \
    --message "Installing nodejs, npm, curl, unzip" \
    --success_msg "Dependencies installed" \
    --error_msg "Failed to install dependencies" || exit 1

# --- Step 3: Resolve Latest Release Download URL ---
info "Resolving latest BentoPDF release..."
DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/${BENTODPF_REPO}/releases/latest" \
    | grep '"browser_download_url"' \
    | grep '\.zip' \
    | head -1 \
    | sed 's/.*"browser_download_url": "\(.*\)".*/\1/')

if [[ -z "$DOWNLOAD_URL" ]]; then
    error "Could not determine the latest BentoPDF release download URL."
    error "Check your internet connection or visit: https://github.com/${BENTODPF_REPO}/releases"
    exit 1
fi

info "Downloading BentoPDF from: ${DOWNLOAD_URL}"

# --- Step 4: Download Release ---
curl -sL "$DOWNLOAD_URL" -o /tmp/bentodpf.zip &
monitor $! \
    --style "$BARS_LOADING_STYLE" \
    --message "Downloading BentoPDF release" \
    --success_msg "BentoPDF release downloaded" \
    --error_msg "Failed to download BentoPDF release" || exit 1

# --- Step 5: Extract and Install Files ---
info "Extracting BentoPDF files..."
mkdir -p /tmp/bentodpf_extract
unzip -qo /tmp/bentodpf.zip -d /tmp/bentodpf_extract &
monitor $! \
    --style "$SPINNER_LOADING_STYLE" \
    --message "Extracting BentoPDF files" \
    --success_msg "Files extracted" \
    --error_msg "Failed to extract BentoPDF files" || exit 1

# Locate the dist/ directory (handles any zip nesting)
DIST_DIR=$(find /tmp/bentodpf_extract -type d -name "dist" -maxdepth 4 | head -1)
if [[ -z "$DIST_DIR" ]]; then
    error "Could not locate dist/ directory inside the downloaded archive."
    exit 1
fi
CONTENT_DIR=$(dirname "${DIST_DIR}")

info "Installing BentoPDF files to ${BENTODPF_DIR}..."
mkdir -p "${BENTODPF_DIR}"
cp -r "${CONTENT_DIR}/." "${BENTODPF_DIR}/"
rm -rf /tmp/bentodpf_extract /tmp/bentodpf.zip

# --- Step 6: Locate npx ---
NPX_BIN=$(command -v npx)
if [[ -z "${NPX_BIN}" ]]; then
    error "npx not found after installing Node.js. Check your Node.js installation."
    exit 1
fi

# --- Step 7: Create Systemd Service ---
info "Creating BentoPDF systemd service..."
service \
    --name "${BENTODPF_SERVICE}" \
    --description "BentoPDF - Privacy-First PDF Toolkit" \
    --working-directory "${BENTODPF_DIR}" \
    --exec-start "${NPX_BIN} serve dist -p ${BENTODPF_PORT}" \
    --restart "always" \
    --restart-sec "10" || exit 1

# --- Step 8: Enable and Start BentoPDF ---
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
info "Site files are located at: ${BENTODPF_DIR}"
