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
