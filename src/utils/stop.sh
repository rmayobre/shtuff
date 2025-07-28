#!/usr/bin/env bash

# Function: stop
# Description: Stops the background process and waits for it to finish.
# Parameters:
#   $1 - pid (integer, required): Process ID to kill
# Returns: Zero if succcesfully stopped.
function stop {
    local pid="$1"

    if [[ -z "$pid" ]]; then
        echo "Error: No PID provided"
        exit 1
    fi

    if [[ -n "$pid" ]]; then
        kill "$pid" 2>/dev/null || return $?
        wait "$pid" 2>/dev/null || return $?
    fi

    return 0
}
