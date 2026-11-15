# Platform support

This page says what is implemented and what is tested. "Untested" means the code
exists but has not been run on that platform.

## Interpreters

| Shell | Status |
|---|---|
| bash 4+ | Supported (tested on Linux) |
| bash 3.2 (macOS default) | Logging, `copy`, `move` and `confirm` were fixed for 3.2. Other modules are not checked. Untested on macOS |
| BusyBox ash (Alpine default) | Logging only. The loader prints a message. Install bash with `apk add bash` |
| zsh | Logging only (uses the ash variant) |

Logging has a variant per interpreter (`log_bash.sh`, `log_ash.sh`). The ash one
was tested under `dash`, not BusyBox ash.

## Features by platform

| Feature | Debian/Ubuntu | Fedora/RHEL | Arch | Alpine | macOS |
|---|---|---|---|---|---|
| Entry point | `shtuff-linux` | `shtuff-linux` | `shtuff-linux` | `shtuff-linux` (needs bash) | `shtuff-core` |
| `install`, `update`, `uninstall`, `clean` | apt | dnf/yum | pacman | apk | Homebrew, untested |
| Logging, prompts, `copy`, `move`, `delete`, `monitor` | Yes | Untested | Untested | Untested | Untested |
| `scan` (port check) | Yes | Yes | Yes | Needs a fix, see below | Not implemented: no `ss` or `/proc` |
| `service`, `timer` | systemd | systemd | systemd | Not implemented: Alpine uses OpenRC | Not implemented: launchd |
| `bridge`, `forward`, `network` | Yes | Untested | Untested | Needs `iproute2` and `iptables` | Not available |
| Containers (`lxc_*`, `pct_*`) | Yes | Untested | Untested | Untested | Not available |
| GPU helpers | Yes | Untested | Untested | Package names are Debian-specific | Not available |
| `locale` | Yes | Untested | Untested | Partly | Not available |

Only the Debian-family column has been exercised end to end, and the Linux tests so
far ran in a container without systemd, so the systemd functions were not run here.

## Known gaps

- **No init-system abstraction.** `service` and `timer` write systemd units. On a
  system without systemd they do not fail cleanly. OpenRC (Alpine) and launchd
  (macOS) versions are planned.
- **Terminal handling.** `monitor` calls `tput`, which is missing from a fresh Alpine
  and fails without a `TERM`. Spinner frames use UTF-8 glyphs that may not render
  in a plain `C` locale.
- **`scan` on Linux.** The `/proc/net/tcp` fallback can match remote ports and
  non-listening sockets, so a port can be reported in use when it is not.
- **Containers and GPU on Alpine.** Guest commands assume `bash`, and GPU package
  names are Debian's.
- **Public names shadow system commands.** `install`, `locale`, `bridge` and
  `service` replace the system programs of the same name inside your script.
- **`examples/`** use `systemctl`, `apt-get` and `docker.io`, so they are Debian-family
  and systemd only.

## Homebrew

Homebrew runs on Linux and macOS, so its support lives in `core/packaging/`. It is
chosen first on macOS and last on Linux, after the native managers. Homebrew
refuses to run as root, so when your script runs as root shtuff runs `brew` as
`$SUDO_USER` or as the owner of the `brew` binary.

## Reporting results

If you run shtuff on Fedora, Arch, Alpine or macOS, please report what worked
and update the table above.
