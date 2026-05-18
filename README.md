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

## Release Source

Source a pinned, stable version by downloading a specific release tarball from GitHub
Releases. This avoids pulling from `main` and gives you reproducible, version-locked
behaviour.

```bash
#!/bin/bash

VERSION="v1.0.0"  # pin to the release tag you want
SHTUFF_TMP="/tmp/shtuff-${VERSION}"

mkdir -p "${SHTUFF_TMP}"
curl -sL "https://github.com/rmayobre/shtuff/releases/download/${VERSION}/shtuff-${VERSION}.tar.gz" \
    | tar -xz -C "${SHTUFF_TMP}"

source "${SHTUFF_TMP}/shtuff.sh"

# Now you have access to all my shtuff (pinned to the chosen version)

install htop curl nano   # Install package(s)
update                   # Update packages and cache
uninstall htop curl nano # Remove package(s)
clean                    # Cleanup unused packages and cache
```

The tarball is extracted into a temporary directory, and `shtuff.sh` is sourced from
there. Because `shtuff.sh` resolves the `src/` files relative to its own location, all
utilities are available immediately after the `source` line.

## Latest Release Source

Source the latest stable release automatically. This pattern checks whether a
local copy of shtuff already exists, compares its version against the latest
GitHub release, and downloads a fresh copy only when the local one is missing
or out of date.

```bash
#!/bin/bash

SHTUFF_LOCAL="${HOME}/.local/share/shtuff"
SHTUFF_REPO="rmayobre/shtuff"

# Resolve the latest release tag from GitHub
LATEST_VERSION=$(curl -sL "https://api.github.com/repos/${SHTUFF_REPO}/releases/latest" \
    | grep '"tag_name"' | cut -d'"' -f4)

# Read the version embedded in the local copy (if one exists)
LOCAL_VERSION=""
if [[ -f "${SHTUFF_LOCAL}/shtuff.sh" ]]; then
    LOCAL_VERSION=$(grep -m1 'SHTUFF_VERSION=' "${SHTUFF_LOCAL}/shtuff.sh" \
        | cut -d'"' -f2)
fi

# Download when no local copy is found or it is behind the latest release
if [[ -z "${LOCAL_VERSION}" || "${LOCAL_VERSION}" != "${LATEST_VERSION}" ]]; then
    mkdir -p "${SHTUFF_LOCAL}"
    curl -sL "https://github.com/${SHTUFF_REPO}/releases/download/${LATEST_VERSION}/shtuff-${LATEST_VERSION}.tar.gz" \
        | tar -xz -C "${SHTUFF_LOCAL}"
fi

source "${SHTUFF_LOCAL}/shtuff.sh"

# Now you have access to all my shtuff (always on the latest release)

install htop curl nano   # Install package(s)
update                   # Update packages and cache
uninstall htop curl nano # Remove package(s)
clean                    # Cleanup unused packages and cache
```

The local copy is kept in `~/.local/share/shtuff/` and reused across script
runs. Only one network round-trip (to the GitHub API) is needed on subsequent
runs when the local copy is already current — the tarball is not re-downloaded.

## Forking

Just fork the project and write your scripts in the same repository. NOTE: update the base URL defined in the `shtuff-remote.sh` file.

---

# Public API Reference

All functions documented here are part of the stable public API. Functions prefixed
with `_` are private internal helpers and must not be called directly.

---

## Logging

Structured terminal logging with level filtering, optional file output, and
automatic colorization.

### Configuration

These environment variables can be set before sourcing or at any point in your
script to control logging behavior.

| Variable        | Default        | Description |
|-----------------|----------------|-------------|
| `LOG_LEVEL`     | `info`         | Logging threshold. Messages below this level are suppressed. Accepted values: `error`, `warn`, `info`, `debug`. |
| `LOG_FILE`      | _(empty)_      | When set to a file path, all log messages are also appended to that file (directory is created automatically). |
| `LOG_TIMESTAMP` | `true`         | Include a `YYYY-MM-DD HH:MM:SS` timestamp prefix on every message. Set to `false` to omit it. |

Level constants that can be assigned to `LOG_LEVEL`:

| Constant       | Value     |
|----------------|-----------|
| `ERROR_LEVEL`  | `"error"` |
| `WARN_LEVEL`   | `"warn"`  |
| `INFO_LEVEL`   | `"info"`  |
| `DEBUG_LEVEL`  | `"debug"` |

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

LOG_LEVEL=$DEBUG_LEVEL        # Log everything (default: INFO_LEVEL)
LOG_FILE="/tmp/logs/test.log" # Log into this file (default: does not log to files)
LOG_TIMESTAMP=true            # Log with timestamps (default: true)
```

### `error`

Logs a message at **error** level. Always emitted regardless of `LOG_LEVEL`.
Output is colored **red** on a TTY.

```
error MESSAGE...
```

```bash
error "Database connection failed"
error "Required file not found:" "$path"
```

### `warn`

Logs a message at **warn** level. Suppressed when `LOG_LEVEL` is `error`.
Output is colored **yellow** on a TTY.

```
warn MESSAGE...
```

```bash
warn "Configuration file not found, using defaults"
warn "Deprecated flag used:" "$flag"
```

### `info`

Logs a message at **info** level. Suppressed when `LOG_LEVEL` is `error` or
`warn`. Output is colored **green** on a TTY.

```
info MESSAGE...
```

```bash
info "Application started successfully"
info "Listening on port" "$port"
```

### `debug`

Logs a message at **debug** level. Only emitted when `LOG_LEVEL=debug`.
Output is colored **cyan** on a TTY.

```
debug MESSAGE...
```

```bash
debug "Processing user ID: 12345"
debug "Resolved path:" "$path"
```

### `log`

Low-level logging function called by the convenience wrappers above. Use
`error`/`warn`/`info`/`debug` in scripts; call `log` directly only when you
need to pass a dynamic level.

```
log LEVEL MESSAGE...
```

| Argument   | Type   | Required | Description |
|------------|--------|----------|-------------|
| `LEVEL`    | string | yes      | One of `error`, `warn`, `info`, `debug`. |
| `MESSAGE…` | string | yes      | Message text; multiple arguments are joined with spaces. |

**Returns:** `0` on success; `1` if the level is missing, invalid, or the message is empty.

```bash
log "info"  "Application started"
log "error" "Failed to connect to database"
log "debug" "Resolved path:" "$resolved"
```

---

## Package Management

Auto-detects the system package manager (apt, dnf, yum, zypper, pacman, apk)
and delegates to the appropriate backend. Never hard-code package manager
commands in your scripts — use these functions instead.

### `install`

Installs one or more packages using the detected package manager.

```
install PACKAGE...
```

| Argument     | Type   | Required | Description |
|--------------|--------|----------|-------------|
| `PACKAGE…`   | string | yes      | One or more package names to install. |

**Returns:** `0` on success; `1` if no packages were specified or no supported package manager was found.

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

install curl
install nodejs npm unzip
```

