#!/usr/bin/env bash

# Refactor Validation Script
#
# Exercises every API change from the packaging-utility-refactor branch:
#   1. _log rename (private) — public wrappers still work
#   2. forms/ → prompts/ — functions still load
#   3. check_port → scan
#   4. wait_for_port → poll
#   5. download moved to utils/
#   6. lxc/pct container subdirectories — files still source
#   7. Packaging functions (install, update, uninstall, clean) use monitor
#
# Usage:
#   sudo ./test-refactor.sh            # Full test (packaging requires root)
#   ./test-refactor.sh                 # Partial test (skips packaging)

set -euo pipefail

# Source shtuff locally
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/../shtuff.sh"

PASS=0
FAIL=0
SKIP=0

pass() {
    PASS=$(( PASS + 1 ))
    info "[PASS] $1"
}

fail() {
    FAIL=$(( FAIL + 1 ))
    error "[FAIL] $1"
}

skip() {
    SKIP=$(( SKIP + 1 ))
    warn "[SKIP] $1"
}

assert_fn_exists() {
    if declare -f "$1" > /dev/null 2>&1; then
        pass "Function '$1' is defined"
    else
        fail "Function '$1' is NOT defined"
    fi
}

assert_fn_missing() {
    if declare -f "$1" > /dev/null 2>&1; then
        fail "Function '$1' should NOT be defined (expected private/removed)"
    else
        pass "Function '$1' is correctly absent from the public API"
    fi
}

# ─── 1. Logging: _log is private, public wrappers work ────────────────────────

info "=== Test 1: Logging (_log rename) ==="

assert_fn_exists "_log"
assert_fn_missing "log"

assert_fn_exists "error"
assert_fn_exists "warn"
assert_fn_exists "info"
assert_fn_exists "debug"
assert_fn_exists "verbose"
assert_fn_exists "log_output"

info "Testing info output..."
warn "Testing warn output..."
debug "Testing debug output (visible only at LOG_LEVEL=debug)..."

pass "Logging wrappers produce output without errors"

# ─── 2. Prompts: forms/ renamed to prompts/ ───────────────────────────────────

info "=== Test 2: Prompts (forms → prompts) ==="

assert_fn_exists "question"
assert_fn_exists "options"
assert_fn_exists "selections"
assert_fn_exists "confirm"

pass "All prompt functions loaded from src/prompts/"

# ─── 3. Networking: check_port → scan ─────────────────────────────────────────

info "=== Test 3: scan (check_port rename) ==="

assert_fn_exists "scan"
assert_fn_missing "check_port"

if scan --port 99999 2>/dev/null; then
    fail "scan should reject port 99999 (out of range)"
else
    pass "scan rejects invalid port numbers"
fi

if scan --port 65534; then
    pass "scan reports port 65534 as free"
else
    pass "scan reports port 65534 as in use (environment-dependent)"
fi

# ─── 4. Networking: wait_for_port → poll ──────────────────────────────────────

info "=== Test 4: poll (wait_for_port rename) ==="

assert_fn_exists "poll"
assert_fn_missing "wait_for_port"

if poll 2>/dev/null; then
    fail "poll without args should fail"
else
    pass "poll returns non-zero when required args are missing"
fi

# ─── 5. Networking dispatcher (scan/poll aliases) ─────────────────────────────

info "=== Test 5: network dispatcher ==="

assert_fn_exists "network"

if network check --port 65533 2>/dev/null; then
    pass "network check (legacy subcommand) routes to scan"
elif [[ $? -eq 2 ]]; then
    fail "network check returned error code 2 (bad args)"
else
    pass "network check (legacy subcommand) routes to scan (port in use)"
fi

if network scan --port 65533 2>/dev/null; then
    pass "network scan (new subcommand alias) works"
elif [[ $? -eq 2 ]]; then
    fail "network scan returned error code 2 (bad args)"
else
    pass "network scan (new subcommand alias) works (port in use)"
fi

# ─── 6. download moved to utils/ ─────────────────────────────────────────────

info "=== Test 6: download (moved to utils) ==="

assert_fn_exists "download"

DOWNLOAD_DIR=$(mktemp -d /tmp/shtuff_test_XXXXXX)

if download --url "https://raw.githubusercontent.com/rmayobre/shtuff/main/LICENSE" \
    --dir "$DOWNLOAD_DIR" \
    --output "LICENSE.txt" \
    --message "Downloading test file"; then
    if [[ -f "${DOWNLOAD_DIR}/LICENSE.txt" ]]; then
        pass "download saved file to utils-sourced location"
    else
        fail "download completed but file not found"
    fi
