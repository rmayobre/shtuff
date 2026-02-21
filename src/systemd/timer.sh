#!/usr/bin/env bash
#
readonly _TIMER_DEFAULT_OUTPUT_DIR="/etc/systemd/system"
readonly _TIMER_DEFAULT_WANTED_BY="timers.target"

# Function: timer
# Description: Generates a systemd timer unit file with configurable scheduling options.
#
# Arguments:
#   --name NAME (string, required): Timer name without the .timer extension.
#       Must contain only letters, numbers, underscores, and hyphens.
#   --description DESC (string, optional): Human-readable description for the [Unit] section.
#       Defaults to "Timer for <name>" when omitted.
#   --on-calendar SPEC (string, optional): Calendar expression for scheduled activation
#       (e.g., "daily", "*-*-* 02:00:00").
#   --on-boot-sec TIME (string, optional): Elapsed time after system boot before first activation
#       (e.g., "5min", "1h").
#   --on-unit-active-sec TIME (string, optional): Elapsed time after the unit was last activated
#       before re-activation (e.g., "1h").
#   --on-unit-inactive-sec TIME (string, optional): Elapsed time after the unit was last deactivated
#       before re-activation (e.g., "30min").
#   --randomized-delay TIME (string, optional): Random delay added to the scheduled time
#       (e.g., "30min").
#   --persistent (flag, optional): When set, missed timer events are caught up on next boot.
#   --unit NAME (string, optional): Name of the service unit to activate.
#       Defaults to <name>.service when omitted.
#   --wanted-by TARGET (string, optional, default: timers.target): Systemd install target.
#   --output-dir DIR (string, optional, default: /etc/systemd/system): Directory to write the unit file into.
#   --force (flag, optional): Overwrite an existing timer file at the output path.
#   --help (flag, optional): Print usage information and return without creating a file.
#   -n NAME (string, required): Short form of --name.
#   -d DESC (string, optional): Short form of --description.
#   -c SPEC (string, optional): Short form of --on-calendar.
#   -b TIME (string, optional): Short form of --on-boot-sec.
#   -a TIME (string, optional): Short form of --on-unit-active-sec.
#   -i TIME (string, optional): Short form of --on-unit-inactive-sec.
#   -r TIME (string, optional): Short form of --randomized-delay.
#   -p (flag, optional): Short form of --persistent.
#   -u NAME (string, optional): Short form of --unit.
#   -w TARGET (string, optional): Short form of --wanted-by.
#   -o DIR (string, optional): Short form of --output-dir.
#   -f (flag, optional): Short form of --force.
#   -h (flag, optional): Short form of --help.
#
# Globals:
#   _TIMER_DEFAULT_OUTPUT_DIR (read): Default directory used when --output-dir is not provided.
#   _TIMER_DEFAULT_WANTED_BY (read): Default install target used when --wanted-by is not provided.
#
# Returns:
#   0 - Timer unit file created successfully, or --help was requested.
#   1 - Invalid or missing arguments (e.g., blank name, unexpected flag).
#   2 - File system error (output directory does not exist, or file already exists without --force).
#   3 - Permission denied writing the timer file.
#
# Examples:
#   timer --name backup --on-calendar daily --persistent
#   timer --name cleanup --on-boot-sec 5min --on-unit-active-sec 1h --description "Periodic cleanup"
#   timer --name maintenance --on-calendar "Sun *-*-* 03:00:00" --randomized-delay 30min --persistent
timer() {
    local name=""
    local description=""
    local on_calendar=""
    local on_boot_sec=""
    local on_unit_active_sec=""
    local on_unit_inactive_sec=""
    local randomized_delay=""
    local persistent="false"
    local unit=""
    local wanted_by="${_TIMER_DEFAULT_WANTED_BY}"
    local output_dir="${_TIMER_DEFAULT_OUTPUT_DIR}"
    local force="false"
    local has_schedule="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2";
                shift 2
                ;;
            -d|--description)
                description="$2"
                shift 2
                ;;
            -c|--on-calendar)
                has_schedule="true"
                on_calendar="$2";
                shift 2
                ;;
            -b|--on-boot-sec)
                has_schedule="true"
                on_boot_sec="$2";
                shift 2
                ;;
            -a|--on-unit-active-sec)
                has_schedule="true"
                on_unit_active_sec="$2";
                shift 2
                ;;
            -i|--on-unit-inactive-sec)
                has_schedule="true"
                on_unit_inactive_sec="$2";
                shift 2
                ;;
            -r|--randomized-delay)
                randomized_delay="$2";
                shift 2
                ;;
            -p|--persistent)
                persistent="true";
                shift
                ;;
            -u|--unit)
                unit="$2";
                shift 2
                ;;
            -w|--wanted-by)
                wanted_by="$2";
                shift 2
                ;;
            -o|--output-dir)
                output_dir="$2"
                shift 2
                ;;
            -f|--force)
                force="true"
                shift
                ;;
            -h|--help)
                _timer_show_help
                return 0
                ;;
            *)
                error "Unexpected argument: $1"
                _timer_show_help
                return 1
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        error "Timer cannot have a null or blank name."
        return 1;
    fi

    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error "Invalid timer name: $name"
        error "Name must contain only letters, numbers, underscores, and hyphens"
        return 1
    fi

    # Validate output directory exists (or can be created)
    if [[ ! -d "$output_dir" ]]; then
        error "Output directory does not exist: $output_dir"
        return 2
    fi

    local content=""

    # [Unit] section
    content+="[Unit]\n"
    if [[ -n "${description}" ]]; then
        content+="Description=${description}\n"
    else
        content+="Description=Timer for ${name}\n"
    fi

    # New line between sections
    content+="\n"

    # [Timer] section
    content+="[Timer]\n"

    # Scheduling options
    if [[ -n "${on_calendar}" ]]; then
        content+="OnCalendar=${on_calendar}\n"
    fi

    if [[ -n "${on_boot_sec}" ]]; then
        content+="OnBootSec=${on_boot_sec}\n"
    fi

    if [[ -n "${on_unit_active_sec}" ]]; then
        content+="OnUnitActiveSec=${on_unit_active_sec}\n"
    fi

    if [[ -n "${on_unit_inactive_sec}" ]]; then
        content+="OnUnitInactiveSec=${on_unit_inactive_sec}\n"
    fi

    # Additional options
    if [[ -n "${randomized_delay}" ]]; then
        content+="RandomizedDelaySec=${randomized_delay}\n"
    fi

    if [[ "${persistent}" == "true" ]]; then
        content+="Persistent=true\n"
    fi

    if [[ -n "${unit}" ]]; then
        content+="Unit=${unit}\n"
    fi

    content+="\n"

    # [Install] section
    content+="[Install]\n"
    content+="WantedBy=${wanted_by}\n"


    # Determine output path
    local output_path="$output_dir/$name.timer"

    # Check if timer file exists
    if [[ -f "${output_path}" ]] && [[ "${force}" != "true" ]]; then
        error "File already exists: ${output_path}"
        error "Use --force to overwrite"
        return 2
    fi

    if ! printf "%b" "${content}" > "${output_path}"; then
        error "Failed to write timer file: ${output_path}"
        return 3
    fi

    chmod 644 "${output_path}"

    info "Created timer file: ${output_path}"

    return 0
}

