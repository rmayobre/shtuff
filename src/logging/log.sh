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
#   LOG_LEVEL     - Set logging threshold (ERROR, WARN, INFO, DEBUG)
#   LOG_FILE      - Enable file logging by setting file path
#   LOG_TIMESTAMP - Set to "false" to disable timestamps

# Logging configuration
LOG_LEVEL=${LOG_LEVEL:-"INFO"}  # Default log level
LOG_FILE=${LOG_FILE:-""}        # Optional log file path
LOG_TIMESTAMP=${LOG_TIMESTAMP:-true}  # Include timestamps

# Log level hierarchy (lower number = higher priority)
declare -A LOG_LEVELS=(
    ["ERROR"]=1
    ["WARN"]=2
    ["INFO"]=3
    ["DEBUG"]=4
)

# Color codes for console output
declare -A LOG_COLORS=(
    ["ERROR"]="$RED"
    ["WARN"]="$YELLOW"
    ["INFO"]="$GREEN"
    ["DEBUG"]="$CYAN"
    ["RESET"]="$RESET"
)

# Main logging function
#
# Logs a message if the provided level is within the allowed ranged set by the
# LOG_LEVEL environemnt variable.
#
# Log Format: "<TIMESTAMP>[<LOG_LEVEL>] <MESSAGE>
#
# Arguments:
#   $1 - Log level (ERROR, WARN, INFO, DEBUG)
#   $@ - Message to log (all remaining arguments joined with spaces)
#
# Environment Variables:
#   LOG_LEVEL - Current log level threshold (default: INFO)
#   LOG_FILE - Optional file path for logging output
#   LOG_TIMESTAMP - Whether to include timestamps (default: true)
#
# Returns:
#   0 - Success or message filtered out
#   1 - Invalid log level provided
#
# Example:
#   log "INFO" "Application started successfully"
#   log "INFO" "Application" "started" "successfully"
#   log "ERROR" "Failed to connect to database"
#
log() {
    # Check if minimum arguments provided
    if [[ $# -lt 2 ]]; then
        echo "log: insufficient arguments. Usage: log LEVEL MESSAGE" >&2
        echo "Available levels: ${!LOG_LEVELS[*]}" >&2
        return 1
    fi

    if [[ -z "$1" ]]; then
        echo "Log level was left empty."
        return 1
    fi

    local level="$1"
    local num_level=${LOG_LEVELS[$level]}
    local color_level=${LOG_COLORS[$level]}
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
        return 0  # Don't log if message level is below current threshold
    fi

    # Format timestamp
    local timestamp=""
    if [[ "$LOG_TIMESTAMP" == "true" ]]; then
        timestamp="$(date '+%Y-%m-%d %H:%M:%S') "
    fi

    # Format the log message
    local formatted_message="${timestamp}[$level] $message"

    # Output to console with colors (only if outputting to terminal)
    if [[ -t 1 ]]; then
        echo -e "${LOG_COLORS[$level]}${formatted_message}${LOG_COLORS[RESET]}"
    else
        echo "$formatted_message"
    fi

    # Output to log file if specified
    if [[ -n "$LOG_FILE" ]]; then
        # Create log file and directory if they don't exist
        if [[ ! -f "$LOG_FILE" ]]; then
            mkdir -p "$(dirname "$LOG_FILE")"
            touch "$LOG_FILE"
        fi
        echo "$formatted_message" >> "$LOG_FILE"
    fi
}

#
# Error level logging function
#
# Logs an error level message - this message is never filtered.
#
# Log Format: "<TIMESTAMP>[<LOG_LEVEL>] <MESSAGE>"
#
# Arguments:
#   $@ - Message to log (all remaining arguments joined with spaces)
#
# Environment Variables:
#   LOG_LEVEL - Current log level threshold (default: INFO)
#   LOG_FILE - Optional file path for logging output
#   LOG_TIMESTAMP - Whether to include timestamps (default: true)
#
# Returns:
#   0 - Success or message filtered out
#   1 - Invalid log level provided
#
# Example:
#   error "Database connection failed"
error() {
    log "ERROR" "$@"
}

#
# Warning level logging function
#
# Logs an warning level message, if the LOG_LEVEL environment variable isn't
# set to filter out the message.
#
# Log Format: "<TIMESTAMP>[<LOG_LEVEL>] <MESSAGE>"
#
# Arguments:
#   $@ - Message to log (all remaining arguments joined with spaces)
#
# Environment Variables:
#   LOG_LEVEL - Current log level threshold (default: INFO)
#   LOG_FILE - Optional file path for logging output
#   LOG_TIMESTAMP - Whether to include timestamps (default: true)
#
# Returns:
#   0 - Success or message filtered out
#   1 - Invalid log level provided
#
# Example:
#   warn "Configuration file not found, using defaults"
warn() {
    log "WARN" "$@"
}

#
# Information level logging function
#
# Logs an information level message, if the LOG_LEVEL environment variable isn't
# set to filter out the message.
#
# Log Format: "<TIMESTAMP>[<LOG_LEVEL>] <MESSAGE>"
#
# Arguments:
#   $@ - Message to log (all remaining arguments joined with spaces)
#
# Environment Variables:
#   LOG_LEVEL - Current log level threshold (default: INFO)
#   LOG_FILE - Optional file path for logging output
#   LOG_TIMESTAMP - Whether to include timestamps (default: true)
#
# Returns:
#   0 - Success or message filtered out
#   1 - Invalid log level provided
#
# Example:
#   info "Application started successfully"
info() {
    log "INFO" "$@"
}

#
# Debug level logging function
#
# Logs an debug level message, if the LOG_LEVEL environment variable isn't
# set to filter out the message.
#
# Log Format: "<TIMESTAMP>[<LOG_LEVEL>] <MESSAGE>"
#
# Arguments:
#   $1 - Log level (ERROR, WARN, INFO, DEBUG)
#   $@ - Message to log (all remaining arguments joined with spaces)
#
# Environment Variables:
#   LOG_LEVEL - Current log level threshold (default: INFO)
#   LOG_FILE - Optional file path for logging output
#   LOG_TIMESTAMP - Whether to include timestamps (default: true)
#
# Returns:
#   0 - Success or message filtered out
#   1 - Invalid log level provided
#
# Example:
#   debug "Processing user ID: 12345"
debug() {
    log "DEBUG" "$@"
}
