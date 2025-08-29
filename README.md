<p align="center">
  <img alt="Shtuff logo" src="assets/logo.png" height=300 />
</p>

Shell stuff - A collection of scripts for everyday use while making shell scripts.

# How to source these scripts

These scripts can be accessed via three methods: locally sourced, remote sourced, and forking.

## Local Source

Use `git` to clone this repo's main branch and source the `shtuff.sh` file to your script.

```bash
git clone https://github.com/rmayobre/shtuff.git
```

Source the scripts locally in your script:

```bash
#!/bin/bash

source ./shtuff/shtuff.sh # or where ever you cloned the project.

# Now you have access to all my shtuff

install htop curl nano   # Install package(s)
update                   # Update packages and cache
uninstall htop curl nano # Remove package(s)
clean                    # Cleanup unused packages and cache
```

Custom shell scripts can reference this repo on it's main branch by sourcing the raw `shtuff-remote.sh` shell file.

## Remote Source

```bash
#!/bin/bash

source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

# Now you have access to all my shtuff

install htop curl nano   # Install package(s)
update                   # Update packages and cache
uninstall htop curl nano # Remove package(s)
clean                    # Cleanup unused packages and cache
```

## Forking

Just fork the project and write your scripts in the same repository. NOTE: update the base URL defined in the `shtuff-remote.sh` file.

# Tools

The available tools to build with.

# Package Management

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)\

install htop curl nano   # Install package(s)
update                   # Update packages and cache
uninstall htop curl nano # Remove package(s)
clean                    # Cleanup unused packages and cache
```

# Loading Indicator

Monitor the progress of a background task.

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)\

DEFAULT_LOADING_STYLE=$SPINNER_LOADING_STYLE

sleep 5 &
background_pid=$!
monitor $background_pid \
    --style $BARS_LOADING_STYLE \
    --message "This processing is loading" \
    --success_msg "Process is done" \
    --error_msg "Failed to complete"
```

## Logging

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)\

LOG_LEVEL=$DEBUG_LEVEL        # Log everything (default: INFO_LEVEL)
LOG_FILE="/tmp/logs/test.log" # Log into this file (default: does not log to files)
LOG_TIMESTAMP=true            # Log with timestamps (default: true)

error "This is an error level message."
warn "This is an warning level message."
info "This is an info level message."
debug "This is an debug level message."
```
