#!/usr/bin/env bash

# Function: download
# Description: Downloads a file from a URL using curl (or wget as a fallback),
#              displaying a loading indicator while the transfer is in progress.
#              By default the file is saved in the same directory as the calling
#              script; use --dir to override the destination.
#
# Arguments:
#   --url URL      (string, required): The URL of the file to download.
#   --dir DIR      (string, optional, default: calling script's directory): Directory
#                  in which to save the downloaded file. Created if it does not exist.
#   --output NAME  (string, optional, default: basename of URL): Filename to use when
#                  saving the downloaded file. Derived from the URL when not provided.
#   --style STYLE  (string, optional, default: "spinner"): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --message MSG  (string, optional, default: "Downloading"): Message shown alongside
#                  the loading indicator.
#
# Globals:
#   DEFAULT_LOADING_STYLE (read): Fallback style used when --style is not provided.
#
# Returns:
#   0 - File downloaded successfully.
#   1 - Missing required arguments, unresolvable filename, directory creation failure,
#       no supported download tool available, or the download command failed.
#
# Examples:
#   download --url "https://example.com/archive.zip"
#   download --url "https://example.com/archive.zip" --dir /tmp
#   download --url "https://example.com/archive.zip" --dir /opt/myapp --output app.zip
#   download --url "https://example.com/archive.zip" --style dots --message "Fetching release"
function download {
    local url=""
    local dir=""
    local output=""
    local style="$DEFAULT_LOADING_STYLE"
    local message="Downloading"

    while (( "$#" )); do
        case "$1" in
            -u|--url)
                url="$2"
                shift 2
                ;;
            -d|--dir)
                dir="$2"
                shift 2
                ;;
            -o|--output)
                output="$2"
                shift 2
                ;;
            -s|--style)
                style="$2"
                shift 2
                ;;
            -m|--message)
                message="$2"
                shift 2
                ;;
            -*)
                error "download: unknown option: $1"
                return 1
                ;;
            *)
                error "download: unexpected argument: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$url" ]]; then
        error "download: --url is required"
        return 1
    fi

    # Default destination directory to the calling script's directory.
    if [[ -z "$dir" ]]; then
        local _caller="${BASH_SOURCE[1]:-}"
        if [[ -n "$_caller" && "$_caller" != "bash" ]]; then
            dir=$(unset CDPATH && cd "$(dirname "$_caller")" 2>/dev/null && pwd) || dir="$(pwd)"
        else
            dir="$(pwd)"
        fi
    fi

    # Derive output filename from the URL when not provided.
    if [[ -z "$output" ]]; then
        output=$(basename "$url")
        output="${output%%\?*}"   # strip query string
        if [[ -z "$output" || "$output" == "/" ]]; then
            error "download: could not derive a filename from the URL; use --output to specify one"
            return 1
        fi
    fi

    local dest="${dir}/${output}"

    mkdir -p "$dir" || {
        error "download: could not create directory: $dir"
        return 1
    }

    debug "download: url=$url dest=$dest"

    if command -v curl &>/dev/null; then
        curl -fsSL "$url" -o "$dest" &
    elif command -v wget &>/dev/null; then
        wget -q "$url" -O "$dest" &
    else
        error "download: neither curl nor wget is available"
        return 1
    fi

    monitor $! \
        --style "$style" \
        --message "$message $output" \
        --success_msg "$output downloaded to $dir" \
        --error_msg "Failed to download $output" || return 1
}
