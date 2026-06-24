#!/usr/bin/env bash

# Terminal output zones — splits the screen into a scrollable log zone (top)
# and a fixed status zone (bottom) for loading indicators. When zones are
# active, logging functions write to the log zone and spinners/progress bars
# render in the status zone, preventing output overlap.
#
# Zones are strictly opt-in: scripts that never call init_display get the
# existing behavior with zero changes. Non-TTY environments also fall back
# to the existing behavior automatically.

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------

_SHTUFF_ZONES_ACTIVE="false"
_SHTUFF_ZONE_STATUS_LINES=3
_SHTUFF_ZONE_LOG_TOP=1
_SHTUFF_ZONE_LOG_BOTTOM=0
_SHTUFF_ZONE_STATUS_TOP=0
_SHTUFF_ZONE_TERM_ROWS=0
_SHTUFF_ZONE_TERM_COLS=0
declare -gA _SHTUFF_ZONE_STATUS_SLOTS=()
declare -gA _SHTUFF_PROGRESS_SLOTS=()

_SHTUFF_ZONE_PREV_EXIT_TRAP=""
_SHTUFF_ZONE_PREV_INT_TRAP=""
_SHTUFF_ZONE_PREV_TERM_TRAP=""

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

# Function: _zones_active
# Description: Checks whether terminal output zones are currently active.
#
# Arguments:
#   None.
#
# Globals:
#   _SHTUFF_ZONES_ACTIVE (read): Current zone activation state.
#
# Returns:
#   0 - Zones are active.
#   1 - Zones are not active.
#
# Examples:
#   if _zones_active; then echo "zones on"; fi
_zones_active() {
    [[ "$_SHTUFF_ZONES_ACTIVE" == "true" ]]
}

# Function: _zones_calculate_boundaries
# Description: Reads terminal dimensions and calculates zone row boundaries.
#
# Arguments:
#   None.
#
# Globals:
#   _SHTUFF_ZONE_STATUS_LINES (read): Number of status zone rows.
#   _SHTUFF_ZONE_TERM_ROWS (write): Cached terminal row count.
#   _SHTUFF_ZONE_TERM_COLS (write): Cached terminal column count.
#   _SHTUFF_ZONE_LOG_TOP (write): First row of the log zone.
#   _SHTUFF_ZONE_LOG_BOTTOM (write): Last row of the log zone.
#   _SHTUFF_ZONE_STATUS_TOP (write): First row of the status zone.
#
# Returns:
#   0 - Boundaries calculated.
#
# Examples:
#   _zones_calculate_boundaries
_zones_calculate_boundaries() {
    _SHTUFF_ZONE_TERM_ROWS=$(tput lines)
    _SHTUFF_ZONE_TERM_COLS=$(tput cols)
    _SHTUFF_ZONE_LOG_TOP=1
    _SHTUFF_ZONE_LOG_BOTTOM=$(( _SHTUFF_ZONE_TERM_ROWS - _SHTUFF_ZONE_STATUS_LINES - 1 ))
    _SHTUFF_ZONE_STATUS_TOP=$(( _SHTUFF_ZONE_LOG_BOTTOM + 2 ))
}

# Function: _zones_draw_separator
# Description: Draws a dim horizontal line between the log and status zones.
#
# Arguments:
#   None.
#
# Globals:
#   _SHTUFF_ZONE_LOG_BOTTOM (read): Last row of the log zone.
#   _SHTUFF_ZONE_TERM_COLS (read): Terminal width.
#   DIM (read): ANSI dim formatting code.
#   RESET (read): ANSI reset sequence.
#
# Returns:
#   0 - Separator drawn.
#
# Examples:
#   _zones_draw_separator
_zones_draw_separator() {
    local sep_row=$(( _SHTUFF_ZONE_LOG_BOTTOM + 1 ))
    local line=""
    local i
    for (( i = 0; i < _SHTUFF_ZONE_TERM_COLS; i++ )); do
        line+="─"
    done
    printf '\033[%d;1H' "$sep_row"
    printf '%b%s%b' "${DIM:-\033[2m}" "$line" "${RESET:-\033[0m}"
}

# Function: _zones_clear_status
# Description: Clears all lines in the status zone.
#
# Arguments:
#   None.
#
# Globals:
#   _SHTUFF_ZONE_STATUS_TOP (read): First row of the status zone.
#   _SHTUFF_ZONE_STATUS_LINES (read): Number of status zone rows.
#
# Returns:
#   0 - Status zone cleared.
#
# Examples:
#   _zones_clear_status
_zones_clear_status() {
    local i
    for (( i = 0; i < _SHTUFF_ZONE_STATUS_LINES; i++ )); do
        printf '\033[%d;1H\033[K' "$(( _SHTUFF_ZONE_STATUS_TOP + i ))"
    done
}

