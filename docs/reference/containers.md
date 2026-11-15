# Containers (LXC and Proxmox)

Linux only. LXC (`lxc_*`) and Proxmox CT (`pct_*`) functions plus shared helpers.

> Generated from the header comments in `src/` by `docs/generate-reference.sh`. Edit the headers, not this file.

## `container`

_Source: `src/linux/containers/container.sh`_

```text
Function: container
Description: Unified interface for creating and managing containers. Automatically
             delegates to PCT (Proxmox Container Toolkit) when pct is found on the
             system, or falls back to LXC otherwise.

Arguments:
  $1 - command (string, required): Subcommand to run.
      Valid values: create, config, start, exec, enter, push, pull, delete, prompt.
  --name NAME (string, required by all subcommands): Container name / hostname.
      For PCT backends, used as the container hostname and the VMID is automatically
      generated via pct_next_vmid. For LXC backends, used as the container name.

  create subcommand — resource allocation flags (passed through to backend):
  --hostname HOSTNAME (string, optional): Hostname to assign inside the container.
  --memory MB (integer, optional): Memory limit in megabytes.
  --cores N (integer, optional): Number of CPU cores to allocate.
  --storage STORAGE (string, optional): Storage type. For LXC: backing store type
      (dir, btrfs, zfs, overlayfs, best; default: dir). For PCT: Proxmox storage
      pool name (e.g. local-lvm; default: local-lvm).
  --disk-size GB (integer, optional): Rootfs size in gigabytes. For LXC, only
      effective when --storage is btrfs or zfs.
  --password PASSWORD (string, optional): Root password for the container.
  --gpu PCI_ADDR (string, optional): PCI address of the GPU to pass through to the
      container (e.g. 01:00.0). Applied after the container is created via
      _gpu_apply_passthrough. Use gpu_list to discover available addresses.
  --pcie (flag, optional): Enable PCIe passthrough mode (pcie=1) when configuring
      GPU passthrough on PCT backends. Has no effect on LXC backends.

  exec subcommand — run a command inside the container without an interactive session:
  -- COMMAND... (required): Everything after -- is the command to run inside the container.

  All other subcommand-specific flags are also forwarded unchanged. See
  pct_create / lxc_create, pct_start / lxc_start, pct_exec / lxc_exec,
  pct_enter / lxc_enter, pct_push / lxc_push, pct_pull / lxc_pull, and
  pct_delete / lxc_delete for the complete list of accepted flags per backend.

  config subcommand — update resource settings on an existing container:
  --hostname HOSTNAME (string, optional): New hostname.
  --memory MB (integer, optional): New memory limit in megabytes.
  --cores N (integer, optional): New CPU core count.
  --set KEY=VALUE (string, optional, repeatable, LXC only): Set an arbitrary
      lxc.* config key. May be specified multiple times.
  Any additional flags accepted by 'pct set' are forwarded on PCT hosts.

  delete subcommand:
  --force (flag, optional): Stop the container before destroying if it is running.
  --purge (flag, optional, PCT only): Remove from related configurations and jobs.

  network subcommand — manage a container's network interface. Accepts an
  optional subcommand keyword as the first argument after 'network':
      (no keyword) — configure the interface (default behaviour).
      show          — display the current network configuration.
      prompt        — interactive form to configure the interface.

  Configure / show flags:
  --bridge BRIDGE (string, optional): Host bridge interface to attach to.
      Default: lxcbr0 (LXC) or vmbr0 (PCT).
  --ip IP/PREFIX (string, optional): Static IP with prefix (e.g. 10.0.0.10/24).
      Omit to leave address unconfigured (use a DHCP client inside the container).
      Use 'dhcp' on PCT to request dynamic assignment via pct.
  --gateway GW (string, optional): Default gateway IP.
  --dns NAMESERVERS (string, optional, PCT only): Space-separated DNS nameserver
      IPs (e.g. "8.8.8.8 8.8.4.4").
  --index N (integer, optional, default: 0): Network interface index.
  --type TYPE (string, optional, LXC only): Interface type.
      Valid values: veth, macvlan, ipvlan, none. Default: veth.
  --hwaddr MAC (string, optional, LXC only): Hardware (MAC) address to assign.

Globals:
  None

Returns:
  0 - Command completed successfully.
  1 - Unknown subcommand or missing required --name argument.
  N - Exit code propagated from the delegated backend function.

Examples:
  container create --name mycontainer --dist debian --release trixie
  container create --name mycontainer --memory 1024 --cores 2 --hostname myapp
  container create --name myapp --template "local:vztmpl/debian-13-standard_13.x-1_amd64.tar.zst" \
      --memory 1024 --cores 2 --disk-size 16
  container create --name mycontainer --dist debian --release trixie --gpu 01:00.0
  container create --name mycontainer --template "local:vztmpl/debian-13-standard_13.x-1_amd64.tar.zst" \
      --gpu 01:00.0 --pcie
  container start --name mycontainer
  container exec --name mycontainer -- bash -c "apt-get update && apt-get install -y curl"
  container enter --name mycontainer
  container enter --name 100 --user deploy
  container push /etc/app.conf /etc/app.conf --name mycontainer
  container pull /var/log/app.log /tmp/app.log --name 100
  container config --name mycontainer --memory 2048 --cores 4
  container config --name mycontainer --hostname newname
  container config --name mycontainer --set lxc.net.0.type=veth
  container delete --name mycontainer
  container delete --name 100 --force --purge
  container network --name mycontainer --bridge lxcbr0 --ip 10.0.0.10/24 --gateway 10.0.0.1
  container network --name 100 --ip 192.168.1.100/24 --gateway 192.168.1.1
  container network --name 100 --ip dhcp --dns "8.8.8.8 8.8.4.4"
  container network show --name mycontainer
  container network show --name 100 --index 1
  container network prompt --name mycontainer
  container network prompt --name mycontainer --index 1
  container shell-script --name mycontainer --content '#!/bin/bash\necho hello' --path /usr/local/bin/hello.sh
  container shell-script --name 100 --content "$(cat setup.sh)" --path /opt/setup.sh
  container shell-script --name mycontainer --path /opt/setup.sh --env PORT="$PORT" --env DIR="$INSTALL_DIR"
  container prompt
  CONTAINER_NAME=myapp CONTAINER_MEMORY=1024 container prompt
```

