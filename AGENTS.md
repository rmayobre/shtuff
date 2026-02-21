# AGENTS.md — shtuff

Guidance for AI agents working in this repository. Read this file before
creating or modifying installer or update scripts.

---

## What Is shtuff?

**shtuff** is a Bash utility library. Scripts source it to get:

- Cross-platform package management (`install`, `update`, `uninstall`, `clean`)
- Structured logging (`info`, `warn`, `error`, `debug`)
- Visual progress indicators for background processes (`monitor`)
- Systemd service and timer generation (`service`, `timer`)

All utilities live in `src/`. The remote entry point `shtuff-remote.sh` fetches
and sources every module from GitHub at runtime.

---

## Utility Reference

### Sourcing

Always source remotely in production scripts:
```bash
source <(curl -sL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-remote.sh)
```

### Logging

| Function | Level   | Color  | Notes |
|----------|---------|--------|-------|
| `error`  | ERROR   | Red    | Always printed |
| `warn`   | WARN    | Yellow | |
| `info`   | INFO    | Green  | |
| `debug`  | DEBUG   | Cyan   | Only when `LOG_LEVEL=DEBUG` |

### Package Management

```bash
update                        # Full system upgrade (no arguments)
install pkg1 pkg2 ...         # Install packages
uninstall pkg1 pkg2 ...       # Remove packages
clean                         # Remove orphans, clean cache
```

Auto-detects: `apt`, `dnf`, `yum`, `zypper`, `pacman`, `apk`.

### Background Process Monitor

Run the command in the background, then pass its PID to `monitor`:

```bash
long_running_command &
monitor $! \
    --style "$SPINNER_LOADING_STYLE" \
    --message "Human-readable progress message" \
    --success_msg "Completed message" \
    --error_msg "Failure message" || exit 1
```

Available `--style` values:
- `$SPINNER_LOADING_STYLE` — braille spinner (default for most steps)
- `$BARS_LOADING_STYLE` — fill bar (use for file downloads)
- `$DOTS_LOADING_STYLE` — progressive dots
- `$ARROWS_LOADING_STYLE` — rotating arrow
- `$CLOCK_LOADING_STYLE` — clock emoji

Always append `|| exit 1` — `monitor` returns the background process exit code.

### Systemd Service Generator

```bash
service \
    --name "myapp" \                          # required; .service suffix added automatically
    --description "My Application" \          # required
    --exec-start "/usr/bin/node server.js" \  # required; use absolute paths
    --working-directory "/opt/myapp" \        # optional but recommended
    --user "www-data" \                       # optional
    --group "www-data" \                      # optional
    --restart "always" \                      # optional (default: on-failure)
    --restart-sec "10" \                      # optional (default: 5)
    --environment "NODE_ENV=production" \     # optional; space-separated KEY=val pairs
    --exec-start-pre "-/usr/bin/pre-cmd" \    # optional; prefix "-" ignores failures
    --exec-stop "/usr/bin/stop-cmd" \         # optional
    --wanted-by "multi-user.target" || exit 1 # optional (default: multi-user.target)
```

After calling `service`, always reload and enable:
```bash
systemctl daemon-reload
systemctl enable myapp
systemctl start myapp
```

### Systemd Timer Generator

```bash
timer \
    --name "myapp-task" \
    --description "Periodic task" \
    --on-calendar "daily" \      # or --on-boot-sec "5min", --on-unit-active-sec "1h"
    --persistent \               # remember missed runs across reboots
    --unit "myapp-task.service"
```

---

## Installer Script Structure

Every `install-*.sh` script must follow this structure:

```
1.  #!/usr/bin/env bash
2.  Header comment (purpose, usage, options, requirements)
3.  source <(curl -sL .../shtuff-remote.sh)
4.  readonly constants  +  overridable VARS="${VARS:-default}"
5.  Argument parser     (while [[ $# -gt 0 ]]; do ... done)
6.  Root check          ([[ $EUID -ne 0 ]] && error "..." && exit 1)
7.  Step 1: update      (update & + monitor)
8.  Step 2: install     (install deps & + monitor)
9.  Step 3+: download / extract / configure
10. Service step:       service --name ... --exec-start ...
11. Enable/start:       daemon-reload, enable, start & + monitor
12. Completion info:    info messages with URL and management commands
```