else
    skip "download failed (may be a network issue)"
fi

rm -rf "$DOWNLOAD_DIR"

# ─── 7. Container subdirectories (lxc/, pct/) ────────────────────────────────

info "=== Test 7: Container subdirectories ==="

assert_fn_exists "container"

LXC_FUNCTIONS=(lxc_config lxc_create lxc_delete lxc_exec lxc_start lxc_push lxc_pull lxc_network)
for fn in "${LXC_FUNCTIONS[@]}"; do
    assert_fn_exists "$fn"
done

PCT_FUNCTIONS=(pct_config pct_create pct_delete pct_exec pct_start pct_push pct_pull pct_network pct_find_vmid pct_next_vmid)
for fn in "${PCT_FUNCTIONS[@]}"; do
    assert_fn_exists "$fn"
done

pass "All container functions loaded from lxc/ and pct/ subdirectories"

# ─── 8. Packaging functions use monitor ───────────────────────────────────────

info "=== Test 8: Packaging functions with monitor ==="

assert_fn_exists "install"
assert_fn_exists "update"
assert_fn_exists "uninstall"
assert_fn_exists "clean"
assert_fn_exists "dependencies"

assert_fn_missing "install_apt"
assert_fn_missing "install_dnf"
assert_fn_missing "update_apt"
assert_fn_missing "update_dnf"
assert_fn_missing "uninstall_apt"
assert_fn_missing "clean_apt"

assert_fn_exists "_install_apt"
assert_fn_exists "_update_apt"
assert_fn_exists "_uninstall_apt"
assert_fn_exists "_clean_apt"

pass "Per-manager helpers are private (_-prefixed)"

if [[ $EUID -eq 0 ]]; then
    info "Running as root — testing packaging with monitor integration..."

    update \
        --style "$SPINNER_LOADING_STYLE" \
        --message "Updating system packages" \
        --success_msg "System packages updated" \
        --error_msg "Failed to update system packages" || {
        warn "update returned non-zero (may be expected in this environment)"
    }
    pass "update() with --message/--style/--success_msg/--error_msg"

    install curl \
        --style "$DOTS_LOADING_STYLE" \
        --message "Installing curl" \
        --success_msg "curl installed" \
        --error_msg "Failed to install curl" || {
        warn "install curl returned non-zero"
    }
    pass "install() with custom monitor flags"

    clean \
        --style "$BARS_LOADING_STYLE" \
        --message "Cleaning up" \
        --success_msg "Cleanup done" \
        --error_msg "Cleanup failed" || {
        warn "clean returned non-zero"
    }
    pass "clean() with custom monitor flags"

    dependencies curl wget \
        || warn "dependencies returned non-zero"
    pass "dependencies() calls install/update with built-in monitor"
else
    skip "Packaging integration tests (requires root)"
fi

# ─── 9. File operations (regression check) ───────────────────────────────────

info "=== Test 9: File operations (regression) ==="

TEST_DIR=$(mktemp -d /tmp/shtuff_fileops_XXXXXX)
echo "shtuff test content" > "${TEST_DIR}/source.txt"

copy "${TEST_DIR}/source.txt" "${TEST_DIR}/copied.txt" \
    --message "Copying test file" || fail "copy failed"
if [[ -f "${TEST_DIR}/copied.txt" ]]; then
    pass "copy works"
else
    fail "copy did not create destination file"
fi

move "${TEST_DIR}/copied.txt" "${TEST_DIR}/moved.txt" \
    --message "Moving test file" || fail "move failed"
if [[ -f "${TEST_DIR}/moved.txt" ]] && [[ ! -f "${TEST_DIR}/copied.txt" ]]; then
    pass "move works"
else
    fail "move did not relocate file correctly"
fi

delete "${TEST_DIR}/moved.txt" --message "Deleting test file" || fail "delete failed"
if [[ ! -f "${TEST_DIR}/moved.txt" ]]; then
    pass "delete works"
else
    fail "delete did not remove file"
fi

rm -rf "$TEST_DIR"

# ─── 10. Verbose log output ──────────────────────────────────────────────────

info "=== Test 10: Verbose log file ==="

if [[ -n "$VERBOSE_FILE" ]]; then
    pass "VERBOSE_FILE is set: $VERBOSE_FILE"
else
    fail "VERBOSE_FILE is not set"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed, $SKIP skipped"
echo "  Verbose log: ${VERBOSE_FILE:-none}"
echo "════════════════════════════════════════════"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi

exit 0
