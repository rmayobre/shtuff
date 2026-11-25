# Platform support

This page says what is implemented and what is tested. "Untested" means the code
exists but has not been run on that platform.

## Interpreters

| Shell | Status |
|---|---|
| bash 4+ | Supported (tested on Linux) |
| bash 3.2 (macOS default) | Logging, `copy`, `move` and `confirm` were fixed for 3.2. Other modules are not checked. Untested on macOS |
| BusyBox ash (Alpine default) | Logging, colors, loading indicators and `monitor`. Other modules are skipped and the loader prints a message. Install bash with `apk add bash` for the rest |
| zsh | Same subset as ash. `monitor` and the loading indicators have zsh versions; logging uses the ash version |

`monitor` and the loading indicators have a bash, zsh and ash implementation, and
were tested in all three under a pseudo-terminal (`busybox ash` 1.36, `dash`, zsh 5.9,
bash 5.2). Logging has bash and ash variants. This is Linux only: nothing here has
run on macOS or on Alpine's own BusyBox build.

## Features by platform

| Feature | Debian/Ubuntu | Fedora/RHEL | Arch | Alpine | macOS |
|---|---|---|---|---|---|
| Entry point | `shtuff-linux` | `shtuff-linux` | `shtuff-linux` | `shtuff-linux` (needs bash) | `shtuff-core` |
| `install`, `update`, `uninstall`, `clean` | apt | dnf/yum | pacman | apk | Homebrew, untested |
| Logging, prompts, `copy`, `move`, `delete`, `monitor` | Yes | Untested | Untested | Untested | Untested |
| `scan` (port check) | Yes | Yes | Yes | Needs a fix, see below | Not implemented: no `ss` or `/proc` |
| `service`, `timer` | systemd | systemd | systemd | Fails with an error: Alpine uses OpenRC, which is not supported yet | Fails with an error: launchd is not implemented |
| `bridge`, `forward`, `network` | Yes | Untested | Untested | Needs `iproute2` and `iptables` | Not available |
| Containers (`lxc_*`, `pct_*`) | Yes | Untested | Untested | Untested | Not available |
| GPU helpers | Yes | Untested | Untested | Package names are Debian-specific | Not available |
| `locale` | Yes | Untested | Untested | Partly | Not available |

Only the Debian-family column has been exercised end to end, and the Linux tests so
far ran in a container without systemd, so the systemd functions were not run here.

## Known gaps

- **systemd only.** `service` and `timer` need `systemctl`. Without it they print an
  error (naming OpenRC when it is detected) and return 1. On macOS, `shtuff-mac.sh`
  provides placeholders that always fail. OpenRC and launchd versions are planned.
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