Run in the background and monitor with a loading indicator:

```bash
install nodejs npm &
monitor $! \
    --style "$SPINNER_LOADING_STYLE" \
    --message "Installing dependencies" \
    --success_msg "Done!" \
    --error_msg "Installation failed!" || exit 1
```

### `update`

Updates all installed packages using the detected package manager. Accepts no arguments.

```
update
```

**Returns:** `0` on success; `1` if no supported package manager was found.

```bash
update &
monitor $! \
    --style "$DOTS_LOADING_STYLE" \
    --message "Updating system packages" \
    --success_msg "System up to date" \
    --error_msg "Update failed" || exit 1
```

### `uninstall`

Removes one or more packages using the detected package manager.

```
uninstall PACKAGE...
```

| Argument     | Type   | Required | Description |
|--------------|--------|----------|-------------|
| `PACKAGE…`   | string | yes      | One or more package names to remove. |

**Returns:** `0` on success; `1` if no packages were specified or no supported package manager was found.

```bash
uninstall nginx
uninstall nodejs npm
```

### `clean`

Removes orphaned packages and cleans the package cache using the detected package manager.

```
clean
```

**Returns:** `0` on success; `1` if no supported package manager was found.

```bash
clean
```

---

## Background Process Monitoring

### `monitor`

Monitors a background process by PID, displaying an animated loading indicator
while it runs, then printing a success or error message based on its exit code.
Always run the command with `&` first and then pass `$!` to `monitor`.

```
monitor PID [OPTIONS]
```

| Argument / Option          | Type    | Required | Default              | Description |
|----------------------------|---------|----------|----------------------|-------------|
| `PID`                      | integer | yes      | —                    | PID of the background process to watch. |
| `--message MSG` / `-m MSG` | string  | no       | `"Processing"`       | Text shown beside the loading indicator. |
| `--style STYLE` / `-s STYLE` | string | no      | `$DEFAULT_LOADING_STYLE` | Animation style (see table below). |
| `--success_msg MSG` / `-sm MSG` | string | no   | `"Process completed"` | Message printed on success (exit 0). |
| `--error_msg MSG` / `-e MSG`  | string | no    | `"Process failed"`   | Message printed on failure (non-zero exit). |

**Loading style constants:**

| Constant                | Style      | Description |
|-------------------------|------------|-------------|
| `$SPINNER_LOADING_STYLE` | `spinner`  | Braille spinner (default) |
| `$DOTS_LOADING_STYLE`    | `dots`     | Cycling dots (`...`) |
| `$BARS_LOADING_STYLE`    | `bars`     | Growing block bars |
| `$ARROWS_LOADING_STYLE`  | `arrows`   | Rotating arrows |
| `$CLOCK_LOADING_STYLE`   | `clock`    | Clock emoji sequence |

**Returns:** `0` if the process exited successfully; the process's exit code otherwise.
Always append `|| exit 1` to propagate failures.

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

# Default spinner style
some_long_command &
monitor $! \
    --message "Doing something" \
    --success_msg "Done!" \
    --error_msg "Failed!" || exit 1

# Custom style with short flags
download_file &
monitor $! -s "$DOTS_LOADING_STYLE" -m "Downloading" || exit 1

# Change the default style for all subsequent monitor calls
DEFAULT_LOADING_STYLE=$BARS_LOADING_STYLE
```

### `stop`

Sends a `SIGTERM` to a background process and waits for it to exit.

```
stop PID
```

| Argument | Type    | Required | Description |
|----------|---------|----------|-------------|
| `PID`    | integer | yes      | PID of the background process to terminate. |

**Returns:** `0` on success; `1` if no PID was provided; the exit code of `kill` or `wait` if either fails.

```bash
some_command &
bg_pid=$!

# ... do other work ...

stop "$bg_pid"
```

---

## File Operations

`copy`, `move`, and `delete` each display an animated loading indicator while
the underlying operation runs. When more than one source or target is given,
a pinned progress bar is shown above the per-item indicators.

Always append `|| exit 1` to propagate failures.

### `copy`

Copies one or more source files or directories to a destination. Directories are
detected automatically and copied recursively (`cp -r`).

```
copy [OPTIONS] SOURCE... DEST
```

| Argument / Option           | Type   | Required | Default              | Description |
|-----------------------------|--------|----------|----------------------|-------------|
| `SOURCE… DEST`              | string | yes      | —                    | All positional paths. The last is the destination; all others are sources. |
| `--style STYLE` / `-s STYLE` | string | no      | `$DEFAULT_LOADING_STYLE` | Loading indicator style. |
| `--message MSG` / `-m MSG`  | string | no       | `"Copying"`          | Label shown in the progress bar and per-item indicator. |

**Returns:** `0` if all items were copied; `1` if fewer than two paths were provided or `cp` failed.

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

# Copy a single file
copy /tmp/app.zip /opt/app/ || exit 1

# Copy multiple config files into a directory
copy config.json settings.yaml env.conf /etc/myapp/ || exit 1

# Copy a directory
copy src/ /tmp/staging/ || exit 1

# Custom style and label
copy --style dots --message "Deploying" dist/ /var/www/html/ || exit 1
```

> **Note:** To clear the *contents* of a directory without removing the directory
> itself, use `rm -rf "${DIR:?}"/*` directly — `copy` (and `delete`) operate on
> the path itself, not its contents.

### `move`

Moves one or more source files or directories to a destination.

```
move [OPTIONS] SOURCE... DEST
```

| Argument / Option           | Type   | Required | Default              | Description |
|-----------------------------|--------|----------|----------------------|-------------|
| `SOURCE… DEST`              | string | yes      | —                    | All positional paths. The last is the destination; all others are sources. |
| `--style STYLE` / `-s STYLE` | string | no      | `$DEFAULT_LOADING_STYLE` | Loading indicator style. |
| `--message MSG` / `-m MSG`  | string | no       | `"Moving"`           | Label shown in the progress bar and per-item indicator. |

**Returns:** `0` if all items were moved; `1` if fewer than two paths were provided or `mv` failed.

```bash
# Move a build artifact to a publish directory
move dist/ /srv/releases/v2.0/ || exit 1

# Move multiple log files into an archive directory
move app.log error.log debug.log /var/log/archive/ || exit 1

# Custom style and label
move --style bars --message "Archiving" monday.tar tuesday.tar /mnt/backup/ || exit 1
```

### `delete`

Removes one or more files or directories. Directories are detected automatically
and removed recursively (`rm -rf`).

```
delete [OPTIONS] TARGET...
```

