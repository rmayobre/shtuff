# A standardized logging for bash scripts:
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
VERBOSE_FILE="${VERBOSE_FILE:-/tmp/script_$$.log}"
VERBOSE_LOGS="$VERBOSE_FILE"

# Log level hierarchy (lower number = higher priority)
readonly -A LOG_LEVELS=(
    ["$ERROR_LEVEL"]=1
    ["$WARN_LEVEL"]=2
    ["$INFO_LEVEL"]=3
    ["$DEBUG_LEVEL"]=4
    ["$VERBOSE_LEVEL"]=5
)

# Color codes for console output
readonly -A LOG_COLORS=(
    ["$ERROR_LEVEL"]="$RED"
    ["$WARN_LEVEL"]="$YELLOW"
    ["$INFO_LEVEL"]="$GREEN"
    ["$DEBUG_LEVEL"]="$CYAN"
    ["$VERBOSE_LEVEL"]="$MAGENTA"
)

# Function: _log
# Description: Logs a message at the given level if it falls within the current threshold.
#              Messages at verbose level are always written to VERBOSE_FILE; they are also
#              printed to the console only when LOG_LEVEL=verbose.
#
# Arguments:
#   $1 - level (string, required): Log level for this message (error, warn, info, debug, verbose).
#   $@ - message (string, required): Message to log; all remaining arguments are joined with spaces.
#
# Globals:
#   LOG_LEVELS (read): Associative array mapping level names to numeric priorities.
#   LOG_LEVEL (read): Current logging threshold; messages above this priority are suppressed.
#   LOG_COLORS (read): Associative array mapping level names to ANSI color codes.
#   LOG_FILE (read): Optional file path; when set, non-verbose messages are written only to this file.
#   LOG_TIMESTAMP (read): When "true", a timestamp prefix is prepended to each message.
#   RESET (read): ANSI reset sequence applied after the colored message on TTY output.
#   VERBOSE_FILE (read): Path to the verbose temp file; verbose messages are always appended here.
#   VERBOSE_LOGS (read): Public alias for VERBOSE_FILE.
#
# Returns:
#   0 - Message logged successfully, or suppressed by the current log level threshold.
#   1 - Invalid or missing log level, or empty message provided.
#
# Examples:
#   log "info" "Application started successfully"
#   log "error" "Failed to connect to database"
#   log "debug" "Resolved path:" "$resolved"
#   log "verbose" "Raw command output line"
_log() {
    # Check if minimum arguments provided
    if [[ $# -lt 2 ]]; then
        echo "_log: insufficient arguments. Usage: _log LEVEL MESSAGE" >&2
        echo "Available levels: ${!LOG_LEVELS[*]}" >&2
        return 1
    fi

    if [[ -z "$1" ]]; then
        echo "Log level was left empty."
        return 1
    fi

    local level="$1"
    local num_level=${LOG_LEVELS[$level]}
    local global_level=${LOG_LEVELS[$LOG_LEVEL]}

    # Shift to the next parameter position to collect all arguments into a
    # single message. This allows for the caller to provide an array or
    # multiple messages that should be concatenated into a single message.
    shift
    local message="$*"

    if [[ -z "$message" ]]; then
        echo "Log message is empty."
        return 1
    fi

    if [[ -z "$num_level" ]]; then
        echo "Invalid log level: $level" >&2
        return 1
    fi

    if [[ $num_level -gt $global_level ]]; then
        # Verbose messages bypass the threshold check — always write to file
        if [[ "$level" != "$VERBOSE_LEVEL" ]]; then
            return 0
        fi
    fi

    # Format timestamp
    local timestamp=""
    if [[ "$LOG_TIMESTAMP" == "true" ]]; then
        timestamp="$(date '+%Y-%m-%d %H:%M:%S') "
    fi

    # Format the log message
    local formatted_message="${timestamp}[$level] $message"

    # Verbose messages always go to VERBOSE_FILE; only mirror to console when LOG_LEVEL=verbose
    if [[ "$level" == "$VERBOSE_LEVEL" ]]; then
        mkdir -p "$(dirname "$VERBOSE_FILE")" 2>/dev/null
        echo "$formatted_message" >> "$VERBOSE_FILE"
        if [[ "$LOG_LEVEL" == "$VERBOSE_LEVEL" ]]; then
            if [[ -t 2 ]]; then
                echo -e "${LOG_COLORS[$level]}${formatted_message}$RESET" >&2
            else
                echo "$formatted_message" >&2
            fi
        fi
    # Output to log file if specified; suppress terminal output when LOG_FILE is set
    elif [[ -n "$LOG_FILE" ]]; then
        # Create log file and directory if they don't exist
        if [[ ! -f "$LOG_FILE" ]]; then
            mkdir -p "$(dirname "$LOG_FILE")"
            touch "$LOG_FILE"
        fi
        echo "$formatted_message" >> "$LOG_FILE"
    else
        # Output to stderr so log messages never pollute stdout return values
        if [[ -t 2 ]]; then
            echo -e "${LOG_COLORS[$level]}${formatted_message}$RESET" >&2
        else
            echo "$formatted_message" >&2
        fi
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
    _log $ERROR_LEVEL "$@"
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
    _log $WARN_LEVEL "$@"
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
    _log $INFO_LEVEL "$@"
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
    _log $DEBUG_LEVEL "$@"
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
#   apt-get install -y curl > >(log_output) 2>&1
#   some_command > >(log_output) 2>&1
log_output() {
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        _log "$VERBOSE_LEVEL" "$line"
    done
}