# Function: _timer_show_help
# Description: Prints timer usage information to stdout.
#
# Arguments:
#   None
#
# Globals:
#   _TIMER_DEFAULT_OUTPUT_DIR (read): Displayed as the default output directory in the help text.
#   _TIMER_DEFAULT_WANTED_BY (read): Displayed as the default install target in the help text.
#
# Returns:
#   0 - Help text printed successfully.
#
# Examples:
#   _timer_show_help
_timer_show_help() {
    cat << EOF
Usage: timer [OPTIONS] --name <timer-name>

Generate systemd timer unit files with configurable scheduling options.

REQUIRED:
    -n, --name NAME                 Timer name (without .timer extension)

SCHEDULING OPTIONS (at least one required):
    -c, --on-calendar SPEC          Calendar expression (e.g., "daily", "*-*-* 02:00:00")
    -b, --on-boot-sec TIME          Time after boot (e.g., "5min", "1h")
    -a, --on-unit-active-sec TIME   Time after unit was last activated
    -i, --on-unit-inactive-sec TIME Time after unit was last deactivated

TIMER OPTIONS:
    -d, --description DESC          Timer description
    -u, --unit NAME                 Service unit to activate (default: <name>.service)
    -r, --randomized-delay TIME     Random delay added to scheduled time
    -p, --persistent                Remember missed runs and catch up
    -w, --wanted-by TARGET          Install target (default: ${_TIMER_DEFAULT_WANTED_BY})

OUTPUT OPTIONS:
    -o, --output-dir DIR            Output directory (default: ${_TIMER_DEFAULT_OUTPUT_DIR})
    -f, --force                     Overwrite existing files

GENERAL OPTIONS:
    -h, --help                      Show this help message

CALENDAR EXPRESSION EXAMPLES:
    hourly                          Every hour
    daily                           Every day at midnight
    weekly                          Every Monday at midnight
    monthly                         First day of each month at midnight
    *-*-* 06:00:00                  Daily at 6:00 AM
    Mon,Fri *-*-* 18:30:00          Monday and Friday at 6:30 PM
    *-*-01 00:00:00                 First day of every month
    *-*-* *:00/15:00                Every 15 minutes

TIME SPAN EXAMPLES:
    30s, 30sec, 30seconds           30 seconds
    5m, 5min, 5minutes              5 minutes
    2h, 2hr, 2hours                 2 hours
    1d, 1day                        1 day
    1w, 1week                       1 week

EXAMPLES:
    # Daily backup at 2 AM
    timer --name backup --on-calendar "*-*-* 02:00:00" \\
        --description "Daily backup timer" --persistent

    # Run 5 minutes after boot, then every hour
    timer --name cleanup --on-boot-sec 5min --on-unit-active-sec 1h \\
        --description "Periodic cleanup"

    # Weekly maintenance on Sunday at 3 AM with random delay
    timer --name maintenance --on-calendar "Sun *-*-* 03:00:00" \\
        --randomized-delay 30min --persistent

EOF
}
