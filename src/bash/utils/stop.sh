#!/usr/bin/env bash

# Function: stop
# Description: Sends a termination signal to a background process and waits for it to exit.
#
# Arguments:
#   $1 - pid (integer, required): Process ID of the background process to stop.
#
# Globals:
#   None
#
# Returns:
#   0 - Process terminated and waited on successfully.
#   1 - No PID provided.
#   N - Exit code returned by kill or wait if either command fails.
#
# Examples:
#   some_command &
#   bg_pid=$!
#   stop "$bg_pid"
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
