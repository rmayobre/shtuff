#!/usr/bin/env bash

# Shtuff Live Demo
#
# Exercises the refactored shtuff API end-to-end so you can watch each
# function run with its loading indicator, progress bar, and log output.
#
# Usage:
#   sudo ./demo-shtuff.sh          # Full demo (packaging requires root)
#   ./demo-shtuff.sh               # Partial demo (skips packaging)

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../shtuff.sh"

DEMO_DIR=$(mktemp -d /tmp/shtuff_demo_XXXXXX)

# ─── Logging ──────────────────────────────────────────────────────────────────

info "=== Logging ==="
info "This is an info message"
warn "This is a warning message"
error "This is an error message (non-fatal, just demonstrating)"
debug "This debug message is hidden unless LOG_LEVEL=debug"

# ─── Monitor styles ──────────────────────────────────────────────────────────

info "=== Monitor loading styles ==="

sleep 2 &
monitor $! --style "$SPINNER_LOADING_STYLE" \
    --message "Spinner style" \
    --success_msg "Spinner done"

sleep 2 &
monitor $! --style "$DOTS_LOADING_STYLE" \
    --message "Dots style" \
    --success_msg "Dots done"

sleep 2 &
monitor $! --style "$BARS_LOADING_STYLE" \
    --message "Bars style" \
    --success_msg "Bars done"

sleep 2 &
monitor $! --style "$ARROWS_LOADING_STYLE" \
    --message "Arrows style" \
    --success_msg "Arrows done"

sleep 2 &
monitor $! --style "$CLOCK_LOADING_STYLE" \
    --message "Clock style" \
    --success_msg "Clock done"

# ─── File operations ─────────────────────────────────────────────────────────

info "=== File operations ==="

echo "Hello from shtuff demo" > "${DEMO_DIR}/original.txt"

copy "${DEMO_DIR}/original.txt" "${DEMO_DIR}/copied.txt" \
    --message "Copying file" || exit 1

move "${DEMO_DIR}/copied.txt" "${DEMO_DIR}/moved.txt" \
    --message "Moving file" || exit 1

delete "${DEMO_DIR}/moved.txt" \
    --message "Deleting file" || exit 1

# ─── Download ─────────────────────────────────────────────────────────────────

info "=== Download (now in utils/) ==="

download \
    --url "https://raw.githubusercontent.com/rmayobre/shtuff/main/LICENSE" \
    --dir "$DEMO_DIR" \
    --output "LICENSE.txt" \
    --style "$DOTS_LOADING_STYLE" \
    --message "Downloading LICENSE from GitHub" || {
    warn "Download failed (network may be unavailable)"
}

# ─── Port scanning ───────────────────────────────────────────────────────────

info "=== Network: scan (formerly check_port) ==="

if scan --port 22; then
    info "Port 22 is free"
else
    info "Port 22 is in use (SSH likely running)"
fi

if scan --port 80; then
    info "Port 80 is free"
else
    info "Port 80 is in use"
fi

# ─── Packaging with built-in monitor ─────────────────────────────────────────

info "=== Packaging (with built-in monitor) ==="

if [[ $EUID -eq 0 ]]; then
    update \
        --style "$SPINNER_LOADING_STYLE" \
        --message "Updating system packages" \
        --success_msg "System packages updated" \
        --error_msg "Failed to update system packages" || exit 1

    install curl wget \
        --style "$DOTS_LOADING_STYLE" \
        --message "Installing curl and wget" \
        --success_msg "curl and wget installed" \
        --error_msg "Failed to install packages" || exit 1

    clean \
        --style "$BARS_LOADING_STYLE" \
        --message "Cleaning up unused packages" \
        --success_msg "Package cache cleaned" \
        --error_msg "Cleanup failed" || exit 1

    info "=== Dependencies (progress bar + per-package monitor) ==="

    dependencies curl wget unzip || exit 1
else
    warn "Skipping packaging demo (requires root)"
    warn "Re-run with: sudo $0"
fi

# ─── Cleanup ──────────────────────────────────────────────────────────────────

delete "$DEMO_DIR" --message "Cleaning up demo files" || exit 1

info "=== Demo complete ==="
info "Verbose log available at: $VERBOSE_FILE"
