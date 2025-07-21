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
uninstall htop curl nano # Remove package(s)
clean                    # Cleanup unused packages and cache
```

## Forking

Just fork the project and write your scripts in the same repository.
