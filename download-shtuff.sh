#!/usr/bin/env bash
#
# download-shtuff.sh
#
# Downloads the latest shtuff release and extracts it to a specified directory.
#
# Usage:
#   bash download-shtuff.sh [OPTIONS]
#
# Options:
#   -d, --dir PATH    Parent directory to extract shtuff into (default: /tmp)
#                     shtuff will be placed at PATH/shtuff/
#   -h, --help        Show this help message and exit
#
# Requirements:
#   curl or wget (curl is installed automatically if neither is found)

readonly SHTUFF_REPO="rmayobre/shtuff"
DEST_DIR="${DEST_DIR:-/tmp}"
_DOWNLOAD_CMD=""

_info()  { printf "\033[32m[info]\033[0m  %s\n" "$*"; }
_warn()  { printf "\033[33m[warn]\033[0m  %s\n" "$*" >&2; }
_error() { printf "\033[31m[error]\033[0m %s\n" "$*" >&2; }

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dir)
            DEST_DIR="$2"
            shift 2
            ;;
        -h|--help)
            awk 'NR>1 && !/^#/{exit} NR>1{sub(/^# ?/,""); print}' "$0"
            exit 0
            ;;
        *)
            _error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# --- Ensure a download tool is available ---
if command -v curl &>/dev/null; then
    _DOWNLOAD_CMD="curl"
elif command -v wget &>/dev/null; then
    _DOWNLOAD_CMD="wget"
else
    _info "Neither curl nor wget found — installing curl..."
    if   command -v apt-get &>/dev/null; then apt-get install -y curl
    elif command -v dnf     &>/dev/null; then dnf install -y curl
    elif command -v yum     &>/dev/null; then yum install -y curl
    elif command -v zypper  &>/dev/null; then zypper install -y curl
    elif command -v pacman  &>/dev/null; then pacman -S --noconfirm curl
    elif command -v apk     &>/dev/null; then apk add --no-cache curl
    else
        _error "No supported package manager found. Install curl or wget manually."
        exit 1
    fi
    _DOWNLOAD_CMD="curl"
fi

# --- Helpers ---
_fetch_stdout() {
    if [[ "$_DOWNLOAD_CMD" == "curl" ]]; then
        curl -fsSL "$1"
    else
        wget -qO- "$1"
    fi
}

_fetch_file() {
    if [[ "$_DOWNLOAD_CMD" == "curl" ]]; then
        curl -fsSL "$1" -o "$2"
    else
        wget -qO "$2" "$1"
    fi
}

# --- Resolve latest release ---
_info "Resolving latest shtuff release..."
_RELEASE_JSON=$(_fetch_stdout "https://api.github.com/repos/${SHTUFF_REPO}/releases/latest")

# Prefer an explicit release asset (tar.gz then zip), fall back to GitHub's auto-generated source archive
_DOWNLOAD_URL=$(printf '%s' "$_RELEASE_JSON" \
    | grep '"browser_download_url"' \
    | grep '\.tar\.gz' \
    | head -1 \
    | sed 's/.*"browser_download_url": "\(.*\)".*/\1/')

if [[ -z "$_DOWNLOAD_URL" ]]; then
    _DOWNLOAD_URL=$(printf '%s' "$_RELEASE_JSON" \
        | grep '"browser_download_url"' \
        | grep '\.zip' \
        | head -1 \
        | sed 's/.*"browser_download_url": "\(.*\)".*/\1/')
fi

if [[ -z "$_DOWNLOAD_URL" ]]; then
    _DOWNLOAD_URL=$(printf '%s' "$_RELEASE_JSON" \
        | grep '"tarball_url"' \
        | head -1 \
        | sed 's/.*"tarball_url": "\(.*\)".*/\1/')
fi

if [[ -z "$_DOWNLOAD_URL" ]]; then
    _error "Could not determine the download URL."
    _error "Check your internet connection or visit: https://github.com/${SHTUFF_REPO}/releases"
    exit 1
fi

# --- Determine archive format ---
_EXT="tar.gz"
[[ "$_DOWNLOAD_URL" == *.zip ]] && _EXT="zip"
_ARCHIVE="/tmp/shtuff-release.${_EXT}"

# --- Download ---
_info "Downloading shtuff..."
_fetch_file "$_DOWNLOAD_URL" "$_ARCHIVE" || {
    _error "Download failed."
    exit 1
}

# --- Extract ---
_TMP_EXTRACT=$(mktemp -d)
_info "Extracting release..."
if [[ "$_EXT" == "zip" ]]; then
    unzip -qo "$_ARCHIVE" -d "$_TMP_EXTRACT"
else
    tar -xzf "$_ARCHIVE" -C "$_TMP_EXTRACT"
fi

# The archive always produces a single top-level directory ({owner}-{repo}-{sha} or similar)
_EXTRACTED_DIR=$(find "$_TMP_EXTRACT" -maxdepth 1 -mindepth 1 -type d | head -1)
if [[ -z "$_EXTRACTED_DIR" ]]; then
    _error "Archive produced no top-level directory. The release may be malformed."
    rm -rf "$_TMP_EXTRACT" "$_ARCHIVE"
    exit 1
fi

# --- Install to destination ---
_SHTUFF_DEST="${DEST_DIR}/shtuff"
if [[ -d "$_SHTUFF_DEST" ]]; then
    _warn "${_SHTUFF_DEST} already exists — overwriting."
    rm -rf "$_SHTUFF_DEST"
fi
mkdir -p "$DEST_DIR"
mv "$_EXTRACTED_DIR" "$_SHTUFF_DEST"

# --- Cleanup ---
rm -rf "$_TMP_EXTRACT" "$_ARCHIVE"

_info "shtuff is ready at ${_SHTUFF_DEST}"
_info "Source locally with: source ${_SHTUFF_DEST}/shtuff.sh"