### Argument Parsing Pattern

```bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--port)
            MY_PORT="$2"
            shift 2
            ;;
        -d|--dir)
            MY_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: sudo $0 [OPTIONS]"
            echo "  -p, --port PORT   Port number (default: 3000)"
            echo "  -d, --dir  DIR    Install directory (default: /var/www/myapp)"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done
```

### GitHub Release Download Pattern

```bash
DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep '"browser_download_url"' \
    | grep '\.zip' \
    | head -1 \
    | sed 's/.*"browser_download_url": "\(.*\)".*/\1/')

[[ -z "$DOWNLOAD_URL" ]] && error "Could not resolve release URL." && exit 1

curl -sL "$DOWNLOAD_URL" -o /tmp/myapp.zip &
monitor $! --style "$BARS_LOADING_STYLE" \
    --message "Downloading release" \
    --success_msg "Downloaded" \
    --error_msg "Download failed" || exit 1
```

### Zip Extraction Pattern (when release contains a `dist/` folder)

```bash
mkdir -p /tmp/myapp_extract
unzip -qo /tmp/myapp.zip -d /tmp/myapp_extract &
monitor $! --style "$SPINNER_LOADING_STYLE" \
    --message "Extracting files" \
    --success_msg "Extracted" \
    --error_msg "Extraction failed" || exit 1

DIST_DIR=$(find /tmp/myapp_extract -type d -name "dist" -maxdepth 4 | head -1)
[[ -z "$DIST_DIR" ]] && error "dist/ not found in archive." && exit 1

CONTENT_DIR=$(dirname "${DIST_DIR}")
mkdir -p "${INSTALL_DIR}"
cp -r "${CONTENT_DIR}/." "${INSTALL_DIR}/"
rm -rf /tmp/myapp_extract /tmp/myapp.zip
```

### npx serve Service Pattern

When serving a static `dist/` folder with `npx serve`:

```bash
NPX_BIN=$(command -v npx)
[[ -z "${NPX_BIN}" ]] && error "npx not found." && exit 1

service \
    --name "${SERVICE_NAME}" \
    --description "My App" \
    --working-directory "${INSTALL_DIR}" \
    --exec-start "${NPX_BIN} serve dist -p ${PORT}" \
    --restart "always" \
    --restart-sec "10" || exit 1
```

### Docker Service Pattern

```bash
service \
    --name "${SERVICE_NAME}" \
    --description "My App" \
    --exec-start-pre "-/usr/bin/docker rm -f ${CONTAINER_NAME}" \
    --exec-start "/usr/bin/docker run --name ${CONTAINER_NAME} -p ${PORT}:3000 ${IMAGE}" \
    --exec-stop "/usr/bin/docker stop ${CONTAINER_NAME}" \
    --restart "always" \
    --restart-sec "10" || exit 1
```

---

## Update Script Structure

Every `update-*.sh` script must follow this structure:

```
1.  #!/usr/bin/env bash
2.  Header comment
3.  source shtuff
4.  readonly constants + overridable vars
5.  Argument parser
6.  Root check
7.  Verify install directory exists (fail with helpful message if not)
8.  Resolve download URL
9.  Download latest release
10. Extract and replace files
11. Restart service (systemctl restart)
12. Completion info
```

### File Replacement Pattern

```bash
rm -rf "${INSTALL_DIR:?}"/*      # :? guard prevents rm -rf /* on empty var
cp -r "${CONTENT_DIR}/." "${INSTALL_DIR}/"
```

### Service Restart Pattern

```bash
systemctl restart "${SERVICE_NAME}" &
monitor $! \
    --style "$SPINNER_LOADING_STYLE" \
    --message "Restarting ${SERVICE_NAME}" \
    --success_msg "Restarted successfully!" \
    --error_msg "Restart failed" || {
    error "Check logs: journalctl -u ${SERVICE_NAME} -n 50"
    exit 1
}
```

---

## Conventions