## `lxc_config`

_Source: `src/linux/containers/lxc/lxc_config.sh`_

```text
Function: lxc_config
Description: Updates configuration settings for an existing LXC container by
             modifying /var/lib/lxc/NAME/config directly. If a key already exists
             it is replaced in-place; otherwise it is appended. Changes take effect
             the next time the container is started — restart if currently running.

Arguments:
  --name NAME (string, required): Name of the container to configure.
  --hostname HOSTNAME (string, optional): Hostname to set (lxc.uts.name).
  --memory MB (integer, optional): Memory limit in megabytes (lxc.cgroup2.memory.max).
  --cores N (integer, optional): CPU core count (lxc.cgroup2.cpuset.cpus).
  --set KEY=VALUE (string, optional, repeatable): Set any arbitrary lxc.* config key.
      May be specified multiple times to update several keys in one call.
  --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.

Returns:
  0 - Configuration updated successfully.
  1 - Invalid or missing arguments, or LXC not installed.
  2 - Container does not exist or config file not found.
  3 - Configuration update failed.

Examples:
  lxc_config --name mycontainer --memory 2048 --cores 4
  lxc_config --name mycontainer --hostname newname
  lxc_config --name mycontainer --set lxc.net.0.type=veth
  lxc_config --name mycontainer --memory 1024 --set lxc.start.auto=1
```

## `lxc_create`

_Source: `src/linux/containers/lxc/lxc_create.sh`_

```text
Function: lxc_create
Description: Creates a new LXC container, installing LXC tooling first if not present.
             Resource constraints (memory, CPU) are written to the container config
             using cgroup v2 keys after creation.

Arguments:
  --name NAME (string, required): Name for the new container.
  --template TEMPLATE (string, optional, default: "download"): LXC template to use.
  --dist DIST (string, optional, default: "debian"): Distribution name (used with "download" template).
  --release RELEASE (string, optional, default: "trixie"): Distribution release (used with "download" template).
  --arch ARCH (string, optional, default: "amd64"): Architecture (used with "download" template).
  --hostname HOSTNAME (string, optional): Hostname to assign inside the container.
  --memory MB (integer, optional): Memory limit in megabytes.
  --cores N (integer, optional): Number of CPU cores to allocate.
  --storage STORAGE (string, optional, default: "dir"): Backing store type for the
      container rootfs. Valid values: dir, btrfs, zfs, overlayfs, best.
      Note: --disk-size only takes effect with btrfs or zfs.
  --disk-size GB (integer, optional): Rootfs size in gigabytes. Requires --storage
      to be set to btrfs or zfs; silently ignored for other backing stores.
  --password PASSWORD (string, optional): Root password to set inside the container.
      The container is started briefly to apply the password, then stopped.
  --style STYLE (string, optional, default: spinner): Loading indicator style.
      Valid values: spinner, dots, bars, arrows, clock.
  --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  SPINNER_LOADING_STYLE (read): Default loading style constant.
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.

Returns:
  0 - Container created successfully.
  1 - Invalid or missing arguments.
  2 - LXC installation failed.
  3 - Container creation or post-creation configuration failed.

Examples:
  lxc_create --name mycontainer
  lxc_create --name webserver --dist debian --release trixie --arch amd64
  lxc_create --name myapp --dist debian --release trixie \
      --hostname myapp --memory 1024 --cores 2 \
      --storage btrfs --disk-size 16 --password secret
```