| Argument / Option           | Type   | Required | Default              | Description |
|-----------------------------|--------|----------|----------------------|-------------|
| `TARGET…`                   | string | yes      | —                    | One or more paths to remove. |
| `--style STYLE` / `-s STYLE` | string | no      | `$DEFAULT_LOADING_STYLE` | Loading indicator style. |
| `--message MSG` / `-m MSG`  | string | no       | `"Deleting"`         | Label shown in the progress bar and per-item indicator. |

**Returns:** `0` if all items were removed; `1` if no targets were provided or `rm` failed.

```bash
# Delete a single temporary file
delete /tmp/myapp.zip || exit 1

# Delete a temporary directory (detected and removed recursively)
delete /tmp/myapp_extract || exit 1

# Delete multiple items at once
delete /tmp/myapp.zip /tmp/myapp_extract || exit 1

# Custom style and label
delete --style dots --message "Cleaning up" /tmp/myapp_extract /tmp/myapp.zip || exit 1
```

---

## Systemd

### `service`

Generates a systemd `.service` unit file and writes it to disk. The `.service`
extension is appended automatically if omitted from `--name`. After calling
`service`, always run `daemon-reload`, `enable`, and `start`.

```
service --name NAME --description DESC --exec-start COMMAND [OPTIONS]
```

| Option / Short            | Type    | Required | Default              | Description |
|---------------------------|---------|----------|----------------------|-------------|
| `--name NAME` / `-n`      | string  | yes      | —                    | Service name. `.service` is appended if absent. |
| `--description DESC` / `-d` | string | yes    | —                    | Human-readable description for the `[Unit]` section. |
| `--exec-start CMD` / `-e` | string  | yes      | —                    | Full command used to start the service. |
| `--working-directory DIR` / `-w` | string | no | —               | Working directory for the service process. |
| `--user USER` / `-u`      | string  | no       | —                    | System user the process runs as. |
| `--group GROUP` / `-g`    | string  | no       | —                    | System group the process runs as. |
| `--restart POLICY` / `-r` | string  | no       | `on-failure`         | Systemd restart policy (e.g. `always`, `on-failure`, `no`). |
| `--restart-sec SECS`      | integer | no       | `5`                  | Seconds to wait before restarting. |
| `--wanted-by TARGET`      | string  | no       | `multi-user.target`  | Systemd install target. |
| `--environment ENV`       | string  | no       | —                    | Space-separated `VAR=value` pairs added as `Environment=` lines. |
| `--exec-start-pre CMD`    | string  | no       | —                    | Command to run before `ExecStart`. |
| `--exec-stop CMD`         | string  | no       | —                    | Command to run when stopping the service. |
| `--output-dir DIR` / `-o` | string  | no       | `/etc/systemd/system` | Directory to write the unit file into. |

**Returns:** `0` on success; `1` if a required argument is missing or an unknown option is provided.

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

# Create a simple Python app service
service \
    --name "myapp" \
    --description "My Sample Application" \
    --exec-start "/usr/bin/python3 /opt/myapp/main.py" \
    --user "myuser" \
    --working-directory "/opt/myapp" \
    --environment "PORT=8080 DEBUG=false" \
    --restart "always" || exit 1

# Enable and start the service
systemctl daemon-reload
systemctl enable myapp.service
systemctl start myapp.service
```

```bash
# Node.js API server with pre-start hook
service \
    --name "api-server" \
    --description "API Server" \
    --exec-start "/usr/local/bin/api-server" \
    --user "apiuser" \
    --environment "PORT=8080 NODE_ENV=production" \
    --restart "always" \
    --restart-sec "10" \
    --exec-start-pre "/usr/local/bin/api-server --check-config" || exit 1

systemctl daemon-reload
systemctl enable api-server.service
systemctl start api-server.service
```

### `timer`

Generates a systemd `.timer` unit file with configurable scheduling options.
The `.timer` extension is added automatically. Use alongside a matching `.service`
unit (created with `service`).

```
timer --name NAME [SCHEDULING OPTIONS] [OPTIONS]
```

**Required:**

| Option / Short       | Type   | Required | Description |
|----------------------|--------|----------|-------------|
| `--name NAME` / `-n` | string | yes      | Timer name (without `.timer`). Letters, numbers, hyphens, and underscores only. |

**Scheduling options** (at least one is recommended):

| Option / Short                        | Type   | Description |
|---------------------------------------|--------|-------------|
| `--on-calendar SPEC` / `-c`           | string | Calendar expression, e.g. `daily`, `*-*-* 02:00:00`. |
| `--on-boot-sec TIME` / `-b`           | string | Time after boot before first activation, e.g. `5min`, `1h`. |
| `--on-unit-active-sec TIME` / `-a`    | string | Interval after last activation, e.g. `1h`. |
| `--on-unit-inactive-sec TIME` / `-i`  | string | Interval after last deactivation, e.g. `30min`. |

**Timer options:**

| Option / Short                  | Type   | Default              | Description |
|---------------------------------|--------|----------------------|-------------|
| `--description DESC` / `-d`     | string | `"Timer for <name>"` | Human-readable description. |
| `--unit NAME` / `-u`            | string | `<name>.service`     | Service unit to activate. |
| `--randomized-delay TIME` / `-r` | string | —                   | Random delay added to the scheduled time, e.g. `30min`. |
| `--persistent` / `-p`           | flag   | off                  | Catch up on missed runs at next boot. |
| `--wanted-by TARGET` / `-w`     | string | `timers.target`      | Systemd install target. |
| `--output-dir DIR` / `-o`       | string | `/etc/systemd/system` | Directory to write the unit file into. |
| `--force` / `-f`                | flag   | off                  | Overwrite an existing timer file. |
| `--help` / `-h`                 | flag   | —                    | Print usage information and return. |

**Returns:** `0` on success or when `--help` is requested; `1` for invalid or missing arguments; `2` for file system errors (missing output directory or file exists without `--force`); `3` for permission denied.

**Calendar expression examples:**

| Expression              | Meaning |
|-------------------------|---------|
| `hourly`                | Every hour |
| `daily`                 | Every day at midnight |
| `weekly`                | Every Monday at midnight |
| `monthly`               | First day of each month at midnight |
| `*-*-* 06:00:00`        | Daily at 6:00 AM |
| `Mon,Fri *-*-* 18:30:00` | Monday and Friday at 6:30 PM |
| `*-*-* *:00/15:00`      | Every 15 minutes |

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

# Daily backup timer at 2 AM, catching up on missed runs
timer \
    --name "myapp-backup" \
    --description "Daily backup" \
    --on-calendar "*-*-* 02:00:00" \
    --persistent || exit 1

systemctl daemon-reload
systemctl enable myapp-backup.timer
systemctl start myapp-backup.timer
```

