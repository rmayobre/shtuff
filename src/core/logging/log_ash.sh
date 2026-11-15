# A standardized logging for POSIX sh / BusyBox ash scripts (same API as log_bash.sh):
# - Multiple log levels with hierarchical filtering
# - Colored console output
# - Optional file logging
# - Timestamp support
# - Environment variable configuration
#
# Usage:
#   source logging.sh
#   log_info "Your message here"
#
# Environment Variables:
#   LOG_LEVEL     - Set logging threshold (ERROR, WARN, INFO, DEBUG, VERBOSE)
#   LOG_FILE      - Redirect all log output to this file path (suppresses terminal output)
#   LOG_TIMESTAMP - Set to "false" to disable timestamps
#   VERBOSE_FILE  - Override the path for the verbose temp file (default: /tmp/script_$$.log)

readonly ERROR_LEVEL="error"
readonly WARN_LEVEL="warn"
readonly INFO_LEVEL="info"
readonly DEBUG_LEVEL="debug"
readonly VERBOSE_LEVEL="verbose"

# Logging configuration
LOG_LEVEL=${LOG_LEVEL:-"$INFO_LEVEL"}  # Default log level
LOG_FILE=${LOG_FILE:-""}        # Optional log file path
LOG_TIMESTAMP=${LOG_TIMESTAMP:-true}  # Include timestamps

# Verbose output file — always written when verbose() / log_output() is called.
# Overridable via environment; defaults to a per-process temp file.
VERBOSE_FILE="${VERBOSE_FILE:-${TMPDIR:-/tmp}/script_$$.log}"
VERBOSE_LOGS="$VERBOSE_FILE"

# Log level hierarchy (lower number = higher priority).
# Implemented with case statements instead of associative arrays so the file
# also loads on bash 3.2 (macOS system bash).
_log_level_num() {
    case "$1" in
        "$ERROR_LEVEL")   echo 1 ;;
        "$WARN_LEVEL")    echo 2 ;;
        "$INFO_LEVEL")    echo 3 ;;
        "$DEBUG_LEVEL")   echo 4 ;;
        "$VERBOSE_LEVEL") echo 5 ;;
        *) return 1 ;;
    esac
}

# Color codes for console output.
_log_color() {
    case "$1" in
        "$ERROR_LEVEL")   printf '%s' "$RED" ;;
        "$WARN_LEVEL")    printf '%s' "$YELLOW" ;;
        "$INFO_LEVEL")    printf '%s' "$GREEN" ;;
        "$DEBUG_LEVEL")   printf '%s' "$CYAN" ;;
        "$VERBOSE_LEVEL") printf '%s' "$MAGENTA" ;;
    esac
}