## `lxc_delete`

_Source: `src/linux/containers/lxc/lxc_delete.sh`_

```text
Function: lxc_delete
Description: Destroys an LXC container, permanently removing it and all its data.
             The container must be stopped first unless --force is specified.

Arguments:
  --name NAME (string, required): Name of the container to destroy.
  --force (flag, optional): Stop the container before destroying if it is running.
  --style STYLE (string, optional, default: spinner): Loading indicator style.
      Valid values: spinner, dots, bars, arrows, clock.
  --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  SPINNER_LOADING_STYLE (read): Default loading style constant.
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.

Returns:
  0 - Container destroyed successfully.
  1 - Invalid or missing arguments, or LXC not installed.
  2 - Container does not exist.
  3 - Container destruction failed.

Examples:
  lxc_delete --name mycontainer
  lxc_delete --name mycontainer --force
```

## `lxc_enter`

_Source: `src/linux/containers/lxc/lxc_enter.sh`_

```text
Function: lxc_enter
Description: Attaches to a running LXC container in an interactive terminal session.
             If the container is stopped, it will be started automatically before attaching.

Arguments:
  --name NAME (string, required): Name of the container to enter.
  --user USER (string, optional, default: "root"): User to run the shell as inside the container.
  --shell SHELL (string, optional, default: "/bin/bash"): Shell executable to launch.
  --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  SPINNER_LOADING_STYLE (read): Default loading style constant.
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.

Returns:
  0 - Session ended normally.
  1 - Invalid or missing arguments, or LXC not installed.
  2 - Container does not exist.
  3 - Container failed to start.

Examples:
  lxc_enter --name mycontainer
  lxc_enter --name webserver --user www-data --shell /bin/sh
```

## `lxc_exec`

_Source: `src/linux/containers/lxc/lxc_exec.sh`_

```text
Function: lxc_exec
Description: Runs a command inside a running LXC container without opening an
             interactive session. The container must already be running.

Arguments:
  --name NAME (string, required): Name of the container to execute the command in.
  -- COMMAND... (required): The command and its arguments to run inside the container.
      Everything after -- is passed verbatim to lxc-attach.
  --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.

Returns:
  0 - Command completed successfully.
  1 - Invalid or missing arguments, or LXC not installed.
  2 - Container does not exist.
  N - Exit code returned by the command run inside the container.

Examples:
  lxc_exec --name mycontainer -- bash -c "apt-get update -qq && apt-get install -y curl"
  lxc_exec --name webserver -- systemctl restart nginx
```

## `lxc_network`

_Source: `src/linux/containers/lxc/lxc_network.sh`_

```text
Function: lxc_network
Description: Configures network interface settings for an LXC container by
             writing lxc.net.N.* keys to /var/lib/lxc/NAME/config. If a key
             already exists it is replaced in-place; otherwise it is appended.
             If the container is currently running it is stopped and restarted
             automatically so the new settings take effect immediately.

Arguments:
  --name NAME (string, required): Name of the container to configure.
  --type TYPE (string, optional, default: veth): Interface type.
      Valid values: veth, macvlan, ipvlan, none.
  --bridge BRIDGE (string, optional, default: lxcbr0): Host bridge interface
      that the container's veth peer is attached to (lxc.net.N.link).
  --ip IP/PREFIX (string, optional): Static IP address with prefix length
      (e.g. 10.0.0.10/24). Omit to leave address unconfigured (use DHCP
      client inside the container for dynamic assignment).
  --gateway GW (string, optional): Default gateway IP. Ignored when --ip
      is not provided.
  --hwaddr MAC (string, optional): Hardware (MAC) address to assign
      (e.g. 00:16:3e:ab:cd:ef). Omit to let LXC auto-generate one.
  --index N (integer, optional, default: 0): Network interface index.
      Controls which lxc.net.N.* block is configured.
  --style STYLE (string, optional, default: spinner): Loading indicator style.
      Valid values: spinner, dots, bars, arrows, clock.
  --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.
  SPINNER_LOADING_STYLE (read): Default loading style constant.

Returns:
  0 - Network configuration updated successfully.
  1 - Invalid or missing arguments, or LXC not installed.
  2 - Container does not exist or config file not found.
  3 - Configuration write or restart failed.

Examples:
  lxc_network --name mycontainer --bridge lxcbr0 --ip 10.0.0.10/24 --gateway 10.0.0.1
  lxc_network --name mycontainer --ip 10.0.0.10/24 --gateway 10.0.0.1
  lxc_network --name mycontainer --bridge lxcbr0
  lxc_network --name mycontainer --index 1 --bridge br1 --ip 192.168.1.5/24
  lxc_network --name mycontainer --hwaddr 00:16:3e:ab:cd:ef --ip 10.0.0.10/24
```