# Function: _zones_init_slots
# Description: Initializes all status zone slots as free.
#
# Arguments:
#   None.
#
# Globals:
#   _SHTUFF_ZONE_STATUS_SLOTS (write): Slot availability map.
#   _SHTUFF_ZONE_STATUS_LINES (read): Number of slots.
#
# Returns:
#   0 - Slots initialized.
#
# Examples:
#   _zones_init_slots
_zones_init_slots() {
    _SHTUFF_ZONE_STATUS_SLOTS=()
    local i
    for (( i = 0; i < _SHTUFF_ZONE_STATUS_LINES; i++ )); do
        _SHTUFF_ZONE_STATUS_SLOTS[$i]="free"
    done
}

# Function: _write_to_log_zone
# Description: Writes a message to the log zone. The scroll region ensures
#              older messages scroll up as new ones arrive.
#
# Arguments:
#   $@ - message (string, required): The formatted message to write.
#
# Globals:
#   _SHTUFF_ZONE_LOG_BOTTOM (read): Last row of the log zone scroll region.
#
# Returns:
#   0 - Message written.
#
# Examples:
#   _write_to_log_zone "\033[32m[info] Hello\033[0m"
_write_to_log_zone() {
    printf '\033[s'
    printf '\033[%d;1H' "$_SHTUFF_ZONE_LOG_BOTTOM"
    printf '\n'
    printf '\033[%d;1H' "$_SHTUFF_ZONE_LOG_BOTTOM"
    printf '\033[K'
    printf '%b' "$*"
    printf '\033[u'
}

# Function: _write_to_status_zone
# Description: Writes or clears content on a specific status zone slot line.
#
# Arguments:
#   --slot N (integer, required): Status line index (0-based).
#   --message MSG (string, optional): Content to render on that line.
#   --clear (flag, optional): Clear the slot instead of writing.
#
# Globals:
#   _SHTUFF_ZONE_STATUS_TOP (read): First row of the status zone.
#   _SHTUFF_ZONE_STATUS_LINES (read): Number of available slots.
#
# Returns:
#   0 - Content written or cleared.
#   1 - Slot index out of bounds.
#
# Examples:
#   _write_to_status_zone --slot 0 --message "⠹ Downloading..."
#   _write_to_status_zone --slot 1 --clear
_write_to_status_zone() {
    local slot=-1
    local message=""
    local clear=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --slot)   slot="$2"; shift 2 ;;
            --message) message="$2"; shift 2 ;;
            --clear)  clear=true; shift ;;
            *)        shift ;;
        esac
    done

    if (( slot < 0 || slot >= _SHTUFF_ZONE_STATUS_LINES )); then
        return 1
    fi

    local row=$(( _SHTUFF_ZONE_STATUS_TOP + slot ))
    printf '\033[s'
    printf '\033[%d;1H' "$row"
    printf '\033[K'
    if [[ "$clear" != true && -n "$message" ]]; then
        printf '%b' "$message"
    fi
    printf '\033[u'
}

# Function: _acquire_status_slot
# Description: Finds the first free status slot, marks it busy, and echoes its index.
#
# Arguments:
#   None.
#
# Globals:
#   _SHTUFF_ZONE_STATUS_SLOTS (read/write): Slot availability map.
#   _SHTUFF_ZONE_STATUS_LINES (read): Number of available slots.
#
# Returns:
#   0 - Slot acquired; index echoed to stdout.
#   1 - No free slots available.
#
# Examples:
#   local slot; slot=$(_acquire_status_slot) || return 1
_acquire_status_slot() {
    local i
    for (( i = 0; i < _SHTUFF_ZONE_STATUS_LINES; i++ )); do
        if [[ "${_SHTUFF_ZONE_STATUS_SLOTS[$i]}" == "free" ]]; then
            _SHTUFF_ZONE_STATUS_SLOTS[$i]="busy"
            echo "$i"
            return 0
        fi
    done
    return 1
}

# Function: _release_status_slot
# Description: Clears a status zone slot and marks it free.
#
# Arguments:
#   $1 - slot (integer, required): Slot index to release.
#
# Globals:
#   _SHTUFF_ZONE_STATUS_SLOTS (write): Slot availability map.
#
# Returns:
#   0 - Slot released.
#
# Examples:
#   _release_status_slot 0
_release_status_slot() {
    local slot="$1"
    _write_to_status_zone --slot "$slot" --clear
    _SHTUFF_ZONE_STATUS_SLOTS[$slot]="free"
}