# Function: _log
# Description: Logs a message at the given level if it falls within the current threshold.
#              Verbose messages are always appended to VERBOSE_FILE and are mirrored to the
#              console only when LOG_LEVEL=verbose. POSIX sh / ash implementation.
#
# Arguments:
#   $1 - level (string, required): Log level (error, warn, info, debug, verbose).
#   $@ - message (string, required): Message; remaining arguments are joined with spaces.
#
# Globals:
#   LOG_LEVEL (read): Current logging threshold.
#   LOG_FILE (read): Optional file path; when set, non-verbose messages go only to this file.
#   LOG_TIMESTAMP (read): When "true", a timestamp prefix is prepended.
#   RESET (read): ANSI reset sequence applied after colored TTY output.
#   VERBOSE_FILE (read): Path to the verbose temp file.
#
# Returns:
#   0 - Message logged, or suppressed by the threshold.
#   1 - Invalid or missing level, or empty message.
#
# Examples:
#   _log "info" "Application started"
_log() {
    if [ $# -lt 2 ]; then
        echo "_log: insufficient arguments. Usage: _log LEVEL MESSAGE" >&2
        return 1
    fi
    [ -n "$1" ] || { echo "Log level was left empty." >&2; return 1; }

    _l_level="$1"
    _l_num=$(_log_level_num "$_l_level") || { echo "Invalid log level: $_l_level" >&2; return 1; }
    _l_global=$(_log_level_num "$LOG_LEVEL") || _l_global=3
    shift
    _l_msg="$*"
    [ -n "$_l_msg" ] || { echo "Log message is empty." >&2; return 1; }

    if [ "$_l_num" -gt "$_l_global" ] && [ "$_l_level" != "$VERBOSE_LEVEL" ]; then
        return 0
    fi

    _l_ts=""
    [ "$LOG_TIMESTAMP" = "true" ] && _l_ts="$(date '+%Y-%m-%d %H:%M:%S') "
    _l_out="${_l_ts}[${_l_level}] ${_l_msg}"

    if [ "$_l_level" = "$VERBOSE_LEVEL" ]; then
        mkdir -p "$(dirname "$VERBOSE_FILE")" 2>/dev/null
        printf '%s\n' "$_l_out" >> "$VERBOSE_FILE"
        [ "$LOG_LEVEL" = "$VERBOSE_LEVEL" ] || return 0
    elif [ -n "$LOG_FILE" ]; then
        mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
        printf '%s\n' "$_l_out" >> "$LOG_FILE"
        return 0
    fi

    if [ -t 2 ]; then
        printf '%b%s%b\n' "$(_log_color "$_l_level")" "$_l_out" "$RESET" >&2
    else
        printf '%s\n' "$_l_out" >&2
    fi
}

# Function: error
# Description: Logs a message at error level; always emitted regardless of LOG_LEVEL threshold.
#
# Arguments:
#   $@ - message (string, required): Message to log; all arguments are joined with spaces.
#
# Globals:
#   ERROR_LEVEL (read): Constant string identifying the error log level.
#
# Returns:
#   0 - Message logged successfully.
#   1 - Empty message provided.
#
# Examples:
#   error "Database connection failed"
#   error "Required file not found:" "$path"
error() {
    _log "$ERROR_LEVEL" "$@"
}

# Function: warn
# Description: Logs a message at warn level; suppressed when LOG_LEVEL is set to error.
#
# Arguments:
#   $@ - message (string, required): Message to log; all arguments are joined with spaces.
#
# Globals:
#   WARN_LEVEL (read): Constant string identifying the warn log level.
#
# Returns:
#   0 - Message logged successfully, or suppressed by log level threshold.
#   1 - Empty message provided.
#
# Examples:
#   warn "Configuration file not found, using defaults"
#   warn "Deprecated flag used:" "$flag"
warn() {
    _log "$WARN_LEVEL" "$@"
}

# Function: info
# Description: Logs a message at info level; suppressed when LOG_LEVEL is set to error or warn.
#
# Arguments:
#   $@ - message (string, required): Message to log; all arguments are joined with spaces.
#
# Globals:
#   INFO_LEVEL (read): Constant string identifying the info log level.
#
# Returns:
#   0 - Message logged successfully, or suppressed by log level threshold.
#   1 - Empty message provided.
#
# Examples:
#   info "Application started successfully"
#   info "Listening on port" "$port"
info() {
    _log "$INFO_LEVEL" "$@"
}

# Function: debug
# Description: Logs a message at debug level; only emitted when LOG_LEVEL=debug.
#
# Arguments:
#   $@ - message (string, required): Message to log; all arguments are joined with spaces.
#
# Globals:
#   DEBUG_LEVEL (read): Constant string identifying the debug log level.
#
# Returns:
#   0 - Message logged successfully, or suppressed by log level threshold.
#   1 - Empty message provided.
#
# Examples:
#   debug "Processing user ID: 12345"
#   debug "Resolved path:" "$path"
debug() {
    _log "$DEBUG_LEVEL" "$@"
}

# Function: verbose
# Description: Logs a message at verbose level. Always written to VERBOSE_FILE regardless of
#              LOG_LEVEL. Also printed to the console when LOG_LEVEL=verbose.
#
# Arguments:
#   $@ - message (string, required): Message to log; all arguments are joined with spaces.
#
# Globals:
#   VERBOSE_LEVEL (read): Constant string identifying the verbose log level.
#   VERBOSE_FILE (write): Path to the verbose temp file; message is appended here.
#   VERBOSE_LOGS (read): Public alias for VERBOSE_FILE.
#
# Returns:
#   0 - Message written to VERBOSE_FILE (and optionally to console).
#   1 - Empty message provided.
#
# Examples:
#   verbose "Detailed diagnostic info"
#   verbose "Raw output line:" "$line"
verbose() {
    _log "$VERBOSE_LEVEL" "$@"
}

# Function: log_output
# Description: Reads lines from stdin and logs each at verbose level. Each line is always
#              appended to VERBOSE_FILE; lines are also mirrored to the console when
#              LOG_LEVEL=verbose. Use as a pipe target to capture raw command output instead
#              of discarding it with /dev/null.
#
# Arguments:
#   None — reads from stdin.
#
# Globals:
#   VERBOSE_LEVEL (read): Constant string identifying the verbose log level.
#   VERBOSE_FILE (write): Path to the verbose temp file; each line is appended here.
#   VERBOSE_LOGS (read): Public alias for VERBOSE_FILE.
#
# Returns:
#   0 - All lines consumed; each non-empty line written to VERBOSE_FILE.
#
# Examples:
#   some_command 2>&1 | log_output
log_output() {
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        _log "$VERBOSE_LEVEL" "$line"
    done
}