## `lxc_network_show`

_Source: `src/linux/containers/lxc/lxc_network_show.sh`_

```text
Function: lxc_network_show
Description: Displays the current network interface configuration for an LXC
             container by reading lxc.net.* entries from the container's
             config file at /var/lib/lxc/NAME/config.

Arguments:
  --name NAME (string, required): Name of the LXC container to inspect.
  --index N (integer, optional): Network interface index. When given, only
      lxc.net.<N>.* entries are shown. Omit to show all lxc.net.* entries.
  --dry-run (flag, optional): Print the system calls that would be executed
      without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.

Returns:
  0 - Configuration displayed successfully (or no entries found).
  1 - Invalid or missing arguments, or lxc not installed.
  2 - Container does not exist or config file not found.

Examples:
  lxc_network_show --name mycontainer
  lxc_network_show --name mycontainer --index 0
```

## `lxc_pull`

_Source: `src/linux/containers/lxc/lxc_pull.sh`_

```text
Function: lxc_pull
Description: Copies a file or directory from inside an LXC container to the host by reading
             directly from the container's rootfs. Works whether the container is running
             or stopped.

Arguments:
  $1 - source (string, required): Absolute path inside the container to copy from.
  $2 - destination (string, required): Path on the host to copy to.
  --name NAME (string, required): Name of the source container.
  --style STYLE (string, optional, default: spinner): Loading indicator style.
      Valid values: spinner, dots, bars, arrows, clock.
  --message MSG (string, optional, default: "Pulling from container..."): Progress message.
  --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  SPINNER_LOADING_STYLE (read): Default loading style constant.
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.

Returns:
  0 - File(s) pulled successfully.
  1 - Invalid or missing arguments, or LXC not installed.
  2 - Source path does not exist inside the container, container does not exist,
      or rootfs not found.
  3 - Copy operation failed.

Examples:
  lxc_pull /etc/myapp.conf /tmp/myapp.conf --name mycontainer
  lxc_pull /var/log/app /tmp/app-logs --name webserver --style dots --message "Fetching logs"
```

## `lxc_push`

_Source: `src/linux/containers/lxc/lxc_push.sh`_

```text
Function: lxc_push
Description: Copies a file or directory from the host into an LXC container by writing
             directly into the container's rootfs. Works whether the container is running
             or stopped.

Arguments:
  $1 - source (string, required): Path on the host to copy from.
  $2 - destination (string, required): Absolute path inside the container to copy to.
  --name NAME (string, required): Name of the target container.
  --style STYLE (string, optional, default: spinner): Loading indicator style.
      Valid values: spinner, dots, bars, arrows, clock.
  --message MSG (string, optional, default: "Pushing to container..."): Progress message.
  --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  SPINNER_LOADING_STYLE (read): Default loading style constant.
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.

Returns:
  0 - File(s) pushed successfully.
  1 - Invalid or missing arguments, or LXC not installed.
  2 - Source path does not exist, container does not exist, or rootfs not found.
  3 - Copy operation failed.

Examples:
  lxc_push /etc/myapp.conf /etc/myapp.conf --name mycontainer
  lxc_push /opt/app /opt/app --name webserver --style dots --message "Deploying app"
```

## `lxc_shell_script`

_Source: `src/linux/containers/lxc/lxc_shell_script.sh`_

