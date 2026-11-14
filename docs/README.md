# shtuff documentation

**shtuff** (Shell Stuff) is a Bash utility library. Scripts source it to get
reusable functions for:

- structured, colored logging
- cross-platform package management (apt, dnf, yum, zypper, pacman, apk, Homebrew)
- background process monitoring with loading indicators
- file operations with progress (`copy`, `move`, `delete`, `download`)
- interactive prompts (`question`, `options`, `selections`, `confirm`)
- networking helpers (`scan`, `poll`, plus `bridge`, `forward`, `network` on Linux)
- systemd services and timers, LXC and Proxmox containers, and GPU setup (Linux)

## Pages

| Page | What it covers |
|---|---|
| [Getting started](getting-started.md) | Entry points, local and remote sourcing, environment variables |
| [Using shtuff in your scripts](using-in-scripts.md) | How to build an external script, with a complete example |
| [Platform support](platform-support.md) | What works on which OS, and what is untested |
| [Architecture](architecture.md) | Directory layout, manifest, loaders, interpreter variants |
| [Contributing](contributing.md) | Header format, logging rules, adding a module, testing |
| Reference | [logging](reference/logging.md), [packaging](reference/packaging.md), [monitor and utilities](reference/monitor.md), [file operations](reference/file-operations.md), [prompts](reference/prompts.md), [networking](reference/networking.md), [systemd](reference/systemd.md), [containers](reference/containers.md), [GPU](reference/gpu.md), [system](reference/system.md) |

## Platforms at a glance

| Entry point | Loads | Use it on |
|---|---|---|
| `shtuff-core.sh` / `shtuff-core-remote.sh` | `core/` only | Any platform with bash |
| `shtuff-linux.sh` / `shtuff-linux-remote.sh` | `core/` + `linux/` | Linux with bash |

Bash is required for everything except logging. BusyBox ash and zsh currently get
the logging functions only. macOS has no entry point yet; see
[platform support](platform-support.md).

## Examples

The [`examples/`](../examples) directory has install and update scripts for
[BentoPDF](https://github.com/alam00000/bentopdf) that serve as reference
implementations.
