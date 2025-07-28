#!/usr/bin/env bash

function copy_file {
    local source="$1"
    if ! [ -f "$source" ]; then
        echo "Source is NOT a file or does not exist: $source"
        exit 1
    fi

    local destination="$2"
    if ! [ -e "$destination" ]; then
        echo "Destination does not exist: $destination"
        exit 1
    fi

    local source_size
    local current_size
    source_size=$(size_of "$source")
    current_size=$(size_of "$destination")
    local percentage=$((current_size * 100 / source_size))

    # echo "Source size: $(numfmt --to=iec-i --suffix=B $source_size)"
    # echo "Starting copy..."

    # Start cp in background
    cp "$source" "$destination" &
    local cp_pid=$!

    trap 'kill "$cp_pid" 2>/dev/null' EXIT INT TERM

    # Monitor progress
    while kill -0 $cp_pid 2>/dev/null; do
        current_size=$(size_of "$destination")
        percentage=$((current_size * 100 / source_size))
        printf "\rProgress: %s / %s (%d%%)" \
               "$(numfmt --to=iec-i --suffix=B "$current_size")" \
               "$(numfmt --to=iec-i --suffix=B "$source_size")" \
               "$percentage"
        sleep 1
    done

    trap - EXIT INT TERM

    local exit_code=0

    # Collect error code from pid
    wait "$cp_pid" 2>/dev/null || exit_code=$?

    # Clear the line
    printf "\r\033[K"

    echo -e "\n${GREEN}✓ File copy completed${NO_COLOR}"

    # Show completion message
    if [[ $exit_code -eq 0 && -n "$success_msg" ]]; then
        echo -e "${GREEN}✓ $success_msg${NO_COLOR}"
    elif [[ $exit_code -ne 0 && -n "$error_msg" ]]; then
        echo -e "${RED}✗ $error_msg${NO_COLOR}"
    fi

    return $exit_code
}