```text
Function: lxc_shell_script
Description: Creates an executable shell script file inside an LXC container by
             writing the provided content to a temporary file on the host, pushing
             it into the container's rootfs, setting executable permissions, and
             cleaning up the temporary file. Works whether the container is running
             or stopped.

Arguments:
  --name NAME       (string, required): Name of the target LXC container.
  --content CONTENT (string, optional): The shell script content to write into the file.
                    Defaults to the value of the $script variable when omitted.
  --path PATH       (string, required): Absolute destination path inside the container
                    (e.g. /usr/local/bin/myscript.sh).
  --env KEY=VALUE   (string, optional, repeatable): Prepend an 'export KEY=VALUE' line
                    to the script. Use to inject outer-shell values into the container
                    script without relying on heredoc variable expansion.
  --style STYLE     (string, optional, default: spinner): Loading indicator style.
      Valid values: spinner, dots, bars, arrows, clock.
  --dry-run         (flag, optional): Print the system calls that would be executed
                    without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  script                (read): Fallback script content used when --content is omitted.
  SPINNER_LOADING_STYLE (read): Default loading style constant.
  IS_DRY_RUN            (read): When "true", enables dry-run mode by default.

Returns:
  0 - Script created successfully.
  1 - Invalid or missing arguments, or LXC not installed.
  2 - Container does not exist, or rootfs not found.
  3 - Push or chmod operation failed.

Examples:
  lxc_shell_script --name mycontainer --content '#!/bin/bash\necho hello' --path /usr/local/bin/hello.sh
  lxc_shell_script --name webserver --content "$(cat setup.sh)" --path /opt/setup.sh --style dots
  lxc_shell_script --name mycontainer --path /opt/setup.sh --env PORT="$PORT" --env DIR="$INSTALL_DIR"
```

## `lxc_start`

_Source: `src/linux/containers/lxc/lxc_start.sh`_

```text
Function: lxc_start
Description: Starts a stopped LXC container.

Arguments:
  --name NAME (string, required): Name of the container to start.
  --style STYLE (string, optional, default: spinner): Loading indicator style.
      Valid values: spinner, dots, bars, arrows, clock.
  --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  SPINNER_LOADING_STYLE (read): Default loading style constant.
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.

Returns:
  0 - Container started successfully.
  1 - Invalid or missing arguments, or LXC not installed.
  2 - Container does not exist.
  3 - Container failed to start.

Examples:
  lxc_start --name mycontainer
  lxc_start --name webserver --style dots
```

## `pct_config`

_Source: `src/linux/containers/pct/pct_config.sh`_

```text
Function: pct_config
Description: Updates configuration settings for an existing Proxmox CT container
             using 'pct set'. Accepts the same resource flags as pct_create plus
             any additional flags supported by 'pct set'.

Arguments:
  --vmid VMID (integer, required): Numeric ID of the container to configure.
  --hostname HOSTNAME (string, optional): Hostname to assign inside the container.
  --memory MB (integer, optional): Memory limit in megabytes.
  --cores N (integer, optional): Number of CPU cores to allocate.
  --style STYLE (string, optional, default: spinner): Loading indicator style.
      Valid values: spinner, dots, bars, arrows, clock.
  --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.
  Any other flags accepted by 'pct set' may also be passed and are forwarded as-is.

Globals:
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.
  SPINNER_LOADING_STYLE (read): Default loading style constant.

Returns:
  0 - Configuration updated successfully.
  1 - Invalid or missing arguments, or PCT not available on this system.
  2 - Container does not exist.
  3 - Configuration update failed.

Examples:
  pct_config --vmid 100 --memory 2048 --cores 4
  pct_config --vmid 101 --hostname newname
  pct_config --vmid 102 --memory 1024 --cores 2 --hostname myapp
```

## `pct_create`

_Source: `src/linux/containers/pct/pct_create.sh`_

