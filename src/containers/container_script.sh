#!/usr/bin/env bash

# Alias: CONTAINER_SCRIPT
# Description: Opens an inline shell script block, capturing all following lines
#              into the global variable $script until CONTAINER_SCRIPT_EOD appears
#              alone on a line.
#
# How it works:
#   Expands to a command-group redirect:
#     { IFS= read -r -d "" script || true; } <<CONTAINER_SCRIPT_EOD
#   The closing } is embedded in the alias expansion, so no extra token is
#   needed after the delimiter. Bash's heredoc parser matches the literal string
#   CONTAINER_SCRIPT_EOD to close the block — alias expansion never occurs
#   inside a heredoc body, so the closing marker must be the literal delimiter.
#   IFS= read -r -d "" reads all heredoc content (preserving every newline and
#   leading whitespace) into $script; read returns 1 on EOF instead of the null
#   byte delimiter, and || true suppresses that non-zero exit status.
#
# Globals:
#   script (write): Set to the full text of the inline script block.
#
# Returns:
#   0 - Always (the inner read's EOF exit-1 is suppressed with || true).
#
# Examples:
#   CONTAINER_SCRIPT
#   #!/bin/bash
#   echo hello
#   CONTAINER_SCRIPT_EOD
#
#   container shell-script --name mycontainer --path /opt/hello.sh
# shellcheck disable=SC2142
alias CONTAINER_SCRIPT='{ IFS= read -r -d "" script || true; } <<CONTAINER_SCRIPT_EOD'

# Alias: CONTAINER_SCRIPT_EOD
# Description: Marks the end of a CONTAINER_SCRIPT block.
#
# How it works:
#   This alias is functionally inert — its expansion is never evaluated.
#   Bash's heredoc parser reads lines literally (no alias expansion) and
#   terminates the heredoc when it sees the delimiter string
#   CONTAINER_SCRIPT_EOD alone on a line. The alias definition exists solely
#   for discoverability: it signals to readers and tooling that
#   CONTAINER_SCRIPT and CONTAINER_SCRIPT_EOD are a matched pair.
#
# Examples:
#   CONTAINER_SCRIPT
#   #!/bin/bash
#   echo hello
#   CONTAINER_SCRIPT_EOD
# shellcheck disable=SC2142
alias CONTAINER_SCRIPT_EOD=':'
