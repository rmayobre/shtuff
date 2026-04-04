#!/usr/bin/env bash

# Global variable that holds the accumulated shell script content between
# a container_script_start / container_script_end pair.
CONTAINER_SCRIPT_CONTENT=""

# Function: container_script_start
# Description: Opens a multi-line shell script string by initializing the global
#              CONTAINER_SCRIPT_CONTENT variable. Optionally seeds it with an
#              initial line (e.g. a shebang). Subsequent lines are appended by
#              the caller before closing with container_script_end.
#
# Arguments:
#   $1 - initial_content (string, optional): First line(s) of the script.
#        If omitted, CONTAINER_SCRIPT_CONTENT is reset to an empty string.
#
# Globals:
#   CONTAINER_SCRIPT_CONTENT (write): Set to the provided initial content, or
#                                     reset to an empty string when omitted.
#
# Returns:
#   0 - Always succeeds.
#
# Examples:
#   container_script_start "#!/bin/bash"
#   CONTAINER_SCRIPT_CONTENT+=$'\necho hello'
#   CONTAINER_SCRIPT_CONTENT+=$'\necho world'
#   container_script_end --name mycontainer --path /usr/local/bin/hello.sh
#
#   container_script_start
#   CONTAINER_SCRIPT_CONTENT="#!/bin/bash
#   apt-get update -qq
#   apt-get install -y curl"
#   container_script_end --name webserver --path /opt/setup.sh
function container_script_start {
    CONTAINER_SCRIPT_CONTENT="${1:-}"
}

# Function: container_script_end
# Description: Closes the multi-line shell script string opened by
#              container_script_start and creates the script inside the named
#              container by passing CONTAINER_SCRIPT_CONTENT to container shell-script.
#              Resets CONTAINER_SCRIPT_CONTENT to an empty string after the call.
#
# Arguments:
#   --name NAME   (string, required): Name or ID of the target container.
#   --path PATH   (string, required): Absolute destination path inside the container.
#   --style STYLE (string, optional, default: spinner): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --dry-run     (flag, optional): Print the system calls that would be executed
#                 without running them. Defaults to IS_DRY_RUN if not specified.
#
# Globals:
#   CONTAINER_SCRIPT_CONTENT (read):  The accumulated script content to write.
#   CONTAINER_SCRIPT_CONTENT (write): Reset to an empty string after the call.
#
# Returns:
#   0 - Script created successfully.
#   1 - Missing required arguments, or CONTAINER_SCRIPT_CONTENT is empty.
#   N - Exit code propagated from container shell-script.
#
# Examples:
#   container_script_start "#!/bin/bash"
#   CONTAINER_SCRIPT_CONTENT+=$'\necho hello'
#   container_script_end --name mycontainer --path /usr/local/bin/hello.sh
#
#   container_script_start "#!/bin/bash"
#   CONTAINER_SCRIPT_CONTENT+=$'\napt-get update -qq'
#   container_script_end --name webserver --path /opt/setup.sh --style dots
function container_script_end {
    if [[ -z "$CONTAINER_SCRIPT_CONTENT" ]]; then
        error "container_script_end: CONTAINER_SCRIPT_CONTENT is empty — call container_script_start first"
        return 1
    fi

    container shell-script --content "$CONTAINER_SCRIPT_CONTENT" "$@"
    local exit_code=$?

    CONTAINER_SCRIPT_CONTENT=""
    return $exit_code
}