```text
Function: pct_create
Description: Creates a Proxmox Container Toolkit (PCT) LXC container on a Proxmox VE host.
             PCT is a Proxmox-specific tool and cannot be installed automatically; this
             function will error if pct is not found on the system.
             When --dist and --release are supplied without --template, pveam is used to
             locate a matching template in local storage and download it if necessary.

Arguments:
  --vmid VMID (integer, required): Unique numeric ID for the new container (e.g. 100).
  --template TEMPLATE (string, optional): CT template path as shown by pveam
      (e.g. "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst").
      Required unless --dist and --release are provided.
  --dist DIST (string, optional, default: "debian"): Distribution name used to
      auto-resolve a template via pveam when --template is not provided.
  --release RELEASE (string, optional, default: "bookworm"): Distribution release used
      with --dist to auto-resolve a template via pveam. Accepts either a version number
      (e.g. "12") or a Debian/Ubuntu codename (e.g. "bookworm", "jammy"); codenames are
      automatically mapped to their version number before searching pveam.
  --arch ARCH (string, optional, default: "amd64"): Architecture used to filter
      templates when auto-resolving via pveam.
  --hostname HOSTNAME (string, optional): Hostname to assign inside the container.
  --memory MB (integer, optional, default: 512): Memory limit in megabytes.
  --cores N (integer, optional, default: 1): Number of CPU cores to allocate.
  --storage STORAGE (string, optional, default: "local-lvm"): Storage pool for the root disk.
  --disk-size GB (integer, optional, default: 8): Root disk size in gigabytes.
  --password PASSWORD (string, optional): Root password for the container.
  --style STYLE (string, optional, default: spinner): Loading indicator style.
      Valid values: spinner, dots, bars, arrows, clock.
  --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.
  SPINNER_LOADING_STYLE (read): Default loading style constant.

Returns:
  0 - Container created successfully.
  1 - Invalid or missing arguments, PCT not available, or template resolution failed.
  3 - Container creation failed.

Examples:
  pct_create --vmid 100 --template "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  pct_create --vmid 101 --dist debian --release bookworm
  pct_create --vmid 101 \
      --template "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst" \
      --hostname mycontainer \
      --memory 1024 \
      --cores 2 \
      --storage local-lvm \
      --disk-size 16
```

## `pct_delete`

_Source: `src/linux/containers/pct/pct_delete.sh`_

```text
Function: pct_delete
Description: Destroys a Proxmox CT container, permanently removing it and all its data.
             The container must be stopped first unless --force is specified.

Arguments:
  --vmid VMID (integer, required): Numeric ID of the container to destroy.
  --force (flag, optional): Stop the container before destroying if it is running.
  --purge (flag, optional): Remove the container from related configurations and jobs.
  --style STYLE (string, optional, default: spinner): Loading indicator style.
      Valid values: spinner, dots, bars, arrows, clock.
  --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.
  SPINNER_LOADING_STYLE (read): Default loading style constant.

Returns:
  0 - Container destroyed successfully.
  1 - Invalid or missing arguments, or PCT not available on this system.
  2 - Container does not exist.
  3 - Container destruction failed.

Examples:
  pct_delete --vmid 100
  pct_delete --vmid 101 --force --purge
```

## `pct_enter`

_Source: `src/linux/containers/pct/pct_enter.sh`_

```text
Function: pct_enter
Description: Opens an interactive terminal session inside a Proxmox CT container.
             If the container is stopped, it is started automatically before attaching.
             Root access uses pct enter directly; non-root access uses pct exec with su.

Arguments:
  --vmid VMID (integer, required): Numeric ID of the container to enter.
  --user USER (string, optional, default: "root"): User to run the shell as inside the container.
  --shell SHELL (string, optional, default: "/bin/bash"): Shell executable to launch (used
      when --user is not root).
  --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.
  SPINNER_LOADING_STYLE (read): Default loading style constant.

Returns:
  0 - Session ended normally.
  1 - Invalid or missing arguments, or PCT not available on this system.
  2 - Container does not exist.
  3 - Container failed to start.

Examples:
  pct_enter --vmid 100
  pct_enter --vmid 101 --user deploy --shell /bin/sh
```

## `pct_exec`

_Source: `src/linux/containers/pct/pct_exec.sh`_

```text
Function: pct_exec
Description: Runs a command inside a Proxmox CT container without opening an
             interactive session. The container does not need to be running
             (pct exec can operate on stopped containers for some commands).

Arguments:
  --vmid VMID (integer, required): Numeric ID of the container to execute the command in.
  --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.
  -- COMMAND... (required): The command and its arguments to run inside the container.
      Everything after -- is passed verbatim to pct exec.

Globals:
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.

Returns:
  0 - Command completed successfully.
  1 - Invalid or missing arguments, or PCT not available on this system.
  2 - Container does not exist.
  N - Exit code returned by the command run inside the container.

Examples:
  pct_exec --vmid 100 -- bash -c "apt-get update -qq && apt-get install -y curl"
  pct_exec --vmid 101 -- systemctl restart nginx
```

## `pct_find_vmid`

_Source: `src/linux/containers/pct/pct_find_vmid.sh`_

```text
Function: pct_find_vmid
Description: Resolves a container hostname to its numeric VMID by searching
             the output of pct list. If NAME is already a numeric VMID, it is
             validated via pct status and returned as-is.

Arguments:
  --name NAME (string, required): Container hostname or numeric VMID to resolve.

Globals:
  None

Returns:
  0 - Success; the resolved VMID is printed to stdout.
  1 - Invalid arguments or PCT not available on this system.
  2 - No container found with the given name or VMID.

Examples:
  vmid=$(pct_find_vmid --name mycontainer)
  vmid=$(pct_find_vmid --name 100)
```

