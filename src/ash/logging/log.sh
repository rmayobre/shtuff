#!/bin/sh
# A standardized logging for sh scripts:
# - Multiple log levels with hierarchical filtering
# - Colored console output
# - Optional file logging
# - Timestamp support
# - Environment variable configuration
#
# Usage:
#   . logging.sh
#   info "Your message here"
#
# Environment Variables:
#   LOG_LEVEL     - Set logging threshold (error, warn, info, debug)
#   LOG_FILE      - Enable file logging by setting file path
#   LOG_TIMESTAMP - Set to "false" to disable timestamps

readonly ERROR_LEVEL="error"
readonly WARN_LEVEL="warn"
readonly INFO_LEVEL="info"
readonly DEBUG_LEVEL="debug"

# Logging configuration
LOG_LEVEL=${LOG_LEVEL:-"$INFO_LEVEL"}  # Default log level
LOG_FILE=${LOG_FILE:-""}               # Optional log file path
LOG_TIMESTAMP=${LOG_TIMESTAMP:-true}   # Include timestamps

# Function: _log_level_num
# Description: Returns the numeric priority for a log level name.
#
# Arguments:
#   $1 - level (string, required): Log level name (error, warn, info, debug).
#
# Returns:
#   0 - Always succeeds; prints the priority to stdout.
#
# Examples:
#   _log_level_num "info"   # prints 3
_log_level_num() {
    case "$1" in
        error) printf '1' ;;
        warn)  printf '2' ;;
        info)  printf '3' ;;
        debug) printf '4' ;;
        *)     printf '0' ;;
    esac
}

# Function: _log_color
# Description: Returns the ANSI color code for a log level name.
#
# Arguments:
#   $1 - level (string, required): Log level name (error, warn, info, debug).
#
# Returns:
#   0 - Always succeeds; prints the ANSI escape sequence to stdout.
#
# Examples:
#   _log_color "error"   # prints the RED escape code
_log_color() {
    case "$1" in
        error) printf '%s' "$RED"    ;;
        warn)  printf '%s' "$YELLOW" ;;
        info)  printf '%s' "$GREEN"  ;;
        debug) printf '%s' "$CYAN"   ;;
    esac
}

# Function: log
# Description: Logs a message at the given level if it falls within the current threshold.
#
# Arguments:
#   $1 - level (string, required): Log level for this message (error, warn, info, debug).
#   $@ - message (string, required): Message to log; all remaining arguments are joined with spaces.
#
# Globals:
#   LOG_LEVEL (read): Current logging threshold; messages above this priority are suppressed.
#   LOG_FILE (read): Optional file path; when set, messages are also appended to this file.
#   LOG_TIMESTAMP (read): When "true", a timestamp prefix is prepended to each message.
#   RESET (read): ANSI reset sequence applied after the colored message on TTY output.
#
# Returns:
#   0 - Message logged successfully, or suppressed by the current log level threshold.
#   1 - Invalid or missing log level, or empty message provided.
#
# Examples:
#   log "info" "Application started successfully"
#   log "error" "Failed to connect to database"
#   log "debug" "Resolved path:" "$resolved"
log() {
    if [ "$#" -lt 2 ]; then
        printf 'log: insufficient arguments. Usage: log LEVEL MESSAGE\n' >&2
        printf 'Available levels: error warn info debug\n' >&2
        return 1
    fi

    if [ -z "$1" ]; then
        printf 'Log level was left empty.\n'
        return 1
    fi

    local level="$1"
    local num_level
    num_level=$(_log_level_num "$level")
    local global_level
    global_level=$(_log_level_num "$LOG_LEVEL")

    shift
    local message="$*"

    if [ -z "$message" ]; then
        printf 'Log message is empty.\n'
        return 1
    fi

    if [ "$num_level" -eq 0 ]; then
        printf 'Invalid log level: %s\n' "$level" >&2
        return 1
    fi

    if [ "$num_level" -gt "$global_level" ]; then
        return 0  # Don't log if message level is below current threshold
    fi

    # Format timestamp
    local timestamp=""
    if [ "$LOG_TIMESTAMP" = "true" ]; then
        timestamp="$(date '+%Y-%m-%d %H:%M:%S') "
    fi

    # Format the log message
    local formatted_message="${timestamp}[$level] $message"

    # Output to console with colors (only if outputting to terminal)
    if [ -t 1 ]; then
        printf '%s%s%s\n' "$(_log_color "$level")" "$formatted_message" "$RESET"
    else
        printf '%s\n' "$formatted_message"
    fi

    # Output to log file if specified
    if [ -n "$LOG_FILE" ]; then
        if [ ! -f "$LOG_FILE" ]; then
            mkdir -p "$(dirname "$LOG_FILE")"
            touch "$LOG_FILE"
        fi
        printf '%s\n' "$formatted_message" >> "$LOG_FILE"
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
    log "$ERROR_LEVEL" "$@"
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
    log "$WARN_LEVEL" "$@"
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
    log "$INFO_LEVEL" "$@"
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
    log "$DEBUG_LEVEL" "$@"
}

# Function: log_output
# Description: Reads lines from stdin and logs each at debug level; only emitted when
#              LOG_LEVEL=debug. Use as a pipe target instead of redirecting to /dev/null
#              to suppress output in normal runs while preserving it for debugging.
#
# Arguments:
#   None — reads from stdin.
#
# Globals:
#   DEBUG_LEVEL (read): Constant string identifying the debug log level.
#
# Returns:
#   0 - All lines consumed; each non-empty line logged or suppressed by log level threshold.
#
# Examples:
#   apt-get install -y curl 2>&1 | log_output
#   some_command 2>&1 | log_output
log_output() {
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        log "$DEBUG_LEVEL" "$line"
    done
}
