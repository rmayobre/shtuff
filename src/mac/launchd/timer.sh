#!/usr/bin/env bash

# Function: timer
# Description: Placeholder for creating a scheduled job on macOS. launchd support is not
#              implemented yet, so this function always fails. It exists so scripts get a clear
#              error instead of "command not found".
#
# Arguments:
#   $@ - ignored: Accepts and ignores the same options as the Linux timer function.
#
# Returns:
#   1 - Always: timers are not implemented on macOS yet.
#
# Examples:
#   timer --name "backup" --on-calendar "daily" || exit 1
timer() {
    error "timer is not implemented on macOS yet (launchd support is planned)."
    return 1
}