## `pct_network`

_Source: `src/linux/containers/pct/pct_network.sh`_

```text
Function: pct_network
Description: Configures network interface settings for a Proxmox CT container
             using 'pct set'. Builds the --netN key=value string from individual
             flags and applies it, optionally also setting a nameserver. If the
             container is currently running it is rebooted automatically so the
             new settings take effect immediately.

Arguments:
  --vmid VMID (integer, required): Numeric ID of the container to configure.
  --bridge BRIDGE (string, optional, default: vmbr0): Host bridge to attach
      the container's interface to.
  --ip IP/PREFIX (string, optional): IP address with prefix length
      (e.g. 192.168.1.100/24), or 'dhcp' for dynamic assignment.
  --gateway GW (string, optional): Default gateway IP. Ignored when --ip dhcp.
  --dns NAMESERVERS (string, optional): Space-separated list of DNS nameserver
      IPs (e.g. "8.8.8.8 8.8.4.4"). Applied via 'pct set --nameserver'.
  --index N (integer, optional, default: 0): Network interface index.
      Controls which --netN option is configured.
  --style STYLE (string, optional, default: spinner): Loading indicator style.
      Valid values: spinner, dots, bars, arrows, clock.
  --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.
  SPINNER_LOADING_STYLE (read): Default loading style constant.

Returns:
  0 - Network configuration updated successfully.
  1 - Invalid or missing arguments, or PCT not available on this system.
  2 - Container does not exist.
  3 - Configuration update failed.

Examples:
  pct_network --vmid 100 --bridge vmbr0 --ip 192.168.1.100/24 --gateway 192.168.1.1
  pct_network --vmid 100 --ip dhcp
  pct_network --vmid 101 --ip 10.0.0.10/24 --dns "8.8.8.8 8.8.4.4"
  pct_network --vmid 102 --index 1 --bridge vmbr1 --ip 172.16.0.5/24
```

## `pct_network_show`

_Source: `src/linux/containers/pct/pct_network_show.sh`_

```text
Function: pct_network_show
Description: Displays the current network interface configuration for a
             Proxmox CT container by reading 'pct config'. Prints one or
             all netN entries depending on whether --index is given.

Arguments:
  --vmid VMID (integer, required): Numeric ID of the container to inspect.
  --index N (integer, optional): Network interface index. When given, only
      the net<N> entry is shown. Omit to show all netN entries.
  --dry-run (flag, optional): Print the system calls that would be executed
      without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.

Returns:
  0 - Configuration displayed successfully (or no interfaces found).
  1 - Invalid or missing arguments, or pct not available.
  2 - Container does not exist.
  3 - Failed to retrieve configuration.

Examples:
  pct_network_show --vmid 100
  pct_network_show --vmid 100 --index 1
```

## `pct_next_vmid`

_Source: `src/linux/containers/pct/pct_next_vmid.sh`_

```text
Function: pct_next_vmid
Description: Finds and prints the next available VMID for a new PCT container.
             Queries the Proxmox cluster API via pvesh to obtain the next free VMID
             (shared across both LXC containers and QEMU VMs). Falls back to scanning
             pct list and qm list directly when pvesh is unavailable.

Arguments:
  --start N (integer, optional, default: 100): Lowest VMID to consider. Only used
      in fallback mode; pvesh /cluster/nextid always returns the cluster-wide next ID.

Globals:
  None

Returns:
  0 - Success; the next available VMID is printed to stdout.
  1 - Invalid arguments or PCT not available on this system.

Examples:
  vmid=$(pct_next_vmid)
  vmid=$(pct_next_vmid --start 200)
```

## `pct_pull`

_Source: `src/linux/containers/pct/pct_pull.sh`_

```text
Function: pct_pull
Description: Copies a file from inside a Proxmox CT container to the host using pct pull.
             The container does not need to be running for file transfers.
             Note: pct pull only supports individual files, not directories.

Arguments:
  $1 - source (string, required): Absolute path to the file inside the container.
  $2 - destination (string, required): Path on the host to copy the file to.
  --vmid VMID (integer, required): Numeric ID of the source container.
  --style STYLE (string, optional, default: spinner): Loading indicator style.
      Valid values: spinner, dots, bars, arrows, clock.
  --message MSG (string, optional, default: "Pulling from container..."): Progress message.
  --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.
  SPINNER_LOADING_STYLE (read): Default loading style constant.

Returns:
  0 - File pulled successfully.
  1 - Invalid or missing arguments, or PCT not available on this system.
  2 - Container does not exist.
  3 - Pull operation failed.

Examples:
  pct_pull /etc/myapp.conf /tmp/myapp.conf --vmid 100
  pct_pull /var/log/app.log /tmp/app.log --vmid 101 --style dots --message "Fetching log"
```