| Rule | Detail |
|------|--------|
| Use `readonly` for fixed values | `readonly REPO="org/app"`, `readonly SERVICE="appname"` |
| Allow env-var overrides | `PORT="${PORT:-3000}"` |
| Always use absolute binary paths in `--exec-start` | `$(command -v npx)`, not `npx` |
| Never hard-code package manager commands | Use `install`/`update` |
| Always `|| exit 1` after `monitor` | Propagate failures immediately |
| Clean up `/tmp/` after extraction | `rm -rf /tmp/myapp_extract /tmp/myapp.zip` |
| Use `${VAR:?}` in destructive `rm -rf` | Prevents catastrophic empty-variable expansion |
| Scripts require root | Check `$EUID -ne 0` at the top |
| Prefer `curl -sL` for downloads | Silent + follow redirects |
| **Never call `_`-prefixed functions** | Functions starting with `_` are private internal helpers used by shtuff. They are not part of the public API and may change without notice. |

### Public API

Only call these documented public functions. Everything else is private:

| Module      | Public functions |
|-------------|-----------------|
| Logging     | `info`, `warn`, `error`, `debug` |
| Packaging   | `install`, `update`, `uninstall`, `clean` |
| Utils       | `monitor`, `stop` |
| Systemd     | `service`, `timer` |

Any function whose name begins with `_` (e.g. `_log_write`, `_detect_pm`) is an
internal implementation detail. Do not call it, reference it, or rely on its
existence in scripts you write.

---

## Contributing to `src/`

### Function Documentation Template

Every function added or modified in `src/` must include a header comment block
in this exact format:

```bash
# Function: function_name
# Description: One-line description of what the function does.
#
# Arguments:
#   --flag-name NAME (string, required): Description.
#   --other-flag VALUE (integer, optional, default: 5): Description.
#   $1 - name (string, required): Use positional $N form ONLY when the
#        argument is explicitly positional, not a named flag.
#
# Globals:
#   VAR_NAME (read): Global variable this function reads.
#   OTHER_VAR (write): Global variable this function writes.
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

#### Arguments

- Document every argument by its **flag name** (`--flag VALUE`), not by
  position, unless the argument is explicitly positional.
- Positional arguments use the `$N - name (type, required/optional)` form.
- Mark each argument as `required` or `optional`. For optional arguments,
  include the default value: `optional, default: "on-failure"`.
- Accepted types: `string`, `integer`, `boolean` (flag-only, no value).

#### Globals

- List every global or environment variable the function reads **or** writes.
- Annotate each with `(read)` or `(write)`.
- Omit the `Globals:` section only if the function truly touches no globals.

#### Returns

- List **every** numeric exit code the function can return.
- Provide a plain-English label for each code.
- Standard codes used across `src/`:

  | Code | Meaning |
  |------|---------|
  | `0`  | Success |
  | `1`  | Invalid arguments or validation failure |
  | `2`  | File or directory error |
  | `3`  | Permission denied |

#### Examples

- Provide at least one realistic, copy-pasteable usage example.
- Show multiple examples when the function has meaningfully different usage
  paths (e.g. required-only vs. with optional flags).

---

### Logging in `src/` Functions

All user-facing output must go through the shtuff logging functions. Never use
bare `echo` or `printf` for messages inside `src/`.

| Function | When to use |
|----------|-------------|
| `info`   | Progress updates and success confirmations |
| `warn`   | Non-fatal issues; execution continues |
| `error`  | Failures; always call immediately before a non-zero `return` |
| `debug`  | Internal state useful only when diagnosing problems |

Pattern — always pair `error` with the failing `return`:

```bash
if [[ -z "$required_arg" ]]; then
    error "function_name: --required-flag is required"
    return 1
fi
```

---

## File Naming

| Script type         | Naming convention             |
|---------------------|-------------------------------|
| Docker install      | `install-<app>-docker.sh`     |
| Native install      | `install-<app>-native.sh`     |
| Docker update       | `update-<app>-docker.sh`      |
| Native update       | `update-<app>-native.sh`      |

All scripts go in `examples/`.

---

## Validating Scripts

Always check syntax before committing:
```bash
bash -n examples/install-myapp-native.sh
bash -n examples/update-myapp-native.sh
```
