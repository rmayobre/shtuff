#!/usr/bin/env bash

# BentoPDF Native Update Script (No Docker)
#
# Downloads the latest BentoPDF release from GitHub, replaces the
# existing site files, and restarts the bentopdf systemd service.
#
# Usage:
#   sudo ./update-bentodpf-native.sh [OPTIONS]
#
# Options:
#   -d, --dir DIR       Directory where BentoPDF is installed (default: /var/www/bentopdf)
#   -h, --help          Show this help message
#
# Requirements:
#   - Root or sudo privileges
#   - BentoPDF installed via install-bentodpf-native.sh
#   - curl (for sourcing shtuff utilities and downloading the release)
#   - Internet connection

# Source shtuff utilities
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

# --- Configuration ---
readonly BENTODPF_REPO="alam00000/bentopdf"
readonly BENTODPF_SERVICE="bentopdf"
BENTODPF_DIR="${BENTODPF_DIR:-/var/www/bentopdf}"

# --- Parse Arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dir)
            BENTODPF_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: sudo $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -d, --dir DIR       Install directory (default: /var/www/bentopdf)"
            echo "  -h, --help          Show this help message"
            echo ""
            echo "Environment Variables:"
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

# --- Verify Install Directory Exists ---
if [[ ! -d "${BENTODPF_DIR}" ]]; then
    error "BentoPDF install directory '${BENTODPF_DIR}' not found."
    error "Install it first with: sudo ./install-bentodpf-native.sh"
    exit 1
fi

info "Updating BentoPDF (native)..."

# --- Step 1: Resolve Latest Release Download URL ---
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

# --- Step 2: Download Latest Release ---
curl -sL "$DOWNLOAD_URL" -o /tmp/bentodpf.zip &
monitor $! \
    --style "$BARS_LOADING_STYLE" \
    --message "Downloading latest BentoPDF release" \
    --success_msg "BentoPDF release downloaded" \
    --error_msg "Failed to download BentoPDF release" || exit 1

# --- Step 3: Extract and Replace Site Files ---
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

info "Replacing BentoPDF files in ${BENTODPF_DIR}..."
rm -rf "${BENTODPF_DIR:?}"/*
cp -r "${CONTENT_DIR}/." "${BENTODPF_DIR}/"
rm -rf /tmp/bentodpf_extract /tmp/bentodpf.zip

# --- Step 4: Restart Service ---
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
info "Site files are located at: ${BENTODPF_DIR}"
