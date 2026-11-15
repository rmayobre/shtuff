# Systemd services and timers

Linux only. Writes unit files and runs `systemctl`. OpenRC (Alpine) and launchd (macOS) equivalents are not implemented yet.

> Generated from the header comments in `src/` by `docs/generate-reference.sh`. Edit the headers, not this file.

## `service`

_Source: `src/linux/systemd/service.sh`_

```text
Function: service
Description: Generates a systemd service unit file and, by default, enables and starts it.

Arguments:
  --name NAME (string, required): Service name; .service extension is appended automatically if omitted.
  --description DESC (string, required): Human-readable description written to the [Unit] section.
  --exec-start COMMAND (string, required): Full command used to start the service.
  --working-directory DIR (string, optional): Working directory set for the service process.
  --user USER (string, optional): System user the service process runs as.
  --group GROUP (string, optional): System group the service process runs as.
  --restart POLICY (string, optional, default: on-failure): Systemd restart policy.
  --restart-sec SECONDS (integer, optional, default: 5): Seconds to wait before restarting.
  --wanted-by TARGET (string, optional, default: multi-user.target): Systemd install target.
  --environment ENV (string, optional): Space-separated VAR=value pairs added as Environment= directives.
  --exec-start-pre COMMAND (string, optional): Command to run before ExecStart.
  --exec-stop COMMAND (string, optional): Command to run when stopping the service.
  --output-dir DIR (string, optional, default: /etc/systemd/system): Directory to write the unit file into.
  --lazy (flag, optional): Write the unit file but skip daemon-reload, enable, and start.
  --dry-run (flag, optional): Print the file that would be created without writing it.
      Defaults to IS_DRY_RUN if not specified.
  -n NAME (string, required): Short form of --name.
  -d DESC (string, required): Short form of --description.
  -e COMMAND (string, required): Short form of --exec-start.
  -w DIR (string, optional): Short form of --working-directory.
  -u USER (string, optional): Short form of --user.
  -g GROUP (string, optional): Short form of --group.
  -r POLICY (string, optional): Short form of --restart.
  -o DIR (string, optional): Short form of --output-dir.

Globals:
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.

Returns:
  0 - Service unit file created (and enabled/started unless --lazy).
  1 - Required argument missing or unknown option provided.

Examples:
  service \
      --name "myapp" \
      --description "My Web Application" \
      --exec-start "/usr/bin/node /opt/myapp/server.js" \
      --user "www-data" \
      --working-directory "/opt/myapp"

  service \
      --name "api-server" \
      --description "API Server" \
      --exec-start "/usr/local/bin/api-server" \
      --user "apiuser" \
      --environment "PORT=8080 NODE_ENV=production" \
      --restart "always" \
      --lazy
```

## `timer`

_Source: `src/linux/systemd/timer.sh`_

```text
Function: timer
Description: Generates a systemd timer unit file and, by default, enables and starts it.

Arguments:
  --name NAME (string, required): Timer name without the .timer extension.
      Must contain only letters, numbers, underscores, and hyphens.
  --description DESC (string, optional): Human-readable description for the [Unit] section.
      Defaults to "Timer for <name>" when omitted.
  --on-calendar SPEC (string, optional): Calendar expression for scheduled activation
      (e.g., "daily", "*-*-* 02:00:00").
  --on-boot-sec TIME (string, optional): Elapsed time after system boot before first activation
      (e.g., "5min", "1h").
  --on-unit-active-sec TIME (string, optional): Elapsed time after the unit was last activated
      before re-activation (e.g., "1h").
  --on-unit-inactive-sec TIME (string, optional): Elapsed time after the unit was last deactivated
      before re-activation (e.g., "30min").
  --randomized-delay TIME (string, optional): Random delay added to the scheduled time
      (e.g., "30min").
  --persistent (flag, optional): When set, missed timer events are caught up on next boot.
  --unit NAME (string, optional): Name of the service unit to activate.
      Defaults to <name>.service when omitted.
  --wanted-by TARGET (string, optional, default: timers.target): Systemd install target.
  --output-dir DIR (string, optional, default: /etc/systemd/system): Directory to write the unit file into.
  --force (flag, optional): Overwrite an existing timer file at the output path.
  --lazy (flag, optional): Write the unit file but skip daemon-reload, enable, and start.
  --dry-run (flag, optional): Print the file that would be created without writing it.
      Defaults to IS_DRY_RUN if not specified.
  --help (flag, optional): Print usage information and return without creating a file.
  -n NAME (string, required): Short form of --name.
  -d DESC (string, optional): Short form of --description.
  -c SPEC (string, optional): Short form of --on-calendar.
  -b TIME (string, optional): Short form of --on-boot-sec.
  -a TIME (string, optional): Short form of --on-unit-active-sec.
  -i TIME (string, optional): Short form of --on-unit-inactive-sec.
  -r TIME (string, optional): Short form of --randomized-delay.
  -p (flag, optional): Short form of --persistent.
  -u NAME (string, optional): Short form of --unit.
  -w TARGET (string, optional): Short form of --wanted-by.
  -o DIR (string, optional): Short form of --output-dir.
  -f (flag, optional): Short form of --force.
  -h (flag, optional): Short form of --help.

Globals:
  _TIMER_DEFAULT_OUTPUT_DIR (read): Default directory used when --output-dir is not provided.
  _TIMER_DEFAULT_WANTED_BY (read): Default install target used when --wanted-by is not provided.
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.

Returns:
  0 - Timer unit file created (and enabled/started unless --lazy), or --help was requested.
  1 - Invalid or missing arguments (e.g., blank name, unexpected flag).
  2 - File system error (output directory does not exist, or file already exists without --force).
  3 - Permission denied writing the timer file.

Examples:
  timer --name backup --on-calendar daily --persistent
  timer --name cleanup --on-boot-sec 5min --on-unit-active-sec 1h --description "Periodic cleanup"
  timer --name maintenance --on-calendar "Sun *-*-* 03:00:00" --randomized-delay 30min --persistent --lazy
```
