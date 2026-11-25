# monitor (POSIX sh / BusyBox ash implementation; see monitor_bash.sh and monitor_zsh.sh for the
# other interpreters). Ash has no arrays, so a command given after -- is kept in "$@".

readonly SPINNER_LOADING_STYLE="spinner"
readonly DOTS_LOADING_STYLE="dots"
readonly BARS_LOADING_STYLE="bars"
readonly ARROWS_LOADING_STYLE="arrows"
readonly CLOCK_LOADING_STYLE="clock"

# The default loading style picked if not defined in the "monitor" function.
DEFAULT_LOADING_STYLE=$SPINNER_LOADING_STYLE

# PID of a command started by monitor; read by the interrupt handler.
_MONITOR_PID=""

# Function: monitor
# Description: Runs or watches a process, replacing its output with a loading indicator and then a
#              status message. In command mode (-- COMMAND [ARGS...]) monitor starts the command
#              itself and captures its stdout and stderr in VERBOSE_FILE. In PID mode it watches a
#              process the caller already started in the background (the caller is responsible for
#              redirecting that process's output).
#              The animated indicator is skipped when stdout is not a terminal or when
#              LOG_LEVEL=verbose; in verbose mode a command's output streams to the console.
#
# Arguments:
#   $1 - pid (integer, optional): Process ID of a background process to watch. Omit it and give a
#        command after -- instead.
#   --message MSG (string, optional, default: "Processing"): Message shown alongside the loading indicator.
#   --style STYLE (string, optional, default: "spinner"): Loading indicator style.
#       Valid values: spinner, dots, bars, arrows, clock.
#   --success_msg MSG (string, optional, default: "Process completed"): Message printed on success.
#   --error_msg MSG (string, optional, default: "Process failed"): Message printed on failure.
#   --dry-run (flag, optional): Do nothing; in command mode print the command instead of running it.
#   -- COMMAND [ARGS...] (string, optional): Command to run and capture. Must come after all options.
#
# Globals:
#   DEFAULT_LOADING_STYLE (read): Fallback style used when --style is not provided.
#   SPINNER_LOADING_STYLE (read): Constant identifying the spinner style.
#   DOTS_LOADING_STYLE (read): Constant identifying the dots style.
#   BARS_LOADING_STYLE (read): Constant identifying the bars style.
#   ARROWS_LOADING_STYLE (read): Constant identifying the arrows style.
#   CLOCK_LOADING_STYLE (read): Constant identifying the clock style.
#   VERBOSE_FILE (write): Receives the captured output of a command started by monitor.
#   LOG_LEVEL (read): When set to "verbose", the loading indicator is skipped.
#   VERBOSE_LEVEL (read): Constant identifying the verbose log level.
#   IS_DRY_RUN (read): When "true", behaves as if --dry-run was passed.
#   _MONITOR_PID (write): PID of the command monitor started, used by the interrupt handler.
#
# Returns:
#   0 - The process exited successfully.
#   1 - No PID or command given, invalid PID, PID does not exist, or unknown loading style.
#   N - Exit code of the process when it exits with a non-zero status (143 if it was interrupted).
#
# Examples:
#   # Command mode: monitor runs the command and captures its output
#   monitor --message "Building project" --success_msg "Build complete!" \
#       --error_msg "Build failed!" -- make all || exit 1
#
#   # PID mode: the caller starts the process and redirects its output
#   some_long_command >> "$VERBOSE_FILE" 2>&1 &
#   monitor $! --style dots --message "Downloading" || exit 1
monitor() {
    local pid=""
    local style="$DEFAULT_LOADING_STYLE"
    local message="Processing"
    local success_msg="Process completed"
    local error_msg="Process failed"
    local dry_run="${IS_DRY_RUN:-false}"
    local exit_code=0
    local has_cmd="false"

    # A leading number is the PID of a process the caller already started.
    case "${1:-}" in
        ''|-*) ;;
        *[!0-9]*)
            error "Invalid PID: $1"
            return 1
            ;;
        *)
            pid="$1"
            shift
            ;;
    esac

    while [ $# -gt 0 ]; do
        case "$1" in
            -m|--message)      message="$2";     shift 2 ;;
            -s|--style)        style="$2";       shift 2 ;;
            -sm|--success_msg) success_msg="$2"; shift 2 ;;
            -e|--error_msg)    error_msg="$2";   shift 2 ;;
            --dry-run)         dry_run="true";   shift ;;
            --)
                # Whatever is left in "$@" is the command to run.
                shift
                [ $# -gt 0 ] && has_cmd="true"
                break
                ;;
            *) break ;;
        esac
    done

    if [ -z "$pid" ] && [ "$has_cmd" = "false" ]; then
        error "monitor: no PID or command provided (usage: monitor PID [options] | monitor [options] -- COMMAND)"
        return 1
    fi

    if [ "$dry_run" = "true" ]; then
        [ "$has_cmd" = "true" ] && info "[DRY RUN] $*"
        return 0
    fi

    case "$style" in
        "$SPINNER_LOADING_STYLE"|"$DOTS_LOADING_STYLE"|"$BARS_LOADING_STYLE"|"$ARROWS_LOADING_STYLE"|"$CLOCK_LOADING_STYLE") ;;
        *)
            error "Unknown loading style: $style"
            return 1
            ;;
    esac

    local animate="true"
    if [ "$LOG_LEVEL" = "$VERBOSE_LEVEL" ] || [ ! -t 1 ]; then
        animate="false"
    fi

    local ran="false"
    if [ "$has_cmd" = "true" ]; then
        if [ "$LOG_LEVEL" = "$VERBOSE_LEVEL" ]; then
            # Verbose: let the command's output stream to the console.
            "$@" || exit_code=$?
            ran="true"
        else
            mkdir -p "$(dirname "$VERBOSE_FILE")" 2>/dev/null
            printf '$ %s\n' "$*" >> "$VERBOSE_FILE"
            "$@" >> "$VERBOSE_FILE" 2>&1 &
            pid=$!
        fi
    elif ! kill -0 "$pid" 2>/dev/null; then
        error "Process $pid does not exist"
        return 1
    fi

    if [ "$ran" != "true" ]; then
        if [ "$animate" = "true" ]; then
            # Hide the cursor; restore it (and stop our command) if interrupted.
            _MONITOR_PID=""
            [ "$has_cmd" = "true" ] && _MONITOR_PID="$pid"
            printf '\033[?25l'
            trap 'printf "\033[A\033[2K\033[?25h"; [ -n "$_MONITOR_PID" ] && kill "$_MONITOR_PID" 2>/dev/null' INT TERM

            case "$style" in
                "$SPINNER_LOADING_STYLE") draw_loading_spinner "$pid" "$message" ;;
                "$DOTS_LOADING_STYLE")    draw_loading_dots "$pid" "$message" ;;
                "$BARS_LOADING_STYLE")    draw_loading_bars "$pid" "$message" ;;
                "$ARROWS_LOADING_STYLE")  draw_loading_arrows "$pid" "$message" ;;
                "$CLOCK_LOADING_STYLE")   draw_loading_clock "$pid" "$message" ;;
            esac
        fi

        # Collect the exit code.
        wait "$pid" 2>/dev/null || exit_code=$?

        if [ "$animate" = "true" ]; then
            # Erase the indicator row and show the cursor again.
            printf '\033[A\033[2K\033[?25h'
            trap - INT TERM
            _MONITOR_PID=""
        fi
    fi

    if [ "$exit_code" -eq 0 ] && [ -n "$success_msg" ]; then
        info "$success_msg"
    elif [ "$exit_code" -ne 0 ] && [ -n "$error_msg" ]; then
        error "$error_msg"
        if [ "$has_cmd" = "true" ] && [ "$LOG_LEVEL" != "$VERBOSE_LEVEL" ]; then
            warn "Command output was saved to $VERBOSE_FILE"
        fi
    fi

    return "$exit_code"
}
