# Networking

`scan` and `poll` are in core. `bridge`, `forward` and `network` are Linux-only (they need `ip` and `iptables`).

> Generated from the header comments in `src/` by `docs/generate-reference.sh`. Edit the headers, not this file.

## `scan`

_Source: `src/core/networking/scan.sh`_

```text
Function: scan
Description: Validates a port number and checks whether it is currently bound
             on the local host. Returns 0 if the port is valid and free,
             1 if the port is in use, or 2 if the port number is invalid.

Arguments:
  --port PORT (integer, required): Port number to check (1–65535).
  --dry-run (flag, optional): Print the system calls that would be executed without
      running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.

Returns:
  0 - Port number is valid and is not currently in use.
  1 - Port is valid but is already bound (in use) on the host.
  2 - Invalid arguments or port number out of range (not 1–65535).

Examples:
  scan --port 8080
  scan --port 443
  if scan --port "$PORT"; then
      info "Port $PORT is available"
  else
      error "Port $PORT is already in use"
  fi
```

## `poll`

_Source: `src/core/networking/poll.sh`_

```text
Function: poll
Description: Polls a TCP host:port until it accepts connections or a timeout
             is reached. Displays a loading indicator while waiting. Useful
             for scripts that start a service and must wait for it to be ready
             before proceeding.

Arguments:
  --host HOST (string, required): Hostname or IP address to probe.
  --port PORT (integer, required): TCP port to probe (1–65535).
  --timeout SECONDS (integer, optional, default: 30): Maximum seconds to wait
      before giving up.
  --interval SECONDS (integer, optional, default: 2): Seconds between each
      probe attempt.
  --style STYLE (string, optional, default: spinner): Loading indicator style.
      Valid values: spinner, dots, bars, arrows, clock.
  --dry-run (flag, optional): Print the system calls that would be executed without
      running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  SPINNER_LOADING_STYLE (read): Default loading style constant.
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.

Returns:
  0 - Port became reachable within the timeout.
  1 - Invalid arguments or port number out of range.
  2 - Timed out waiting for the port to become reachable.

Examples:
  poll --host 127.0.0.1 --port 8080
  poll --host 10.0.0.10 --port 80 --timeout 60
  poll --host 10.0.0.10 --port 5432 --timeout 120 --interval 5 || exit 1
```

## `bridge`

_Source: `src/linux/networking/bridge.sh`_

```text
Function: bridge
Description: Manages Linux bridge interfaces on the host using iproute2.
             Supports creating, deleting, and adding or removing physical
             interfaces from a bridge. Changes take effect immediately but
             are not persistent across reboots — use your distribution's
             network configuration tool (netplan, systemd-networkd, etc.)
             to make them permanent.

Arguments:
  $1 - command (string, required): Subcommand to run.
      Valid values: create, delete, add-interface, remove-interface.

  create subcommand:
  --name NAME (string, required): Name of the bridge interface to create.
  --ip IP/PREFIX (string, optional): IP address and prefix length to assign
      (e.g. 10.0.0.1/24). Omit to create a bridge with no IP.

  delete subcommand:
  --name NAME (string, required): Name of the bridge interface to remove.

  add-interface subcommand:
  --name NAME (string, required): Name of the bridge to add the interface to.
  --interface IFACE (string, required): Network interface to attach to the bridge.

  remove-interface subcommand:
  --name NAME (string, required): Name of the bridge to remove the interface from.
  --interface IFACE (string, required): Network interface to detach from the bridge.

  --dry-run (flag, optional): Print the system calls that would be executed without
      running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  SPINNER_LOADING_STYLE (read): Default loading style constant.
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.

Returns:
  0 - Command completed successfully.
  1 - Invalid arguments, unknown subcommand, or 'ip' tool not available.
  2 - Bridge or interface already exists / does not exist.
  3 - Operation failed.

Examples:
  bridge create --name lxcbr0 --ip 10.0.0.1/24
  bridge create --name lxcbr0
  bridge add-interface --name lxcbr0 --interface eth0
  bridge remove-interface --name lxcbr0 --interface eth0
  bridge delete --name lxcbr0
```

