# Logging

info, warn, error, debug, verbose and log_output. Messages go to stderr. `LOG_LEVEL`, `LOG_FILE` and `LOG_TIMESTAMP` control output.

> Generated from the header comments in `src/` by `docs/generate-reference.sh`. Edit the headers, not this file.

## `error`

_Source: `src/core/logging/log_bash.sh`_

```text
Function: error
Description: Logs a message at error level; always emitted regardless of LOG_LEVEL threshold.

Arguments:
  $@ - message (string, required): Message to log; all arguments are joined with spaces.

Globals:
  ERROR_LEVEL (read): Constant string identifying the error log level.

Returns:
  0 - Message logged successfully.
  1 - Empty message provided.

Examples:
  error "Database connection failed"
  error "Required file not found:" "$path"
```

## `warn`

_Source: `src/core/logging/log_bash.sh`_

```text
Function: warn
Description: Logs a message at warn level; suppressed when LOG_LEVEL is set to error.

Arguments:
  $@ - message (string, required): Message to log; all arguments are joined with spaces.

Globals:
  WARN_LEVEL (read): Constant string identifying the warn log level.

Returns:
  0 - Message logged successfully, or suppressed by log level threshold.
  1 - Empty message provided.

Examples:
  warn "Configuration file not found, using defaults"
  warn "Deprecated flag used:" "$flag"
```

## `info`

_Source: `src/core/logging/log_bash.sh`_

```text
Function: info
Description: Logs a message at info level; suppressed when LOG_LEVEL is set to error or warn.

Arguments:
  $@ - message (string, required): Message to log; all arguments are joined with spaces.

Globals:
  INFO_LEVEL (read): Constant string identifying the info log level.

Returns:
  0 - Message logged successfully, or suppressed by log level threshold.
  1 - Empty message provided.

Examples:
  info "Application started successfully"
  info "Listening on port" "$port"
```

## `debug`

_Source: `src/core/logging/log_bash.sh`_

```text
Function: debug
Description: Logs a message at debug level; only emitted when LOG_LEVEL=debug.

Arguments:
  $@ - message (string, required): Message to log; all arguments are joined with spaces.

Globals:
  DEBUG_LEVEL (read): Constant string identifying the debug log level.

Returns:
  0 - Message logged successfully, or suppressed by log level threshold.
  1 - Empty message provided.

Examples:
  debug "Processing user ID: 12345"
  debug "Resolved path:" "$path"
```

## `verbose`

_Source: `src/core/logging/log_bash.sh`_

```text
Function: verbose
Description: Logs a message at verbose level. Always written to VERBOSE_FILE regardless of
             LOG_LEVEL. Also printed to the console when LOG_LEVEL=verbose.

Arguments:
  $@ - message (string, required): Message to log; all arguments are joined with spaces.

Globals:
  VERBOSE_LEVEL (read): Constant string identifying the verbose log level.
  VERBOSE_FILE (write): Path to the verbose temp file; message is appended here.
  VERBOSE_LOGS (read): Public alias for VERBOSE_FILE.

Returns:
  0 - Message written to VERBOSE_FILE (and optionally to console).
  1 - Empty message provided.

Examples:
  verbose "Detailed diagnostic info"
  verbose "Raw output line:" "$line"
```

## `log_output`

_Source: `src/core/logging/log_bash.sh`_

```text
Function: log_output
Description: Reads lines from stdin and logs each at verbose level. Each line is always
             appended to VERBOSE_FILE; lines are also mirrored to the console when
             LOG_LEVEL=verbose. Use as a pipe target to capture raw command output instead
             of discarding it with /dev/null.

Arguments:
  None — reads from stdin.

Globals:
  VERBOSE_LEVEL (read): Constant string identifying the verbose log level.
  VERBOSE_FILE (write): Path to the verbose temp file; each line is appended here.
  VERBOSE_LOGS (read): Public alias for VERBOSE_FILE.

Returns:
  0 - All lines consumed; each non-empty line written to VERBOSE_FILE.

Examples:
  apt-get install -y curl > >(log_output) 2>&1
  some_command > >(log_output) 2>&1
```