## `pct_push`

_Source: `src/linux/containers/pct/pct_push.sh`_

```text
Function: pct_push
Description: Copies a file from the host into a Proxmox CT container using pct push.
             The container does not need to be running for file transfers.
             Note: pct push only supports individual files, not directories.

Arguments:
  $1 - source (string, required): Path to the file on the host to copy.
  $2 - destination (string, required): Absolute path inside the container to copy to.
  --vmid VMID (integer, required): Numeric ID of the target container.
  --perms PERMS (string, optional): File permissions to set (e.g. "0644").
  --user USER (string, optional): Owner user to set inside the container.
  --group GROUP (string, optional): Owner group to set inside the container.
  --style STYLE (string, optional, default: spinner): Loading indicator style.
      Valid values: spinner, dots, bars, arrows, clock.
  --message MSG (string, optional, default: "Pushing to container..."): Progress message.
  --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.
  SPINNER_LOADING_STYLE (read): Default loading style constant.

Returns:
  0 - File pushed successfully.
  1 - Invalid or missing arguments, or PCT not available on this system.
  2 - Source file does not exist, or container does not exist.
  3 - Push operation failed.

Examples:
  pct_push /etc/myapp.conf /etc/myapp.conf --vmid 100
  pct_push /opt/app/config.json /opt/app/config.json --vmid 101 --perms 0644 --user root
```

## `pct_shell_script`

_Source: `src/linux/containers/pct/pct_shell_script.sh`_

```text
Function: pct_shell_script
Description: Creates an executable shell script file inside a Proxmox CT container
             by writing the provided content to a temporary file on the host, pushing
             it into the container with 0755 permissions, and cleaning up the temporary
             file. The container does not need to be running for file transfers.

Arguments:
  --vmid VMID       (integer, required): Numeric ID of the target container.
  --content CONTENT (string, optional): The shell script content to write into the file.
                    Defaults to the value of the $script variable when omitted.
  --path PATH       (string, required): Absolute destination path inside the container
                    (e.g. /usr/local/bin/myscript.sh).
  --env KEY=VALUE   (string, optional, repeatable): Prepend an 'export KEY=VALUE' line
                    to the script. Use to inject outer-shell values into the container
                    script without relying on heredoc variable expansion.
  --style STYLE     (string, optional, default: spinner): Loading indicator style.
      Valid values: spinner, dots, bars, arrows, clock.
  --dry-run         (flag, optional): Print the system calls that would be executed
                    without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  script                (read): Fallback script content used when --content is omitted.
  SPINNER_LOADING_STYLE (read): Default loading style constant.
  IS_DRY_RUN            (read): When "true", enables dry-run mode by default.

Returns:
  0 - Script created successfully.
  1 - Invalid or missing arguments, or PCT not available on this system.
  2 - Container does not exist.
  3 - Push operation failed.

Examples:
  pct_shell_script --vmid 100 --content '#!/bin/bash\necho hello' --path /usr/local/bin/hello.sh
  pct_shell_script --vmid 101 --content "$(cat setup.sh)" --path /opt/setup.sh --style dots
  pct_shell_script --vmid 100 --path /opt/setup.sh --env PORT="$PORT" --env DIR="$INSTALL_DIR"
```

## `pct_start`

_Source: `src/linux/containers/pct/pct_start.sh`_

```text
Function: pct_start
Description: Starts a stopped Proxmox CT container.

Arguments:
  --vmid VMID (integer, required): Numeric ID of the container to start.
  --style STYLE (string, optional, default: spinner): Loading indicator style.
      Valid values: spinner, dots, bars, arrows, clock.
  --dry-run (flag, optional): Print the system calls that would be executed without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.
  SPINNER_LOADING_STYLE (read): Default loading style constant.

Returns:
  0 - Container started successfully.
  1 - Invalid or missing arguments, or PCT not available on this system.
  2 - Container does not exist.
  3 - Container failed to start.

Examples:
  pct_start --vmid 100
  pct_start --vmid 101 --style dots
```