```bash
# Run 5 minutes after boot, then every hour
timer \
    --name "cleanup" \
    --description "Periodic cleanup" \
    --on-boot-sec "5min" \
    --on-unit-active-sec "1h" || exit 1

# Weekly maintenance on Sunday at 3 AM with a random delay
timer \
    --name "maintenance" \
    --on-calendar "Sun *-*-* 03:00:00" \
    --randomized-delay "30min" \
    --persistent || exit 1
```

---

## Progress Bar

### `progress`

Draws or updates a progress bar in-place on the current terminal line. Calling
it repeatedly with increasing `--current` values animates the bar. Used
internally by `copy`, `move`, and `delete` but available for direct use.

```
progress --current N --total N [OPTIONS]
```

| Option / Short             | Type    | Required | Default      | Description |
|----------------------------|---------|----------|--------------|-------------|
| `--current N` / `-c N`     | integer | yes      | —            | Current step (0 to `--total`). |
| `--total N` / `-t N`       | integer | yes      | —            | Total steps, representing 100%. |
| `--message MSG` / `-m MSG` | string  | no       | `"Progress"` | Label printed before the bar. |
| `--width N` / `-w N`       | integer | no       | `40`         | Number of fill characters in the bar. |
| `--lines-above N` / `-l N` | integer | no       | `0`          | Move cursor up N lines before drawing, then restore. Used to keep the bar pinned above scrolling output. |
| `--done` / `-d`            | flag    | no       | off          | Force a trailing newline, finalizing the bar. Implied when `--current` equals `--total`. |

**Returns:** `0` on success; `1` if required arguments are missing, non-numeric, or `--current` exceeds `--total`.

**Visual output:**

```
Downloading [████████████████░░░░░░░░░░░░░░░░░░░░░░░░]  40% ( 4/10)
```

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

files=(file1.txt file2.txt file3.txt file4.txt file5.txt)
total=${#files[@]}

for i in "${!files[@]}"; do
    process_file "${files[$i]}"
    progress --current $(( i + 1 )) --total "$total" --message "Processing files"
done
```

---

## Forms

Interactive terminal prompts that store user input in the global variable
`answer`. Read `$answer` immediately after calling either function.

### `question`

Displays a prompt string and reads a single line of free-form text from the
user, storing the result in `$answer`.

```
question PROMPT
```

| Argument | Type   | Required | Description |
|----------|--------|----------|-------------|
| `PROMPT` | string | yes      | Text displayed to the user before the input cursor. |

**Globals written:** `answer` — set to the string the user entered.

**Returns:** `0` on success; `1` if no prompt argument was provided.

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

question "What is your name?"
echo "Hello, $answer!"

question "Which port should the server listen on?"
PORT="$answer"
```

### `options`

Displays a numbered list of choices, prompts the user to select one by
number, re-prompts on invalid input, and stores the selected value in
`$answer`.

```
options PROMPT --choice VALUE [--choice VALUE ...]
```

| Argument / Option       | Type   | Required   | Description |
|-------------------------|--------|------------|-------------|
| `PROMPT`                | string | yes        | Question text displayed above the numbered list. |
| `--choice VALUE`        | string | yes (×1+)  | A choice to add to the list. Repeat for each option; order is preserved. |

**Globals written:** `answer` — set to the text of the choice the user selected (not the number).

**Returns:** `0` on success; `1` if the prompt is missing, an unknown flag is passed, or no `--choice` values are provided.

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

options "What would you like to do?" \
    --choice "Install" \
    --choice "Update" \
    --choice "Exit"
echo "You chose: $answer"

options "Select an environment:" \
    --choice "development" \
    --choice "staging" \
    --choice "production"
DEPLOY_ENV="$answer"
```

**Example terminal output:**

```
What would you like to do?
  1) Install
  2) Update
  3) Exit
Enter number [1-3]:
```

### `confirm`

Displays a yes/no question, stores `"yes"` or `"no"` in `$answer`, and
returns `0` for yes or `1` for no. Can be used as an `if` condition directly.
Uses whiptail if available; falls back to a `[y/n]` terminal prompt.

```
confirm PROMPT
```

| Argument | Type   | Required | Description |
|----------|--------|----------|-------------|
| `PROMPT` | string | yes      | The yes/no question displayed to the user. |

**Globals written:** `answer` — set to `"yes"` or `"no"`.

**Returns:** `0` if the user answered yes; `1` if no; `2` if no prompt was provided.

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

# Use as a condition
if confirm "Overwrite existing files?"; then
    copy src/ dest/ || exit 1
fi

# Inspect $answer
confirm "Enable debug logging?"
echo "You chose: $answer"
```

**Example terminal output:**

```
Overwrite existing files? [y/n]:
```

---

## Networking

### `download`

Downloads a file from a URL using `curl` (or `wget` as a fallback), displaying
a loading indicator during the transfer.

```
download --url URL [OPTIONS]
```

| Option / Short             | Type   | Required | Default              | Description |
|----------------------------|--------|----------|----------------------|-------------|
| `--url URL`                | string | yes      | —                    | URL of the file to download. |
| `--dir DIR`                | string | no       | Calling script's directory | Directory to save the file into; created if it does not exist. |
| `--output NAME`            | string | no       | Basename of URL      | Filename to use when saving. Derived from the URL when omitted. |
| `--style STYLE` / `-s`     | string | no       | `$DEFAULT_LOADING_STYLE` | Loading indicator style. |
| `--message MSG` / `-m`     | string | no       | `"Downloading"`      | Label shown beside the indicator. |

**Returns:** `0` on success; `1` if required arguments are missing, no download tool is available, or the download fails.

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

download --url "https://example.com/archive.zip"
download --url "https://example.com/archive.zip" --dir /tmp
download --url "https://example.com/archive.zip" --dir /opt/myapp --output app.zip
download --url "https://example.com/archive.zip" --style dots --message "Fetching release"
```

### `check_port`

Validates a port number and checks whether it is currently bound on the local host.

```
check_port --port PORT [--dry-run]
```

| Option       | Type    | Required | Description |
|--------------|---------|----------|-------------|
| `--port PORT` | integer | yes     | Port number to check (1–65535). |
| `--dry-run`  | flag    | no       | Print the system calls that would run without executing them. Defaults to `$IS_DRY_RUN`. |

**Returns:** `0` if the port is valid and free; `1` if the port is in use; `2` if the port number is invalid.

```bash
check_port --port 8080
if check_port --port "$PORT"; then
    info "Port $PORT is available"
else
    error "Port $PORT is already in use"