## `forward`

_Source: `src/linux/networking/forward.sh`_

```text
Function: forward
Description: Manages iptables NAT DNAT rules for host-to-container port
             forwarding. Supports adding, removing, and listing forwarding
             rules. Also ensures IP forwarding is enabled in the kernel.
             Rules are not persistent across reboots without iptables-persistent
             or an equivalent tool.

Arguments:
  $1 - command (string, required): Subcommand to run.
      Valid values: add, remove, list.

  add subcommand:
  --from-port PORT (integer, required): Host port to forward from.
  --to-host HOST (string, required): Destination IP address (e.g. container IP).
  --to-port PORT (integer, optional, default: same as --from-port): Destination port.
  --protocol PROTO (string, optional, default: tcp): Protocol (tcp or udp).

  remove subcommand:
  --from-port PORT (integer, required): Host port of the rule to remove.
  --protocol PROTO (string, optional, default: tcp): Protocol of the rule to remove.

  list subcommand:
  No additional arguments. Displays current NAT PREROUTING rules.

  --dry-run (flag, optional): Print the system calls that would be executed without
      running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.

Returns:
  0 - Command completed successfully.
  1 - Invalid arguments, unknown subcommand, or iptables not available.
  2 - No matching rule found (remove only).
  3 - Operation failed.

Examples:
  forward add --from-port 8080 --to-host 10.0.0.10 --to-port 80
  forward add --from-port 2222 --to-host 10.0.0.10 --to-port 22 --protocol tcp
  forward add --from-port 5353 --to-host 10.0.0.20 --protocol udp
  forward remove --from-port 8080
  forward remove --from-port 5353 --protocol udp
  forward list
```

## `network`

_Source: `src/linux/networking/network.sh`_

```text
Function: network
Description: Unified interface for networking utilities. Dispatches subcommands
             to the appropriate networking function. Individual functions
             (download, scan, poll, bridge, forward) remain
             callable directly; this is a convenience entry point.

Arguments:
  $1 - command (string, required): Subcommand to run.
      Valid values: download, check, wait, bridge, forward.

  download subcommand:
  --url URL (string, required): URL to download.
  --dir DIR (string, optional): Directory to save the file.
  --output NAME (string, optional): Output filename.
  --style STYLE (string, optional): Loading indicator style.
  --message MSG (string, optional): Progress message.

  check subcommand:
  --port PORT (integer, required): Port number to check (1–65535).

  wait subcommand:
  --host HOST (string, required): Hostname or IP to probe.
  --port PORT (integer, required): TCP port to probe.
  --timeout SECONDS (integer, optional, default: 30): Max seconds to wait.
  --interval SECONDS (integer, optional, default: 2): Seconds between probes.
  --style STYLE (string, optional): Loading indicator style.

  bridge subcommand — manage Linux bridge interfaces:
  See bridge function for full subcommand and flag documentation.
  Valid bridge subcommands: create, delete, add-interface, remove-interface.

  forward subcommand — manage iptables DNAT port forwarding rules:
  See forward function for full subcommand and flag documentation.
  Valid forward subcommands: add, remove, list.

Globals:
  None

Returns:
  0 - Command completed successfully.
  1 - Unknown subcommand or missing required arguments.
  N - Exit code propagated from the delegated function.

Examples:
  network download --url https://example.com/file.zip --dir /tmp
  network check --port 8080
  network wait --host 127.0.0.1 --port 8080 --timeout 60
  network bridge create --name lxcbr0 --ip 10.0.0.1/24
  network bridge add-interface --name lxcbr0 --interface eth0
  network bridge delete --name lxcbr0
  network forward add --from-port 8080 --to-host 10.0.0.10 --to-port 80
  network forward remove --from-port 8080
  network forward list
```
