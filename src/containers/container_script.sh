#!/usr/bin/env bash

# Alias: CONTAINER_SCRIPT
# Description: Opens a heredoc assignment into the 'script' variable. Used as
#              the opening bracket of a multi-line shell script string.
#              Close the heredoc with CONTAINER_SCRIPT_EOD on its own line.
#
# Examples:
#   CONTAINER_SCRIPT
#   #!/bin/bash
#   echo hello
#   CONTAINER_SCRIPT_EOD
#
#   container shell-script --name mycontainer --content "$script" --path /opt/hello.sh
# shellcheck disable=SC2142
alias CONTAINER_SCRIPT='script=$(cat <<EOF'

# Alias: CONTAINER_SCRIPT_EOD
# Description: Closes the heredoc assignment opened by CONTAINER_SCRIPT.
#
# Examples:
#   CONTAINER_SCRIPT
#   #!/bin/bash
#   echo hello
#   CONTAINER_SCRIPT_EOD
# shellcheck disable=SC2142
alias CONTAINER_SCRIPT_EOD='EOF)'