# Function: _shtuff_zones_cleanup_on_exit
# Description: EXIT trap handler that restores terminal state and chains to
#              any previously registered EXIT trap.
#
# Arguments:
#   None.
#
# Globals:
#   _SHTUFF_ZONE_PREV_EXIT_TRAP (read): Previous EXIT trap handler.
#
# Returns:
#   0 - Cleanup completed.
#
# Examples:
#   trap '_shtuff_zones_cleanup_on_exit' EXIT
_shtuff_zones_cleanup_on_exit() {
    cleanup_display
    if [[ -n "$_SHTUFF_ZONE_PREV_EXIT_TRAP" ]]; then
        eval "$_SHTUFF_ZONE_PREV_EXIT_TRAP"
    fi
}

# Function: _shtuff_zones_cleanup_on_signal
# Description: INT/TERM trap handler that restores terminal state.
#
# Arguments:
#   None.
#
# Globals:
#   None.
#
# Returns:
#   0 - Cleanup completed.
#
# Examples:
#   trap '_shtuff_zones_cleanup_on_signal; exit 130' INT
_shtuff_zones_cleanup_on_signal() {
    cleanup_display
}

# Function: _shtuff_zones_handle_winch
# Description: SIGWINCH handler that recalculates zone boundaries and redraws
#              the separator after a terminal resize.
#
# Arguments:
#   None.
#
# Globals:
#   _SHTUFF_ZONE_LOG_TOP (read): First row of the log zone.
#   _SHTUFF_ZONE_LOG_BOTTOM (read/write): Last row of the log zone.
#
# Returns:
#   0 - Zones recalculated.
#
# Examples:
#   trap '_shtuff_zones_handle_winch' WINCH
_shtuff_zones_handle_winch() {
    if ! _zones_active; then
        return 0
    fi
    _zones_calculate_boundaries
    printf '\033[%d;%dr' "$_SHTUFF_ZONE_LOG_TOP" "$_SHTUFF_ZONE_LOG_BOTTOM"
    _zones_draw_separator
    _zones_clear_status
}

# ---------------------------------------------------------------------------
# Public functions
# ---------------------------------------------------------------------------

# Function: init_display
# Description: Initializes terminal output zones, splitting the screen into a
#              scrollable log zone (top) and a fixed status zone (bottom).
#              When zones are active, logging functions write to the log zone
#              and loading indicators render in the status zone, preventing
#              output overlap. Safe to call multiple times (idempotent).
#              Returns 1 as a no-op when stdout is not a TTY, the terminal is
#              too small, or SHTUFF_NO_DISPLAY=true is set.
#
# Arguments:
#   --status-lines N (integer, optional, default: 3): Number of lines reserved
#                    for the status zone at the bottom of the terminal.
#
# Globals:
#   _SHTUFF_ZONES_ACTIVE (write): Set to "true" on success.
#   _SHTUFF_ZONE_STATUS_LINES (write): Number of status zone rows.
#   _SHTUFF_ZONE_LOG_TOP (write): First row of the log zone.
#   _SHTUFF_ZONE_LOG_BOTTOM (write): Last row of the log zone.
#   _SHTUFF_ZONE_STATUS_TOP (write): First row of the status zone.
#   _SHTUFF_ZONE_TERM_ROWS (write): Cached terminal row count.
#   _SHTUFF_ZONE_TERM_COLS (write): Cached terminal column count.
#   _SHTUFF_ZONE_STATUS_SLOTS (write): Slot availability map.
#   SHTUFF_NO_DISPLAY (read): When "true", zones are not initialized.
#
# Returns:
#   0 - Zones initialized successfully.
#   1 - Not a TTY, terminal too small, display suppressed, or already active.
#
# Examples:
#   init_display
#   init_display --status-lines 4
init_display() {
    if _zones_active; then
        return 0
    fi

    if [[ "${SHTUFF_NO_DISPLAY:-}" == "true" ]]; then
        return 1
    fi

    if ! [[ -t 1 ]]; then
        return 1
    fi

    local status_lines=3

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --status-lines)
                status_lines="$2"
                shift 2
                ;;
            *)
                error "init_display: unknown option: $1"
                return 1
                ;;
        esac
    done

    _SHTUFF_ZONE_STATUS_LINES="$status_lines"

    _zones_calculate_boundaries

    if (( _SHTUFF_ZONE_TERM_ROWS < _SHTUFF_ZONE_STATUS_LINES + 5 )); then
        warn "init_display: terminal too small for zones (${_SHTUFF_ZONE_TERM_ROWS} rows, need $(( _SHTUFF_ZONE_STATUS_LINES + 5 )))"
        return 1
    fi

    # Save existing trap handlers for chaining
    _SHTUFF_ZONE_PREV_EXIT_TRAP=$(trap -p EXIT | sed "s/^trap -- '//;s/' EXIT$//" 2>/dev/null || true)
    _SHTUFF_ZONE_PREV_INT_TRAP=$(trap -p INT | sed "s/^trap -- '//;s/' INT$//" 2>/dev/null || true)
    _SHTUFF_ZONE_PREV_TERM_TRAP=$(trap -p TERM | sed "s/^trap -- '//;s/' TERM$//" 2>/dev/null || true)

    # Clear screen and set up zones
    printf '\033[2J'
    printf '\033[%d;%dr' "$_SHTUFF_ZONE_LOG_TOP" "$_SHTUFF_ZONE_LOG_BOTTOM"
    _zones_draw_separator
    _zones_clear_status
    _zones_init_slots

    # Position cursor at top of log zone
    printf '\033[%d;1H' "$_SHTUFF_ZONE_LOG_TOP"

    # Install traps
    trap '_shtuff_zones_cleanup_on_exit' EXIT
    trap '_shtuff_zones_cleanup_on_signal; exit 130' INT
    trap '_shtuff_zones_cleanup_on_signal; exit 143' TERM
    trap '_shtuff_zones_handle_winch' WINCH

    _SHTUFF_ZONES_ACTIVE="true"
    return 0
}

