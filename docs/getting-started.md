# Getting started

## Pick an entry point

| File | Modules loaded |
|---|---|
| `shtuff-core.sh` | `core/` (logging, packaging, utils, prompts, `scan`, `poll`) |
| `shtuff-linux.sh` | `core/` plus `linux/` (systemd, containers, GPU, `bridge`, `forward`, `network`, `locale`) |
| `shtuff-core-remote.sh` | Same as `shtuff-core.sh`, fetched from GitHub |
| `shtuff-linux-remote.sh` | Same as `shtuff-linux.sh`, fetched from GitHub |

If you are not sure, use the Linux entry point on Linux and the core one elsewhere.
Calling a Linux-only function (such as `service`) after loading only core gives
"command not found".

## Source from a clone

```bash
git clone https://github.com/rmayobre/shtuff.git
```

```bash
#!/usr/bin/env bash
source ./shtuff/shtuff-linux.sh   # or shtuff-core.sh
info "shtuff loaded"
```

## Source remotely

With `curl`:

```bash
source <(curl -fsSL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-linux-remote.sh)
```

With `wget`, for systems without `curl`:

```bash
source <(wget -qO- https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-linux-remote.sh)
```

On macOS's bash 3.2, `source <(...)` is unreliable. Use `eval` instead:

```bash
eval "$(curl -fsSL https://raw.githubusercontent.com/rmayobre/shtuff/refs/heads/main/shtuff-core-remote.sh)"
```

The remote entry point downloads `src/manifest.txt` and then every module it
lists, so a load makes dozens of requests. For repeatable installs, pin to a
release (below) instead.

## Pin to a release

Release tarballs contain the entry points and `src/`:

```bash
VERSION="v1.0.0"                      # a release tag
SHTUFF_TMP="/tmp/shtuff-${VERSION}"
mkdir -p "${SHTUFF_TMP}"
curl -fsSL "https://github.com/rmayobre/shtuff/releases/download/${VERSION}/shtuff-${VERSION}.tar.gz" \
    | tar -xz -C "${SHTUFF_TMP}"
source "${SHTUFF_TMP}/shtuff-linux.sh"
```

You can also point the remote entry points at a fork or a tag:

```bash
export SHTUFF_BASE_URL="https://raw.githubusercontent.com/<you>/shtuff/refs/heads/main"
source <(curl -fsSL "${SHTUFF_BASE_URL}/shtuff-linux-remote.sh")
```

## Requirements

- **bash** 3.2 or newer for the full library. On Alpine run `apk add bash`.
- **curl** or **wget** for the remote entry points. On Alpine also install
  `ca-certificates`; BusyBox `wget` needs `ssl_client` for HTTPS.
- Package functions and `service` need root (or `sudo`).

Under BusyBox ash or zsh only the logging functions load, and the loader prints a
message saying so.

## Environment variables

| Variable | Default | Effect |
|---|---|---|
| `LOG_LEVEL` | `info` | Threshold: `error`, `warn`, `info`, `debug`, `verbose` |
| `LOG_FILE` | empty | Write log output to this file instead of the terminal |
| `LOG_TIMESTAMP` | `true` | Set `false` to drop the timestamp prefix |
| `VERBOSE_FILE` | `${TMPDIR:-/tmp}/script_$$.log` | Where raw command output from `install`, `update` and similar is saved |
| `IS_DRY_RUN` | `false` | Functions that support `--dry-run` print their commands instead of running them |
| `SHTUFF_BASE_URL` | upstream `main` | Repository root used by the remote entry points |
| `SHTUFF_DIR` | auto | Project root for local entry points. Set it under plain ash, which cannot locate the file itself |

## Next

See [Using shtuff in your scripts](using-in-scripts.md).
