#!/usr/bin/env bash

# Enhanced function to get total size (works for files AND directories)
function size_of {
    local path="$1"

    if [ -f "$path" ]; then
        # Regular file - get file size
        stat -f%z "$path" 2>/dev/null || stat -c%s "$path" 2>/dev/null
    elif [ -d "$path" ]; then
        # Directory - get total size of all contents
        du -sb "$path" 2>/dev/null | cut -f1 || du -sk "$path" 2>/dev/null | awk '{print $1*1024}'
    else
        echo "0"
    fi
}