# Function: cleanup_display
# Description: Restores the terminal to normal state by resetting the scroll
#              region, showing the cursor, and clearing zone state. Safe to
#              call multiple times (idempotent). Called automatically via the
#              EXIT trap installed by init_display.
#
# Arguments:
#   None.
#
# Globals:
#   _SHTUFF_ZONES_ACTIVE (write): Set to "false".
#   _SHTUFF_ZONE_STATUS_SLOTS (write): Cleared.
#   _SHTUFF_PROGRESS_SLOTS (write): Cleared.
#   _SHTUFF_ZONE_PREV_EXIT_TRAP (read): Restored to EXIT trap.
#   _SHTUFF_ZONE_PREV_INT_TRAP (read): Restored to INT trap.
#   _SHTUFF_ZONE_PREV_TERM_TRAP (read): Restored to TERM trap.
#
# Returns:
#   0 - Terminal state restored.
#
# Examples:
#   cleanup_display
cleanup_display() {
    if ! _zones_active; then
        return 0
    fi

    _SHTUFF_ZONES_ACTIVE="false"

    # Reset scroll region to full terminal
    printf '\033[r'

    # Show cursor
    tput cnorm 2>/dev/null || true

    # Move cursor below the status zone
    printf '\033[%d;1H' "$_SHTUFF_ZONE_TERM_ROWS"
    printf '\n'

    # Clear state
    _SHTUFF_ZONE_STATUS_SLOTS=()
    _SHTUFF_PROGRESS_SLOTS=()

    # Restore previous traps
    if [[ -n "$_SHTUFF_ZONE_PREV_EXIT_TRAP" ]]; then
        trap "$_SHTUFF_ZONE_PREV_EXIT_TRAP" EXIT
    else
        trap - EXIT
    fi
    if [[ -n "$_SHTUFF_ZONE_PREV_INT_TRAP" ]]; then
        trap "$_SHTUFF_ZONE_PREV_INT_TRAP" INT
    else
        trap - INT
    fi
    if [[ -n "$_SHTUFF_ZONE_PREV_TERM_TRAP" ]]; then
        trap "$_SHTUFF_ZONE_PREV_TERM_TRAP" TERM
    else
        trap - TERM
    fi
    trap - WINCH

    _SHTUFF_ZONE_PREV_EXIT_TRAP=""
    _SHTUFF_ZONE_PREV_INT_TRAP=""
    _SHTUFF_ZONE_PREV_TERM_TRAP=""
}

# Function: display_pipe
# Description: Reads lines from stdin and routes each through the log zone when
#              zones are active, or passes through to stderr when zones are off.
#              Use as a pipe target to capture child process output (e.g. from
#              container exec) and display it within the zone layout.
#
# Arguments:
#   None — reads from stdin.
#
# Globals:
#   _SHTUFF_ZONES_ACTIVE (read): Whether zones are currently active.
#
# Returns:
#   0 - All lines consumed.
#
# Examples:
#   container exec --name ct -- bash /opt/setup.sh > >(display_pipe) 2>&1 &
#   monitor $! --message "Running setup" || exit 1
display_pipe() {
    local line
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if _zones_active; then
            _write_to_log_zone "$line"
        else
            echo "$line" >&2
        fi
    done
}
