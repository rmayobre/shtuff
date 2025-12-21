<p align="center">
  <img alt="Shtuff logo" src="assets/logo.png" height=300 />
</p>

Shell stuff - A collection of scripts for everyday use while making shell scripts.

# Sourcing Code

## Source locally

Use `git` to clone this repo's main branch and source the `shtuff.sh` file to your script.

```bash
git clone https://github.com/rmayobre/shtuff.git
```

Source the scripts locally in your script:

```bash
#!/bin/bash

source ./shtuff/shtuff.sh # or where ever you cloned the project.

# Now you can build some cool shtuff

install htop curl nano   # Install package(s)
update                   # Update packages and cache
uninstall htop curl nano # Remove package(s)
clean                    # Cleanup unused packages and cache
```

Custom shell scripts can reference this repo on it's main branch by sourcing the raw `shtuff-remote.sh` shell file.

## Source Remotely

### Source Latest

This will result in always sourcing the latest release. Latest can carry breaking changes. Use with caution.

```bash
#!/bin/bash

source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

# Now you can build some cool shtuff

install htop curl nano   # Install package(s)
update                   # Update packages and cache
uninstall htop curl nano # Remove package(s)
clean                    # Cleanup unused packages and cache
```

### Source by Release

```bash
source <(curl -sL https://github.com/rmayobre/shtuff/releases/shtuff.sh.gz | gunzip)

# Now you can build some cool shtuff

install htop curl nano   # Install package(s)
update                   # Update packages and cache
uninstall htop curl nano # Remove package(s)
clean                    # Cleanup unused packages and cache
```

### Caching Remote Source - Optional

Optionally, you can cache a release of shtuff by extracting the release into a specific directory. "tmp" is a good location as your 
system will delete these files after reboots. Choose a different location if you want to keep the files longer.

```bash
# 1. Download and decompress only if the file doesn't exist
[[ ! -f "/tmp/shtuff/shtuff.sh" ]] && curl -sL "https://github.com/rmayobre/shtuff/releases/shtuff.sh.gz" | gunzip > "/tmp/shtuff/"

# 2. Source the file from the local tmp directory
source "/tmp/shtuff/shtuff.sh"

# Now you can build some cool shtuff

install htop curl nano   # Install package(s)
update                   # Update packages and cache
uninstall htop curl nano # Remove package(s)
clean                    # Cleanup unused packages and cache
```

## Source Forks

Just fork the project and write your scripts in the same repository. NOTE: update the base URL defined in the `shtuff-remote.sh` file.

# Functions

The available functions to build with.

# Package Management

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

install htop curl nano   # Install package(s)
update                   # Update packages and cache
uninstall htop curl nano # Remove package(s)
clean                    # Cleanup unused packages and cache
```

# Loading Indicator

Monitor the progress of a background task.

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

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

Logging progress into the terminal and/or file with levels and timestamps.

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

LOG_LEVEL=$DEBUG_LEVEL        # Log everything (default: INFO_LEVEL)
LOG_FILE="/tmp/logs/test.log" # Log into this file (default: does not log to files)
LOG_TIMESTAMP=true            # Log with timestamps (default: true)

error "This is an error level message."
warn "This is an warning level message."
info "This is an info level message."
debug "This is an debug level message."
```

## Systemd

Create a `.service` file for systemd to manage.

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)\

# Create a simple python app
service \
    --name "myapp" \
    --description "My Sample Application" \
    --exec-start "/usr/bin/python3 /opt/myapp/main.py" \
    --user "myuser" \
    --working-directory "/opt/myapp" \
    --environment "PORT=8080 DEBUG=false" \
    --restart "always"

# Start service
systemctl daemon-reload
systemctl enable myapp.service
systemctl start myapp.service
```
