#!/usr/bin/env bash

# BentoPDF Native Install Script (No Docker)
#
# Downloads the latest BentoPDF pre-built release from GitHub and serves it
# as a static site via nginx using shtuff utilities.
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
readonly BENTODPF_NGINX_CONF="/etc/nginx/sites-available/bentopdf"
readonly BENTODPF_NGINX_ENABLED="/etc/nginx/sites-enabled/bentopdf"
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
info "Installing required packages (nginx, curl, unzip)..."
install nginx curl unzip &
monitor $! \
    --style "$SPINNER_LOADING_STYLE" \
    --message "Installing nginx, curl, unzip" \
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

# Locate the directory that contains index.html (handles any zip nesting)
CONTENT_DIR=$(dirname "$(find /tmp/bentodpf_extract -name "index.html" -maxdepth 4 | head -1)")
if [[ -z "$CONTENT_DIR" || "$CONTENT_DIR" == "." ]]; then
    error "Could not locate index.html inside the downloaded archive."
    exit 1
fi

info "Installing BentoPDF files to ${BENTODPF_DIR}..."
mkdir -p "${BENTODPF_DIR}"
cp -r "${CONTENT_DIR}/." "${BENTODPF_DIR}/"
rm -rf /tmp/bentodpf_extract /tmp/bentodpf.zip

# Set ownership so nginx can read the files
chown -R www-data:www-data "${BENTODPF_DIR}" 2>/dev/null \
    || chown -R nginx:nginx "${BENTODPF_DIR}" 2>/dev/null \
    || warn "Could not set ownership on ${BENTODPF_DIR}; nginx may lack read access."

# --- Step 6: Configure Nginx ---
info "Writing nginx site configuration..."
cat > "${BENTODPF_NGINX_CONF}" << EOF
server {
    listen ${BENTODPF_PORT};
    server_name _;

    root ${BENTODPF_DIR};
    index index.html;

    # Route all requests through index.html for client-side navigation
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Long-term cache for hashed static assets
    location ~* \.(js|css|woff2?|ttf|eot|svg|ico|png|jpg|jpeg|gif|webp)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Enable the site
ln -sf "${BENTODPF_NGINX_CONF}" "${BENTODPF_NGINX_ENABLED}"

# Remove the default nginx site if it conflicts on port 80
if [[ "${BENTODPF_PORT}" -eq 80 ]] && [[ -L /etc/nginx/sites-enabled/default ]]; then
    warn "Removing default nginx site to avoid port 80 conflict."
    rm -f /etc/nginx/sites-enabled/default
fi

# Validate nginx configuration
if ! nginx -t &>/dev/null; then
    error "nginx configuration test failed. Review ${BENTODPF_NGINX_CONF}."
    nginx -t
    exit 1
fi

# --- Step 7: Enable and Start Nginx ---
info "Enabling and starting nginx..."
systemctl enable nginx
systemctl restart nginx &
monitor $! \
    --style "$SPINNER_LOADING_STYLE" \
    --message "Starting nginx" \
    --success_msg "nginx is running!" \
    --error_msg "Failed to start nginx" || {
    error "nginx failed to start. Check logs with: journalctl -u nginx -n 50"
    exit 1
}

info "BentoPDF installed and running successfully!"
info "Access BentoPDF at: http://localhost:${BENTODPF_PORT}"
info "Manage the service with: systemctl {start|stop|restart|status} nginx"
info "Site files are located at: ${BENTODPF_DIR}"
