#!/usr/bin/env bash

# Function: service
# Description: Placeholder for creating a background service on macOS. launchd support is not
#              implemented yet, so this function always fails. It exists so scripts get a clear
#              error instead of "command not found".
#
# Arguments:
#   $@ - ignored: Accepts and ignores the same options as the Linux service function.
#
# Returns:
#   1 - Always: services are not implemented on macOS yet.
#
# Examples:
#   service --name "myapp" --description "My App" --exec-start "/usr/local/bin/myapp" || exit 1
service() {
    error "service is not implemented on macOS yet (launchd support is planned)."
    return 1
}
