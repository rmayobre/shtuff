#!/usr/bin/env bash

# Function: _container_dist_release_prompt
# Description: Interactively prompts the user to select a distribution
#              (Debian or Ubuntu) and then one of that distribution's latest
#              three releases. Intended to be called by other container
#              creation/prompt functions which declare local 'dist' and
#              'release' variables — this function relies on bash's dynamic
#              scoping to assign directly into those caller-local variables.
#
# Arguments:
#   None
#
# Globals:
#   dist (write): Set to the caller's local 'dist' variable to "debian" or "ubuntu".
#   release (write): Set to the caller's local 'release' variable to the chosen release codename.
#   answer (write): Overwritten by each internal 'options' call.
#
# Returns:
#   0 - Always.
#
# Examples:
#   local dist="" release=""
#   _container_dist_release_prompt
function _container_dist_release_prompt {
    options "Distribution:" \
        --choice "debian" \
        --choice "ubuntu"
    dist="$answer"

    case "$dist" in
        ubuntu)
            options "Release:" \
                --choice "noble" \
                --choice "jammy" \
                --choice "focal"
            ;;
        *)
            options "Release:" \
                --choice "trixie" \
                --choice "bookworm" \
                --choice "bullseye"
            ;;
    esac
    release="$answer"
}
