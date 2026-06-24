#!/usr/bin/env bash

# Terminal Output Zones — Test Script
#
# Exercises every aspect of the init_display / cleanup_display feature so you
# can visually verify that log messages scroll in the top zone while spinners
# and progress bars animate in the fixed bottom zone without overlapping.
#
# Usage:
#   bash examples/test-terminal-zones.sh
#
# Requirements:
#   - A terminal with at least 12 rows (the script needs room for both zones)
#   - No root or network access required — uses sleep as fake background work

SCRIPT_DIR=$(unset CDPATH && cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${SCRIPT_DIR}/shtuff.sh"

# ---------------------------------------------------------------------------
# Initialize display zones
# ---------------------------------------------------------------------------

init_display --status-lines 3

info "=== Terminal Output Zones — Test Suite ==="
sleep 1

# ---------------------------------------------------------------------------
# Test 1: Logging in the log zone
# ---------------------------------------------------------------------------

info "--- Test 1: Logging levels ---"
sleep 0.5
info  "This is an info message"
sleep 0.3
warn  "This is a warning message"
sleep 0.3
error "This is an error message (non-fatal, just for display)"
sleep 0.3
debug "This debug message only appears when LOG_LEVEL=debug"
sleep 1

# ---------------------------------------------------------------------------
# Test 2: Spinner with interleaved log messages
# ---------------------------------------------------------------------------

info "--- Test 2: Spinner + interleaved logging ---"
info "A spinner should appear in the status zone while log messages scroll above."
sleep 0.5

sleep 3 &
bg_pid=$!
(
    sleep 0.5; info  "Log message during spinner (1 of 3)"
    sleep 0.7; warn  "Warning during spinner (2 of 3)"
    sleep 0.5; info  "Log message during spinner (3 of 3)"
) &
log_pid=$!
monitor $bg_pid \
    --style "$SPINNER_LOADING_STYLE" \
    --message "Working on something" \
    --success_msg "Spinner test passed" \
    --error_msg "Spinner test failed" || exit 1
wait $log_pid 2>/dev/null
sleep 1

# ---------------------------------------------------------------------------
# Test 3: Sequential spinners with different styles
# ---------------------------------------------------------------------------

info "--- Test 3: Sequential spinners (different styles) ---"
sleep 0.5

sleep 1.5 &
monitor $! \
    --style "$SPINNER_LOADING_STYLE" \
    --message "Spinner style" \
    --success_msg "Spinner done" || exit 1

sleep 1.5 &
monitor $! \
    --style "$DOTS_LOADING_STYLE" \
    --message "Dots style" \
    --success_msg "Dots done" || exit 1

sleep 1.5 &
monitor $! \
    --style "$BARS_LOADING_STYLE" \
    --message "Bars style" \
    --success_msg "Bars done" || exit 1

sleep 1.5 &
monitor $! \
    --style "$ARROWS_LOADING_STYLE" \
    --message "Arrows style" \
    --success_msg "Arrows done" || exit 1

sleep 1.5 &
monitor $! \
    --style "$CLOCK_LOADING_STYLE" \
    --message "Clock style" \
    --success_msg "Clock done" || exit 1

sleep 1

# ---------------------------------------------------------------------------
# Test 4: Single progress bar
# ---------------------------------------------------------------------------

info "--- Test 4: Single progress bar ---"
info "A progress bar should appear in the status zone and update in place."
sleep 0.5

local_total=10
for (( i = 0; i <= local_total; i++ )); do
    progress --current "$i" --total "$local_total" --message "Processing items"
    sleep 0.3
done
sleep 1

# ---------------------------------------------------------------------------
# Test 5: Multiple simultaneous progress bars
# ---------------------------------------------------------------------------

info "--- Test 5: Multiple simultaneous progress bars (--id) ---"
info "Two progress bars should appear in the status zone at the same time."
sleep 0.5

images_total=8
configs_total=5
images_done=0
configs_done=0

progress --id "images" --current 0 --total "$images_total" --message "Images "
progress --id "configs" --current 0 --total "$configs_total" --message "Configs"

while (( images_done < images_total || configs_done < configs_total )); do
    if (( images_done < images_total )); then
        (( images_done++ ))
        progress --id "images" --current "$images_done" --total "$images_total" --message "Images "
    fi
    sleep 0.2
    if (( configs_done < configs_total )); then
        (( configs_done++ ))
        progress --id "configs" --current "$configs_done" --total "$configs_total" --message "Configs"
    fi
    sleep 0.2
done
sleep 1

# ---------------------------------------------------------------------------
# Test 6: Progress bar + spinner together
# ---------------------------------------------------------------------------

info "--- Test 6: Progress bar + spinner running together ---"
info "A progress bar and a spinner should coexist in the status zone."
sleep 0.5

sleep 4 &
bg_pid=$!

steps=8
for (( i = 0; i <= steps; i++ )); do
    progress --id "combined" --current "$i" --total "$steps" --message "Downloading"
    if (( i < steps )); then
        sleep 0.4
    fi
done

monitor $bg_pid \
    --style "$SPINNER_LOADING_STYLE" \
    --message "Finalizing" \
    --success_msg "Combined test passed" || exit 1
sleep 1

# ---------------------------------------------------------------------------
# Test 7: display_pipe
# ---------------------------------------------------------------------------

info "--- Test 7: display_pipe ---"
info "Output from a subshell piped through display_pipe should appear in the log zone."
sleep 0.5

(
    echo "Piped line 1: hello from subshell"
    sleep 0.3
    echo "Piped line 2: still going"
    sleep 0.3
    echo "Piped line 3: done"
) | display_pipe
sleep 1

# ---------------------------------------------------------------------------
# Done — cleanup happens automatically via EXIT trap
# ---------------------------------------------------------------------------

info "=== All tests completed ==="
info "The terminal will be restored to normal in 2 seconds..."
sleep 2
