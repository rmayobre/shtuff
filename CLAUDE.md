# CLAUDE.md — shtuff

## Project Overview

**shtuff** (Shell Stuff) is a Bash utility library providing reusable functions for
cross-platform package management, structured logging, background process monitoring,
file operations (copy, move, delete), and systemd service/timer creation. Scripts
source it locally or via `curl`.

The `examples/` directory contains install and update scripts for [BentoPDF](https://github.com/alam00000/bentopdf)
that serve as reference implementations.

---

## How to Source shtuff

**Locally** (after cloning):
```bash
source ./shtuff.sh
```

**Remotely** (production scripts):
```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)
```

All example scripts use the remote form. When writing new scripts, always use the
remote form unless the script is explicitly for local development use.

---

## Key Utilities Quick Reference

### Logging
```bash
info  "Informational message"   # Green
warn  "Warning message"         # Yellow
error "Error message"           # Red
debug "Debug message"           # Cyan (only when LOG_LEVEL=DEBUG)
```

### Package Management
```bash
update                          # Update all system packages (no args)
install nodejs npm curl unzip   # Install one or more packages
uninstall nginx                 # Remove one or more packages
clean                           # Remove orphans and clean package cache
```
All commands auto-detect the package manager (apt, dnf, yum, zypper, pacman, apk).

### Background Process Monitoring
Always run the command in the background with `&`, then pass `$!` to `monitor`:
```bash
some_long_command &
monitor $! \
    --style "$SPINNER_LOADING_STYLE" \
    --message "Doing something" \
    --success_msg "Done!" \
    --error_msg "Failed!" || exit 1
```
Available styles: `$SPINNER_LOADING_STYLE`, `$DOTS_LOADING_STYLE`,
`$BARS_LOADING_STYLE`, `$ARROWS_LOADING_STYLE`, `$CLOCK_LOADING_STYLE`

### File Operations
```bash
copy /source/path /destination/path                 # Copy file or directory
move /source/path /destination/path                 # Move file or directory
delete /path/to/remove                              # Delete file or directory
```
All three accept `--style STYLE` and `--message MSG` (same values as `monitor`).
Always append `|| exit 1` to propagate failures.

**Note:** To clear only the *contents* of a directory without removing the directory
itself, use the `rm -rf "${DIR:?}"/*` safety pattern directly — `delete` removes the
path itself, not its contents.

### Systemd Service Creation
```bash
service \
    --name "myapp" \
    --description "My Application" \
    --working-directory "/opt/myapp" \
    --exec-start "/usr/bin/node server.js" \
    --user "www-data" \
    --restart "always" \
    --restart-sec "10" \
    --environment "NODE_ENV=production PORT=3000" || exit 1
```
After calling `service`, always run:
```bash
systemctl daemon-reload
systemctl enable <name>
systemctl start <name>
```

### Forms

Result is stored in the global variable `$answer` after each call.

```bash
question "What is your name?"           # Free-form text; result in $answer
echo "Hello, $answer!"

options "Select an environment:" \      # Numbered list; selected text in $answer
    --choice "development" \
    --choice "staging" \
    --choice "production"
DEPLOY_ENV="$answer"

if confirm "Overwrite existing files?"; then   # Yes/No; returns 0=yes 1=no
    copy src/ dest/ || exit 1
fi
```

### Systemd Timer Creation
```bash
timer \
    --name "myapp-backup" \
    --description "Daily backup" \
    --on-calendar "daily" \
    --persistent
```

---

## Writing Installer Scripts

Follow the structure from `examples/install-bentodpf-native.sh` and
`examples/install-bentodpf-docker.sh`:

1. **Shebang + header comment** — describe purpose, usage, options, requirements
2. **Source shtuff** via remote curl
3. **Define constants** — `readonly` for fixed values, plain vars for overridable config
4. **Parse `--flag VALUE` arguments** — support both short (`-p`) and long (`--port`) forms
5. **Root check** — exit early if `$EUID -ne 0`
6. **Step 1:** `update` system packages (run in background, monitor)
7. **Step 2:** `install` dependencies (run in background, monitor)
8. **Step 3+:** Download / extract / configure the application
9. **Service step:** Call `service` to create the systemd unit
10. **Enable/start step:** `daemon-reload`, `enable`, `start`
11. **Final `info`** messages showing access URL and management commands

### Argument Pattern
```bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--port)  MY_PORT="$2"; shift 2 ;;
        -d|--dir)   MY_DIR="$2";  shift 2 ;;
        -h|--help)  # print help and exit 0
                    ;;
        *)  error "Unknown option: $1"; exit 1 ;;
    esac
done
```

### Extraction Pattern (zip releases with a `dist/` folder)
```bash
mkdir -p /tmp/myapp_extract
unzip -qo /tmp/myapp.zip -d /tmp/myapp_extract &
monitor $! ... || exit 1

DIST_DIR=$(find /tmp/myapp_extract -type d -name "dist" -maxdepth 4 | head -1)
CONTENT_DIR=$(dirname "${DIST_DIR}")
mkdir -p "${INSTALL_DIR}"
copy "${CONTENT_DIR}/." "${INSTALL_DIR}/" --message "Installing files" || exit 1
delete /tmp/myapp_extract --message "Removing temporary files" || exit 1
delete /tmp/myapp.zip || exit 1
```

---

## Writing Update Scripts

Follow `examples/update-bentodpf-native.sh` and `examples/update-bentodpf-docker.sh`:

1. Source shtuff
2. Parse `--dir` (and any other overridable config) arguments
3. Root check
4. **Verify install directory exists** — fail early with a helpful message
5. Resolve latest release URL from GitHub API
6. Download → extract → replace files (`rm -rf "${DIR:?}"/*` then `copy`)
7. Restart the service with `systemctl restart`

Key safety guard when clearing install directory contents:
```bash
rm -rf "${INSTALL_DIR:?}"/*   # :? prevents rm -rf /* if var is empty
copy "${CONTENT_DIR}/." "${INSTALL_DIR}/" --message "Replacing files" || exit 1
```
Use `rm -rf "${DIR:?}"/*` (not `delete`) when clearing a directory's contents in-place,
as `delete` removes the path itself. Use `delete` for temp files and directories.

---

## Conventions

- Always `|| exit 1` after `monitor` calls — propagate failures
- Use `readonly` for constants that must not change (`REPO`, `SERVICE` name)
- Allow config vars to be overridden via environment: `PORT="${PORT:-3000}"`
- Download files to `/tmp/`, always clean up temp files afterward
- Use `command -v <bin>` to verify a binary exists after installation
- Full binary paths in `--exec-start` (use `$(command -v npx)`, not just `npx`)
- Never hard-code package manager commands — always use `install`/`update`
- **Never call functions prefixed with `_`** — they are private internal helpers
  used by shtuff itself and are not part of the public API. Their signatures and
  behavior may change without notice. Only call the documented public functions
  (`info`, `warn`, `error`, `debug`, `install`, `update`, `uninstall`, `clean`,
  `monitor`, `stop`, `copy`, `move`, `delete`, `service`, `timer`,
  `question`, `options`, `confirm`).

---

## Contributing to `src/`

### Function Documentation

Every function in `src/` must have a header comment block using this format:

```bash
# Function: function_name
# Description: One-line description of what the function does.
#
# Arguments:
#   --flag-name NAME (string, required): Description of the argument.
#   --other-flag VALUE (integer, optional, default: 5): Description.
#   $1 - name (string, required): Use positional form only when the argument
#        is explicitly positional (not a named flag).
#
# Globals:
#   VAR_NAME (read): Description of global variable this function reads.
#   OTHER_VAR (write): Description of global variable this function writes.
#
# Returns:
#   0 - Success
#   1 - Invalid arguments or validation failure
#   2 - File or directory error
#   3 - Permission denied
#
# Examples:
#   function_name --flag-name "value" --other-flag 10
#   function_name --flag-name "other"
```

Rules:
- **Arguments** must be documented by name (e.g. `--flag VALUE`) unless the
  argument is explicitly positional, in which case use `$N - name` form.
- **Globals** must list every global variable the function reads or writes.
  Omit the section entirely only if the function touches no globals.
- **Returns** must list every numeric exit code the function can return with
  a plain-English description for each.
- **Examples** must include at least one realistic usage example.

### Logging

All user-facing output inside `src/` functions must go through the logging
functions — never bare `echo` or `printf` for messages:

```bash
info  "Step completed"            # progress / success
warn  "Falling back to default"   # non-fatal issues
error "Required argument missing" # failures before return 1
debug "Resolved path: $path"      # verbose detail
```

Use `error` immediately before any `return 1` (or non-zero return) so the
caller always sees a reason for failure. Use `debug` for internal state that
is only useful when diagnosing problems.

---

## Testing Scripts

Validate Bash syntax without executing:
```bash
bash -n examples/install-bentodpf-native.sh
bash -n examples/update-bentodpf-native.sh
```

Run shellcheck for lint (if available):
```bash
shellcheck examples/install-bentodpf-native.sh
```

---

## Repository Layout

```
shtuff/
├── shtuff.sh              # Local sourcing entry point
├── shtuff-remote.sh       # Remote sourcing entry point
├── src/
│   ├── graphics/          # ANSI colors, loading indicators
│   ├── logging/           # log(), info(), warn(), error(), debug()
│   ├── packaging/         # install(), update(), uninstall(), clean()
│   ├── forms/             # question(), options(), confirm()
│   ├── systemd/           # service(), timer()
│   └── utils/             # monitor(), stop(), copy(), move(), delete()
└── examples/
    ├── install-bentodpf-docker.sh
    ├── install-bentodpf-native.sh
    ├── update-bentodpf-docker.sh
    └── update-bentodpf-native.sh
```