fi
```

### `wait_for_port`

Polls a TCP host:port until it accepts connections or a timeout is reached.
Useful after starting a service to wait until it is ready to accept requests.

```
wait_for_port --host HOST --port PORT [OPTIONS]
```

| Option / Short         | Type    | Required | Default   | Description |
|------------------------|---------|----------|-----------|-------------|
| `--host HOST`          | string  | yes      | —         | Hostname or IP address to probe. |
| `--port PORT`          | integer | yes      | —         | TCP port to probe (1–65535). |
| `--timeout SECONDS`    | integer | no       | `30`      | Maximum seconds to wait before giving up. |
| `--interval SECONDS`   | integer | no       | `2`       | Seconds between each probe attempt. |
| `--style STYLE`        | string  | no       | `spinner` | Loading indicator style. |
| `--dry-run`            | flag    | no       | —         | Print system calls without executing them. |

**Returns:** `0` when the port becomes reachable; `1` for invalid arguments; `2` on timeout.

```bash
# Start a service then wait for it to be ready
systemctl start myapp
wait_for_port --host 127.0.0.1 --port 8080 || exit 1

# Allow more time for a database
wait_for_port --host 10.0.0.5 --port 5432 --timeout 120 --interval 5 || exit 1
```

### `bridge`

Manages Linux bridge interfaces using iproute2. Changes take effect immediately
but are not persistent across reboots without additional network configuration.

```
bridge SUBCOMMAND [OPTIONS]
```

| Subcommand         | Description |
|--------------------|-------------|
| `create`           | Create a new bridge interface. |
| `delete`           | Remove an existing bridge interface. |
| `add-interface`    | Attach a physical interface to a bridge. |
| `remove-interface` | Detach a physical interface from a bridge. |

**create options:**

| Option          | Type   | Required | Description |
|-----------------|--------|----------|-------------|
| `--name NAME`   | string | yes      | Name of the bridge to create. |
| `--ip IP/PREFIX` | string | no      | IP address and prefix length to assign (e.g. `10.0.0.1/24`). |

**delete / add-interface / remove-interface options:**

| Option              | Type   | Required | Description |
|---------------------|--------|----------|-------------|
| `--name NAME`       | string | yes      | Name of the bridge. |
| `--interface IFACE` | string | yes (add/remove) | Network interface to attach or detach. |

**Returns:** `0` on success; `1` for invalid arguments or missing `ip` tool; `2` if the bridge/interface already or does not exist; `3` on operation failure.

```bash
bridge create --name lxcbr0 --ip 10.0.0.1/24
bridge add-interface --name lxcbr0 --interface eth0
bridge remove-interface --name lxcbr0 --interface eth0
bridge delete --name lxcbr0
```

### `forward`

Manages iptables DNAT rules for host-to-container port forwarding and ensures
IP forwarding is enabled in the kernel. Rules are not persistent across reboots
without `iptables-persistent` or an equivalent tool.

```
forward SUBCOMMAND [OPTIONS]
```

| Subcommand | Description |
|------------|-------------|
| `add`      | Add a DNAT forwarding rule. |
| `remove`   | Remove an existing forwarding rule. |
| `list`     | Display all current NAT PREROUTING rules. |

**add options:**

| Option                | Type    | Required | Default              | Description |
|-----------------------|---------|----------|----------------------|-------------|
| `--from-port PORT`    | integer | yes      | —                    | Host port to forward from. |
| `--to-host HOST`      | string  | yes      | —                    | Destination IP (e.g. container IP). |
| `--to-port PORT`      | integer | no       | Same as `--from-port` | Destination port. |
| `--protocol PROTO`    | string  | no       | `tcp`                | Protocol (`tcp` or `udp`). |

**remove options:**

| Option             | Type    | Required | Default | Description |
|--------------------|---------|----------|---------|-------------|
| `--from-port PORT` | integer | yes      | —       | Host port of the rule to remove. |
| `--protocol PROTO` | string  | no       | `tcp`   | Protocol of the rule to remove. |

**Returns:** `0` on success; `1` for invalid arguments or missing `iptables`; `2` if no matching rule is found (remove); `3` on operation failure.

```bash
# Forward host port 8080 to container port 80
forward add --from-port 8080 --to-host 10.0.0.10 --to-port 80

# Forward SSH port to container
forward add --from-port 2222 --to-host 10.0.0.10 --to-port 22

# Forward UDP port
forward add --from-port 5353 --to-host 10.0.0.20 --protocol udp

