# Using shtuff in your scripts

This page shows how to build a script that depends on shtuff. The scripts in
[`examples/`](../examples) follow the same structure.

## Script skeleton

1. Shebang and a header comment (purpose, usage, options, requirements).
2. Source shtuff.
3. Constants: `readonly` for fixed values, plain variables for overridable config.
4. Parse `--flag VALUE` arguments.
5. Root check.
6. Work steps, each followed by `|| exit 1`.
7. Final `info` messages.

## Complete example

This publishes a directory over HTTP with Python's built-in web server, managed
by systemd. It needs a Linux system with systemd and root access.

```bash
#!/usr/bin/env bash
#
# install-site.sh - Publish a directory as a static site via a systemd service.
#
# Usage:  sudo ./install-site.sh [--dir /var/www/site] [--port 8080]
# Needs:  Linux with systemd, root privileges, bash, curl

source <(curl -fsSL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-linux-remote.sh)

readonly SERVICE="static-site"
SITE_DIR="${SITE_DIR:-/var/www/site}"
PORT="${PORT:-8080}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dir)   SITE_DIR="$2"; shift 2 ;;
        -p|--port)  PORT="$2";     shift 2 ;;
        -h|--help)  echo "Usage: $0 [--dir DIR] [--port PORT]"; exit 0 ;;
        *)          error "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ $EUID -ne 0 ]]; then
    error "Run as root (try: sudo $0)"
    exit 1
fi

update || exit 1
install python3 || exit 1
PYTHON="$(command -v python3)" || { error "python3 was not installed"; exit 1; }

mkdir -p "${SITE_DIR}"
echo "<h1>Hello from shtuff</h1>" > "${SITE_DIR}/index.html"

service \
    --name "${SERVICE}" \
    --description "Static site on port ${PORT}" \
    --working-directory "${SITE_DIR}" \
    --exec-start "${PYTHON} -m http.server ${PORT}" \
    --restart "always" || exit 1

info "Site is live at http://localhost:${PORT}"
info "Manage it with: systemctl status ${SERVICE}"
```

## Conventions

- Add `|| exit 1` after every `install`, `update`, `copy`, `move`, `delete`,
  `download` and `monitor` call so failures stop the script.
- Never hard-code `apt` or `dnf`. Use `install`, `update`, `uninstall` and `clean`.
- Download to `/tmp/` and delete the files afterward with `delete`.
- Use full binary paths in `service --exec-start`, for example `$(command -v node)`.
- Verify a binary with `command -v <bin>` after installing it.
- Allow overrides from the environment: `PORT="${PORT:-3000}"`.
- Only call the public functions. Names that start with `_` are private and can
  change without notice.

## Common tasks

Long-running commands: start in the background, then hand the PID to `monitor`.

```bash
tar -xzf /tmp/app.tar.gz -C /opt/app &
monitor $! \
    --style "$SPINNER_LOADING_STYLE" \
    --message "Extracting" \
    --success_msg "Extracted" \
    --error_msg "Extraction failed" || exit 1
```

Styles: `$SPINNER_LOADING_STYLE`, `$DOTS_LOADING_STYLE`, `$BARS_LOADING_STYLE`,
`$ARROWS_LOADING_STYLE`, `$CLOCK_LOADING_STYLE`.

File operations:

```bash
copy /src/dist/. /var/www/site/ --message "Publishing" || exit 1
delete /tmp/app.tar.gz || exit 1
```

To empty a directory without removing it, use the safe pattern directly:

```bash
rm -rf "${INSTALL_DIR:?}"/*    # :? aborts if the variable is empty
```

Prompts (result in `$answer`; `selections` fills the `$answers` array):

```bash
options "Select an environment:" --choice "staging" --choice "production"
DEPLOY_ENV="$answer"

if confirm "Overwrite existing files?"; then
    copy src/ dest/ || exit 1
fi
```

A systemd service (Linux entry point):

```bash
service \
    --name "myapp" \
    --description "My Application" \
    --working-directory "/opt/myapp" \
    --exec-start "$(command -v node) server.js" \
    --user "www-data" \
    --restart "always" || exit 1
```

`service` writes the unit and runs `daemon-reload`, `enable` and `start`. Pass
`--lazy` to write the file only.

## Logging from your script

```bash
info  "Step completed"
warn  "Using the default"
error "Something failed"      # always shown
debug "path=$path"            # only when LOG_LEVEL=debug
```

Log output goes to stderr, so it never pollutes values your script prints to stdout.

## Testing your script

```bash
bash -n install-site.sh        # syntax check
shellcheck install-site.sh     # lint, if installed
```

See the [reference pages](README.md) for every function's arguments, return codes
and examples.