# Remove a rule and list all rules
forward remove --from-port 8080
forward list
```

### `network` (unified)

Convenience dispatcher that routes subcommands to the appropriate networking
function. All underlying functions are also callable directly.

```
network SUBCOMMAND [OPTIONS]
```

| Subcommand | Delegates to  | Description |
|------------|---------------|-------------|
| `download` | `download`    | Download a file from a URL. |
| `check`    | `check_port`  | Check whether a port is free. |
| `wait`     | `wait_for_port` | Wait until a port is reachable. |
| `bridge`   | `bridge`      | Manage bridge interfaces. |
| `forward`  | `forward`     | Manage iptables forwarding rules. |

```bash
network download --url https://example.com/file.zip --dir /tmp
network check --port 8080
network wait --host 127.0.0.1 --port 8080 --timeout 60
network bridge create --name lxcbr0 --ip 10.0.0.1/24
network forward add --from-port 8080 --to-host 10.0.0.10 --to-port 80
network forward list
```

---

## Containers

Container functions automatically detect whether Proxmox `pct` or plain LXC is
present and delegate to the appropriate backend. The unified `container`
function is the recommended entry point; backend-specific functions
(`lxc_*`, `pct_*`) remain callable directly.

### `container`

Unified interface for creating and managing containers.

```
container SUBCOMMAND --name NAME [OPTIONS]
```

**Subcommands:**

| Subcommand     | Description |
|----------------|-------------|
| `create`       | Create and start a new container. |
| `config`       | Update resource settings on an existing container. |
| `start`        | Start a stopped container. |
| `exec`         | Run a command inside the container non-interactively. |
| `enter`        | Open an interactive shell session inside the container. |
| `push`         | Copy a file from the host into the container. |
| `pull`         | Copy a file out of the container to the host. |
| `delete`       | Destroy a container. |
| `network`      | Configure a container's network interface. |
| `shell-script` | Write an executable shell script into the container. |
| `prompt`       | Interactively collect all creation options, then create. |

**`create` options:**

When `--gpu` is provided, GPU passthrough is configured immediately after the
container is created (see [GPU Passthrough](#gpu-passthrough)).

| Option                  | Type    | Required | Description |
|-------------------------|---------|----------|-------------|
| `--name NAME`           | string  | yes      | Container name / hostname. |
| `--hostname HOSTNAME`   | string  | no       | Hostname inside the container. |
| `--memory MB`           | integer | no       | Memory limit in megabytes. |
| `--cores N`             | integer | no       | Number of CPU cores. |
| `--storage STORAGE`     | string  | no       | Storage pool (PCT) or backing store type (LXC: `dir`, `btrfs`, `zfs`, `overlayfs`). |
| `--disk-size GB`        | integer | no       | Rootfs size in gigabytes. |
| `--password PASSWORD`   | string  | no       | Root password for the container. |
| `--template PATH`       | string  | no       | Template path (PCT) or template name (LXC). |
| `--gpu PCI_ADDR`        | string  | no       | PCI address of a GPU to pass through (e.g. `01:00.0`). Use `gpu_list` to discover addresses. |
| `--pcie`                | flag    | no       | Enable PCIe passthrough mode (`pcie=1`) when using `--gpu` on PCT backends. |

**`exec` options:**

```bash
# Everything after -- is the command run inside the container
container exec --name mycontainer -- bash -c "apt-get update"
```

**`config` options:**

| Option               | Type    | Description |
|----------------------|---------|-------------|
| `--hostname NAME`    | string  | New hostname. |
| `--memory MB`        | integer | New memory limit. |
| `--cores N`          | integer | New CPU core count. |
| `--set KEY=VALUE`    | string  | Set an arbitrary `lxc.*` config key (LXC only, repeatable). |

**`delete` options:**

| Option    | Type | Description |
|-----------|------|-------------|
| `--force` | flag | Stop the container before destroying if it is running. |
| `--purge` | flag | Remove from related configurations and jobs (PCT only). |

**`network` options:**

| Option               | Type   | Default                   | Description |
|----------------------|--------|---------------------------|-------------|
| `--bridge BRIDGE`    | string | `lxcbr0` (LXC) / `vmbr0` (PCT) | Host bridge interface to attach to. |
| `--ip IP/PREFIX`     | string | —                         | Static IP with prefix, e.g. `10.0.0.10/24`. Use `dhcp` on PCT for dynamic assignment. |
| `--gateway GW`       | string | —                         | Default gateway IP. |
| `--dns NAMESERVERS`  | string | —                         | Space-separated DNS IPs (PCT only). |
| `--index N`          | integer | `0`                      | Network interface index. |
| `--type TYPE`        | string | `veth`                    | Interface type: `veth`, `macvlan`, `ipvlan`, `none` (LXC only). |

**`shell-script` options:**

| Option              | Type   | Required | Description |
|---------------------|--------|----------|-------------|
| `--name NAME`       | string | yes      | Container name or VMID. |
| `--path PATH`       | string | yes      | Absolute destination path inside the container. |
| `--content CONTENT` | string | no       | Script text. Defaults to `$script` when omitted (see `CONTAINER_SCRIPT`). |
| `--style STYLE`     | string | no       | Loading indicator style. |
| `--dry-run`         | flag   | no       | Print system calls without executing them. |

**`prompt` globals** (pre-fill values to skip individual prompts):

```bash
CONTAINER_NAME=myapp CONTAINER_MEMORY=1024 container prompt
```

| Environment Variable   | Description |
|------------------------|-------------|
| `CONTAINER_NAME`       | Container name. Skips name prompt if set. |
| `CONTAINER_TEMPLATE`   | Template path (PCT) or template name (LXC). |
| `CONTAINER_DIST`       | Distribution name (LXC only). |
| `CONTAINER_RELEASE`    | Distribution release (LXC only). |
| `CONTAINER_ARCH`       | Architecture (LXC only). |
| `CONTAINER_HOSTNAME`   | Hostname inside the container. |
| `CONTAINER_MEMORY`     | Memory limit in megabytes. |
| `CONTAINER_CORES`      | Number of CPU cores. |
| `CONTAINER_STORAGE`    | Storage pool (PCT) or backing store (LXC). |
| `CONTAINER_DISK_SIZE`  | Root disk size in gigabytes. |
| `CONTAINER_PASSWORD`   | Root password. |
| `CONTAINER_GPU`        | PCI address of GPU to pass through. Skips GPU prompt if set. Use `gpu_list` to find addresses. |
| `CONTAINER_GPU_PCIE`   | Set to `"true"` to enable PCIe passthrough mode on PCT backends. |

**Returns:** `0` on success; `1` for unknown subcommand or missing `--name`; propagates backend exit codes otherwise.

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

# Create a Debian container (LXC)
container create \
    --name myapp \
    --dist debian \
    --release trixie \
    --memory 2048 \
    --cores 4 || exit 1

# Create a PCT container from a downloaded template
container create \
    --name myapp \
    --template "local:vztmpl/debian-13-standard_13.x-1_amd64.tar.zst" \
    --memory 2048 \
    --cores 4 \
    --disk-size 16 || exit 1

# Create an LXC container with GPU passthrough applied automatically after creation
container create \
    --name gpu-workload \
    --dist debian \
    --release trixie \
    --memory 8192 \
    --cores 8 \
    --gpu 01:00.0 || exit 1

# Create a PCT container with PCIe GPU passthrough
container create \
    --name gpu-workload \
    --template "local:vztmpl/debian-13-standard_13.x-1_amd64.tar.zst" \
    --memory 8192 \
    --cores 8 \
    --gpu 01:00.0 \
    --pcie || exit 1

# Run a command inside the container
container exec --name myapp -- bash -c "apt-get update && apt-get install -y curl"

# Open an interactive shell
container enter --name myapp

# Configure a static IP on the container
container network --name myapp --bridge lxcbr0 --ip 10.0.0.10/24 --gateway 10.0.0.1

# Copy files in and out
container push /etc/app.conf /etc/app.conf --name myapp
container pull /var/log/app.log /tmp/app.log --name myapp

# Reconfigure resources
container config --name myapp --memory 2048 --cores 4

# Write a script into the container and make it executable
container shell-script --name myapp \
    --content '#!/bin/bash\necho hello' \
    --path /usr/local/bin/hello.sh

# Delete the container
container delete --name myapp --force
```

### `CONTAINER_SCRIPT` / `CONTAINER_SCRIPT_EOD`

An alias pair that captures an inline multi-line shell script into the global
variable `$script`. The captured text can then be passed to
`container shell-script` (or `lxc_shell_script` / `pct_shell_script` directly)
to deploy the script into a container.

```
CONTAINER_SCRIPT
<script content>
CONTAINER_SCRIPT_EOD
```

After `CONTAINER_SCRIPT_EOD`, `$script` holds the full text of the inline block.
Omit `--content` from `container shell-script` to use `$script` implicitly.

```bash
#!/bin/bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

CONTAINER_SCRIPT
#!/bin/bash
apt-get update -y
apt-get install -y curl git
echo "Setup complete"
CONTAINER_SCRIPT_EOD

# Deploy the captured script into the container
container shell-script --name myapp --path /opt/setup.sh

# Execute it
container exec --name myapp -- /opt/setup.sh
```

> **How it works:** `CONTAINER_SCRIPT` expands to a command-group redirect
> `{ IFS= read -r -d "" script || true; } <<CONTAINER_SCRIPT_EOD`. The
> closing `}` is already inside the alias, so `CONTAINER_SCRIPT_EOD` on its own
> line is the sole closing marker — matched literally by the heredoc parser
> (alias expansion never occurs inside a heredoc body).

---

## Writing Scripts with shtuff

This section shows the recommended structure for installer and updater scripts
that use shtuff as the underlying framework.

### Installer script structure

```bash
#!/usr/bin/env bash
# Purpose: Install <app> on a supported Linux system.
# Usage:   ./install.sh [--port PORT] [--dir DIR]
# Requirements: bash 4+, root or sudo

source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

# ── Constants (never change at runtime) ───────────────────────────────────────
readonly REPO="https://github.com/example/myapp/releases/latest/download/myapp.zip"
readonly SERVICE_NAME="myapp"

# ── Overridable config (can be set via environment or flags) ──────────────────
INSTALL_DIR="${INSTALL_DIR:-/opt/myapp}"
PORT="${PORT:-3000}"

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--port) PORT="$2";        shift 2 ;;
        -d|--dir)  INSTALL_DIR="$2"; shift 2 ;;
        -h|--help) echo "Usage: $0 [--port PORT] [--dir DIR]"; exit 0 ;;
        *)         error "Unknown option: $1"; exit 1 ;;
    esac
done

# ── Root check ────────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || { error "This script must be run as root"; exit 1; }

# ── Step 1: Update system packages ───────────────────────────────────────────
update &
monitor $! \
    --style "$SPINNER_LOADING_STYLE" \
    --message "Updating system packages" \
    --success_msg "Packages updated" \
    --error_msg "Update failed" || exit 1

# ── Step 2: Install dependencies ─────────────────────────────────────────────
install curl unzip nodejs &
monitor $! \
    --style "$DOTS_LOADING_STYLE" \
    --message "Installing dependencies" \
    --success_msg "Dependencies installed" \
    --error_msg "Dependency install failed" || exit 1

# ── Step 3: Download and extract the release ─────────────────────────────────
download --url "$REPO" --dir /tmp --output myapp.zip

mkdir -p /tmp/myapp_extract
unzip -qo /tmp/myapp.zip -d /tmp/myapp_extract &
monitor $! --message "Extracting release" || exit 1

DIST_DIR=$(find /tmp/myapp_extract -type d -name "dist" -maxdepth 4 | head -1)
CONTENT_DIR=$(dirname "${DIST_DIR}")

mkdir -p "${INSTALL_DIR}"
copy "${CONTENT_DIR}/." "${INSTALL_DIR}/" --message "Installing files" || exit 1

delete /tmp/myapp_extract --message "Removing temp files" || exit 1
delete /tmp/myapp.zip || exit 1

# ── Step 4: Create and start the service ─────────────────────────────────────
service \
    --name "$SERVICE_NAME" \
    --description "My Application" \
    --working-directory "$INSTALL_DIR" \
    --exec-start "$(command -v node) $INSTALL_DIR/server.js" \
    --user "www-data" \
    --restart "always" \
    --environment "PORT=$PORT NODE_ENV=production" || exit 1

info "Installation complete. Access the app at http://localhost:${PORT}"
info "Manage the service: systemctl {start|stop|restart|status} ${SERVICE_NAME}"
```

### Updater script structure

```bash
#!/usr/bin/env bash
# Purpose: Update <app> to the latest release.
# Usage:   ./update.sh [--dir DIR]

source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

readonly REPO="https://api.github.com/repos/example/myapp/releases/latest"
readonly SERVICE_NAME="myapp"
INSTALL_DIR="${INSTALL_DIR:-/opt/myapp}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dir) INSTALL_DIR="$2"; shift 2 ;;
        *)        error "Unknown option: $1"; exit 1 ;;
    esac
done

[[ $EUID -eq 0 ]] || { error "This script must be run as root"; exit 1; }

# Fail early if not installed yet
[[ -d "$INSTALL_DIR" ]] || { error "Install directory not found: $INSTALL_DIR"; exit 1; }

# Resolve latest release URL from GitHub API
RELEASE_URL=$(curl -sL "$REPO" | grep '"browser_download_url"' | grep '\.zip' | head -1 | cut -d'"' -f4)
[[ -n "$RELEASE_URL" ]] || { error "Could not resolve release URL"; exit 1; }

download --url "$RELEASE_URL" --dir /tmp --output myapp.zip

mkdir -p /tmp/myapp_extract
unzip -qo /tmp/myapp.zip -d /tmp/myapp_extract &
monitor $! --message "Extracting release" || exit 1

DIST_DIR=$(find /tmp/myapp_extract -type d -name "dist" -maxdepth 4 | head -1)
CONTENT_DIR=$(dirname "${DIST_DIR}")

# Replace existing files in-place (rm -rf contents, then copy; do not use delete
# here — it removes the directory itself, not just its contents)
rm -rf "${INSTALL_DIR:?}"/*
copy "${CONTENT_DIR}/." "${INSTALL_DIR}/" --message "Replacing files" || exit 1

delete /tmp/myapp_extract || exit 1
delete /tmp/myapp.zip || exit 1

systemctl restart "$SERVICE_NAME"
info "Update complete."
```

### Dry-run mode

Set `IS_DRY_RUN=true` before sourcing (or after) to make `check_port`,
`wait_for_port`, `bridge`, `forward`, `container shell-script`, and other
system-mutating functions print the commands they would run without executing
them. Useful for testing scripts in a safe environment.

```bash
IS_DRY_RUN=true
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

check_port --port 8080     # prints: [DRY RUN] ss -tlnp ...
forward add --from-port 8080 --to-host 10.0.0.10 --to-port 80  # prints commands only
```

### Conventions

| Practice | Why |
|----------|-----|
| Always `\|\| exit 1` after `monitor` | Propagate failures; a silent background crash is hard to debug. |
| Use `readonly` for constants | Prevents accidental reassignment mid-script. |
| Use `${VAR:-default}` for config | Lets callers override via environment without editing the script. |
| Download to `/tmp/`, always clean up | Avoids leaving large files behind if the script exits early. |
| Use `rm -rf "${DIR:?}"/*` to clear a directory's contents | The `:?` guard prevents `rm -rf /*` if the variable is empty. Use `delete` for paths that should be fully removed. |
| Full binary paths in `--exec-start` | Systemd does not use `$PATH`; use `$(command -v node)` instead of `node`. |
| Never hard-code a package manager | Always use `install`/`update`/`uninstall` so scripts work across distros. |
| Never call `_` prefixed functions | Private helpers; their signatures may change without notice. |

---

## GPU Passthrough

Functions for discovering host GPUs, interactively selecting one, and installing
hardware-acceleration libraries — on the host or inside a container. GPU passthrough
is also integrated directly into `container create` and `container prompt` via the
`--gpu` flag and `CONTAINER_GPU` environment variable (see [Containers](#containers)).

Requires `pciutils` (`lspci`) on the host for GPU discovery.

### `gpu_list`

Lists all PCI GPU devices detected on the host. Prints each GPU's PCI address,
vendor (NVIDIA / AMD / Intel / Unknown), and full description from `lspci`. Use
this to find the PCI address to pass to `gpu_select`, `container create --gpu`,
or `CONTAINER_GPU`.

```
gpu_list
```

**Returns:** `0` if one or more GPUs were found and listed; `1` if `lspci` is not available; `2` if no GPUs were detected.

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

gpu_list
```

**Example output:**

```
Detected GPU devices:
  [1] 01:00.0  NVIDIA    VGA compatible controller: NVIDIA Corporation GA102 [GeForce RTX 3090] (rev a1)
  [2] 02:00.0  AMD       Display controller: Advanced Micro Devices, Inc. [AMD/ATI] Navi 23 [Radeon RX 6600 XT]
```

### `gpu_select`

Interactively prompts the user to choose a GPU from the host's detected PCI GPU
devices. Uses `whiptail` when available; falls back to a plain numbered terminal
menu. When `--container` is provided, GPU passthrough is automatically configured
on the container after the user makes a selection.

The selected GPU descriptor (`"PCI_ADDR description"`) is always stored in
`$answer` regardless of whether `--container` is given.

```
gpu_select [OPTIONS]
```

| Option | Type | Required | Default | Description |
|--------|------|----------|---------|-------------|
| `--container NAME` | string | no | — | Container name or VMID. When set, applies GPU passthrough to the container after selection (PCT: `pct set --hostpciN`; LXC: appends cgroup/mount-entry lines to the config file). |
| `--index N` | integer | no | `0` | hostpci slot index to use on PCT backends (`--hostpci0`, `--hostpci1`, …). Ignored for LXC. |
| `--pcie` | flag | no | off | Enable PCIe passthrough mode (`pcie=1`) on PCT backends. |
| `--dry-run` | flag | no | `$IS_DRY_RUN` | Print the passthrough commands that would be executed without applying them. |

**Globals written:** `answer` — the full GPU descriptor string of the selected GPU, e.g. `"01:00.0 NVIDIA Corporation GA102 [GeForce RTX 3090] (rev a1)"`.

**Returns:** `0` on success; `1` if `lspci` is unavailable, no GPUs are found, or arguments are invalid; `2` if the container is not found or passthrough configuration fails.

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

# Select a GPU — result stored in $answer
gpu_select
echo "Selected: $answer"

# Select a GPU and immediately configure passthrough on an LXC container
gpu_select --container mycontainer
# Container must be restarted to apply changes

# Select and configure passthrough on a PCT container with PCIe mode
gpu_select --container 100 --pcie

# Assign a second GPU to a container (PCT slot 1)
gpu_select --container 100 --index 1 --pcie

# Preview what would be applied without making changes
gpu_select --container mycontainer --dry-run
```

**Example interactive menu (plain terminal):**

```
Select a GPU for container 'mycontainer'
  1) 01:00.0  [NVIDIA]  VGA compatible controller: NVIDIA Corporation GA102 [GeForce RTX 3090] (rev a1)
  2) 00:02.0  [Intel]   Display controller: Intel Corporation UHD Graphics 630
Enter number [1-2]:
```

### `gpu_install`

Installs hardware-acceleration libraries on the host or inside a container.
Auto-detects the GPU vendor via `lspci` when `--vendor` is omitted. When
`--container` is provided, package manager detection is performed inside the
container so that host and container distros need not match.

```
gpu_install [OPTIONS]
```

| Option | Type | Required | Default | Description |
|--------|------|----------|---------|-------------|
| `--vendor VENDOR` | string | no | auto-detected | GPU vendor. One of `nvidia`, `amd`, `intel`, `generic`. When omitted, detected from `lspci`. |
| `--container NAME` | string | no | — | Container name or VMID to install libraries inside. When omitted, installs on the host. |
| `--style STYLE` | string | no | `$SPINNER_LOADING_STYLE` | Loading indicator style. |
| `--dry-run` | flag | no | `$IS_DRY_RUN` | Print what would be installed without running it. |

**Packages installed by vendor:**

| Vendor | Packages |
|--------|----------|
| `nvidia` | `nvidia-cuda-toolkit`, `nvidia-container-toolkit` |
| `amd` | `rocm-opencl-runtime`, `rocm-hip-runtime` |
| `intel` | `intel-opencl-icd`, `intel-media-va-driver`, `vainfo` |
| `generic` | `ocl-icd-opencl-dev`, `clinfo` |

**Returns:** `0` on success; `1` if arguments are invalid or the vendor is unsupported; `2` if host installation fails; `3` if the container is not found or installation inside the container fails.

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

# Auto-detect vendor and install on the host
gpu_install

# Install NVIDIA libraries on the host
gpu_install --vendor nvidia

# Install AMD libraries inside a container (package manager detected inside the container)
gpu_install --vendor amd --container mycontainer

# Auto-detect vendor and install inside a PCT container
gpu_install --container 100

# Preview what would be installed
gpu_install --vendor intel --dry-run
```

### GPU + Container Workflow

Complete example: discover GPUs, create a container with passthrough pre-configured,
then install the matching acceleration libraries inside it.

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

# 1. See what GPUs are available
gpu_list

# 2. Create the container with passthrough in one step (LXC)
container create \
    --name gpu-workload \
    --dist debian \
    --release trixie \
    --memory 8192 \
    --cores 8 \
    --gpu 01:00.0 || exit 1

# 3. Start the container
container start --name gpu-workload || exit 1

# 4. Install acceleration libraries inside the container
gpu_install --vendor nvidia --container gpu-workload || exit 1
```

Using `container prompt` for a fully interactive setup:

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

# Interactive: prompts for all fields; asks "Enable GPU passthrough?" mid-flow
container prompt

# Semi-automated: GPU and name pre-set, everything else prompted
CONTAINER_NAME=gpu-workload \
CONTAINER_GPU=01:00.0 \
    container prompt
```

Scripted multi-GPU passthrough (PCT, two GPUs on separate hostpci slots):

```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)

container create \
    --name multi-gpu \
    --template "local:vztmpl/debian-13-standard_13.x-1_amd64.tar.zst" \
    --memory 16384 \
    --cores 16 \
    --gpu 01:00.0 \
    --pcie || exit 1

# Add a second GPU to slot 1 after creation
gpu_select --container multi-gpu --index 1 --pcie
```
