#!/usr/bin/env bash
# Tests for --dry-run flag behaviors across all shtuff functions that support it.
# Verifies that dry-run prints the expected commands without executing any of them.

SHTUFF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SHTUFF_DIR/shtuff.sh"

# Suppress info/warn log output during tests for cleaner output.
LOG_LEVEL="error"

PASS=0
FAIL=0

# ─── Assertion helpers ────────────────────────────────────────────────────────

assert_exit_code() {
    local description="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo "PASS: $description"
        PASS=$(( PASS + 1 ))
    else
        echo "FAIL: $description" >&2
        echo "  Expected exit code: $expected, got: $actual" >&2
        FAIL=$(( FAIL + 1 ))
    fi
}

assert_contains() {
    local description="$1" expected="$2" actual="$3"
    if echo "$actual" | grep -qF -- "$expected"; then
        echo "PASS: $description"
        PASS=$(( PASS + 1 ))
    else
        echo "FAIL: $description" >&2
        echo "  Expected output to contain: $expected" >&2
        echo "  Actual output:" >&2
        echo "$actual" | sed 's/^/    /' >&2
        FAIL=$(( FAIL + 1 ))
    fi
}

assert_file_exists() {
    local description="$1" path="$2"
    if [[ -e "$path" ]]; then
        echo "PASS: $description"
        PASS=$(( PASS + 1 ))
    else
        echo "FAIL: $description" >&2
        echo "  Expected file to exist: $path" >&2
        FAIL=$(( FAIL + 1 ))
    fi
}

assert_file_missing() {
    local description="$1" path="$2"
    if [[ ! -e "$path" ]]; then
        echo "PASS: $description"
        PASS=$(( PASS + 1 ))
    else
        echo "FAIL: $description" >&2
        echo "  Expected file to NOT exist: $path" >&2
        FAIL=$(( FAIL + 1 ))
    fi
}

# ─── copy --dry-run ───────────────────────────────────────────────────────────

test_copy_dry_run() {
    local tmpdir; tmpdir=$(mktemp -d)
    local src_file="$tmpdir/source.txt"
    local src_dir="$tmpdir/sourcedir"
    local dest="$tmpdir/dest"
    echo "hello" > "$src_file"
    mkdir -p "$src_dir" "$dest"

    local output exit_code

    # Single file with --dry-run flag
    output=$(copy --dry-run "$src_file" "$dest" 2>/dev/null)
    exit_code=$?
    assert_exit_code "copy --dry-run (file) returns 0" 0 "$exit_code"
    assert_contains "copy --dry-run (file) prints cp command" \
        "cp \"$src_file\" \"$dest\"" "$output"
    assert_file_missing "copy --dry-run (file) does not create file at dest" \
        "$dest/source.txt"

    # Directory with --dry-run flag
    output=$(copy --dry-run "$src_dir" "$dest" 2>/dev/null)
    exit_code=$?
    assert_exit_code "copy --dry-run (dir) returns 0" 0 "$exit_code"
    assert_contains "copy --dry-run (dir) prints cp -r command" \
        "cp -r \"$src_dir\" \"$dest\"" "$output"
    assert_file_missing "copy --dry-run (dir) does not copy directory to dest" \
        "$dest/sourcedir"

    # Multiple sources
    local src2="$tmpdir/source2.txt"; echo "world" > "$src2"
    output=$(copy --dry-run "$src_file" "$src2" "$dest" 2>/dev/null)
    assert_contains "copy --dry-run (multi) prints command for first source" \
        "cp \"$src_file\" \"$dest\"" "$output"
    assert_contains "copy --dry-run (multi) prints command for second source" \
        "cp \"$src2\" \"$dest\"" "$output"
    assert_file_missing "copy --dry-run (multi) does not create first file at dest" \
        "$dest/source.txt"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(copy "$src_file" "$dest" 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for copy" \
        "cp \"$src_file\" \"$dest\"" "$output"
    assert_file_missing "IS_DRY_RUN=true copy does not create file at dest" \
        "$dest/source.txt"

    rm -rf "$tmpdir"
}

# ─── delete --dry-run ─────────────────────────────────────────────────────────

test_delete_dry_run() {
    local tmpdir; tmpdir=$(mktemp -d)
    local file="$tmpdir/file.txt"
    local dir="$tmpdir/subdir"
    echo "data" > "$file"
    mkdir -p "$dir"

    local output exit_code

    # Single file
    output=$(delete --dry-run "$file" 2>/dev/null)
    exit_code=$?
    assert_exit_code "delete --dry-run (file) returns 0" 0 "$exit_code"
    assert_contains "delete --dry-run (file) prints rm command" \
        "rm \"$file\"" "$output"
    assert_file_exists "delete --dry-run (file) does not remove file" "$file"

    # Single directory
    output=$(delete --dry-run "$dir" 2>/dev/null)
    exit_code=$?
    assert_exit_code "delete --dry-run (dir) returns 0" 0 "$exit_code"
    assert_contains "delete --dry-run (dir) prints rm -rf command" \
        "rm -rf \"$dir\"" "$output"
    assert_file_exists "delete --dry-run (dir) does not remove directory" "$dir"

    # Multiple targets: file and directory together
    output=$(delete --dry-run "$file" "$dir" 2>/dev/null)
    assert_contains "delete --dry-run (multi) prints rm for file" \
        "rm \"$file\"" "$output"
    assert_contains "delete --dry-run (multi) prints rm -rf for dir" \
        "rm -rf \"$dir\"" "$output"
    assert_file_exists "delete --dry-run (multi) does not remove file" "$file"
    assert_file_exists "delete --dry-run (multi) does not remove directory" "$dir"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(delete "$file" 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for delete" \
        "rm \"$file\"" "$output"
    assert_file_exists "IS_DRY_RUN=true delete does not remove file" "$file"

    rm -rf "$tmpdir"
}

# ─── move --dry-run ───────────────────────────────────────────────────────────

test_move_dry_run() {
    local tmpdir; tmpdir=$(mktemp -d)
    local src="$tmpdir/source.txt"
    local dest="$tmpdir/dest"
    echo "data" > "$src"
    mkdir -p "$dest"

    local output exit_code

    # Single file
    output=$(move --dry-run "$src" "$dest" 2>/dev/null)
    exit_code=$?
    assert_exit_code "move --dry-run returns 0" 0 "$exit_code"
    assert_contains "move --dry-run prints mv command" \
        "mv \"$src\" \"$dest\"" "$output"
    assert_file_exists "move --dry-run does not remove source file" "$src"
    assert_file_missing "move --dry-run does not create file at dest" \
        "$dest/source.txt"

    # Multiple sources
    local src2="$tmpdir/source2.txt"; echo "data2" > "$src2"
    output=$(move --dry-run "$src" "$src2" "$dest" 2>/dev/null)
    assert_contains "move --dry-run (multi) prints mv for first source" \
        "mv \"$src\" \"$dest\"" "$output"
    assert_contains "move --dry-run (multi) prints mv for second source" \
        "mv \"$src2\" \"$dest\"" "$output"
    assert_file_exists "move --dry-run (multi) does not remove first source" "$src"
    assert_file_exists "move --dry-run (multi) does not remove second source" "$src2"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(move "$src" "$dest" 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for move" \
        "mv \"$src\" \"$dest\"" "$output"
    assert_file_exists "IS_DRY_RUN=true move does not remove source file" "$src"

    rm -rf "$tmpdir"
}

# ─── service --dry-run ────────────────────────────────────────────────────────

test_service_dry_run() {
    local tmpdir; tmpdir=$(mktemp -d)
    local output exit_code

    # Minimal required arguments
    output=$(service \
        --name "test-svc" \
        --description "Test Service" \
        --exec-start "/usr/bin/test" \
        --output-dir "$tmpdir" \
        --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "service --dry-run returns 0" 0 "$exit_code"
    assert_contains "service --dry-run prints would-write header" \
        "would write $tmpdir/test-svc.service" "$output"
    assert_contains "service --dry-run prints [Unit] section" \
        "[Unit]" "$output"
    assert_contains "service --dry-run prints Description" \
        "Description=Test Service" "$output"
    assert_contains "service --dry-run prints After=network.target" \
        "After=network.target" "$output"
    assert_contains "service --dry-run prints [Service] section" \
        "[Service]" "$output"
    assert_contains "service --dry-run prints ExecStart" \
        "ExecStart=/usr/bin/test" "$output"
    assert_contains "service --dry-run prints default Restart policy" \
        "Restart=on-failure" "$output"
    assert_contains "service --dry-run prints default RestartSec" \
        "RestartSec=5s" "$output"
    assert_contains "service --dry-run prints [Install] section" \
        "[Install]" "$output"
    assert_contains "service --dry-run prints default WantedBy" \
        "WantedBy=multi-user.target" "$output"
    assert_file_missing "service --dry-run does not create unit file" \
        "$tmpdir/test-svc.service"

    # Auto-appends .service extension when omitted
    output=$(service \
        --name "no-ext" \
        --description "No Ext" \
        --exec-start "/usr/bin/noext" \
        --output-dir "$tmpdir" \
        --dry-run 2>/dev/null)
    assert_contains "service --dry-run auto-appends .service extension" \
        "would write $tmpdir/no-ext.service" "$output"

    # All optional fields
    output=$(service \
        --name "full-svc" \
        --description "Full Service" \
        --exec-start "/usr/bin/myapp" \
        --user "myuser" \
        --group "mygroup" \
        --working-directory "/opt/myapp" \
        --restart "always" \
        --restart-sec "10" \
        --environment "PORT=3000 NODE_ENV=production" \
        --exec-start-pre "/usr/bin/precheck" \
        --exec-stop "/usr/bin/cleanup" \
        --wanted-by "default.target" \
        --output-dir "$tmpdir" \
        --dry-run 2>/dev/null)
    assert_contains "service --dry-run prints User" \
        "User=myuser" "$output"
    assert_contains "service --dry-run prints Group" \
        "Group=mygroup" "$output"
    assert_contains "service --dry-run prints WorkingDirectory" \
        "WorkingDirectory=/opt/myapp" "$output"
    assert_contains "service --dry-run prints Restart=always" \
        "Restart=always" "$output"
    assert_contains "service --dry-run prints RestartSec=10s" \
        "RestartSec=10s" "$output"
    assert_contains "service --dry-run prints first Environment variable" \
        "Environment=PORT=3000" "$output"
    assert_contains "service --dry-run prints second Environment variable" \
        "Environment=NODE_ENV=production" "$output"
    assert_contains "service --dry-run prints ExecStartPre" \
        "ExecStartPre=/usr/bin/precheck" "$output"
    assert_contains "service --dry-run prints ExecStop" \
        "ExecStop=/usr/bin/cleanup" "$output"
    assert_contains "service --dry-run prints custom WantedBy" \
        "WantedBy=default.target" "$output"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(service \
        --name "global-dry" \
        --description "Global Dry" \
        --exec-start "/usr/bin/test" \
        --output-dir "$tmpdir" 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for service" \
        "would write" "$output"
    assert_file_missing "IS_DRY_RUN=true service does not create unit file" \
        "$tmpdir/global-dry.service"

    rm -rf "$tmpdir"
}

# ─── timer --dry-run ──────────────────────────────────────────────────────────

test_timer_dry_run() {
    local tmpdir; tmpdir=$(mktemp -d)
    local output exit_code

    # On-calendar schedule
    output=$(timer \
        --name "test-timer" \
        --description "Test Timer" \
        --on-calendar "daily" \
        --output-dir "$tmpdir" \
        --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "timer --dry-run returns 0" 0 "$exit_code"
    assert_contains "timer --dry-run prints would-write header" \
        "would write $tmpdir/test-timer.timer" "$output"
    assert_contains "timer --dry-run prints [Unit] section" \
        "[Unit]" "$output"
    assert_contains "timer --dry-run prints Description" \
        "Description=Test Timer" "$output"
    assert_contains "timer --dry-run prints [Timer] section" \
        "[Timer]" "$output"
    assert_contains "timer --dry-run prints OnCalendar" \
        "OnCalendar=daily" "$output"
    assert_contains "timer --dry-run prints [Install] section" \
        "[Install]" "$output"
    assert_contains "timer --dry-run prints default WantedBy" \
        "WantedBy=timers.target" "$output"
    assert_file_missing "timer --dry-run does not create timer file" \
        "$tmpdir/test-timer.timer"

    # On-boot-sec + on-unit-active-sec + persistent
    output=$(timer \
        --name "boot-timer" \
        --on-boot-sec "5min" \
        --on-unit-active-sec "1h" \
        --persistent \
        --output-dir "$tmpdir" \
        --dry-run 2>/dev/null)
    assert_contains "timer --dry-run prints OnBootSec" \
        "OnBootSec=5min" "$output"
    assert_contains "timer --dry-run prints OnUnitActiveSec" \
        "OnUnitActiveSec=1h" "$output"
    assert_contains "timer --dry-run prints Persistent=true" \
        "Persistent=true" "$output"

    # On-unit-inactive-sec + randomized delay + custom unit
    output=$(timer \
        --name "random-timer" \
        --on-calendar "weekly" \
        --on-unit-inactive-sec "30min" \
        --randomized-delay "10min" \
        --unit "myapp.service" \
        --output-dir "$tmpdir" \
        --dry-run 2>/dev/null)
    assert_contains "timer --dry-run prints OnUnitInactiveSec" \
        "OnUnitInactiveSec=30min" "$output"
    assert_contains "timer --dry-run prints RandomizedDelaySec" \
        "RandomizedDelaySec=10min" "$output"
    assert_contains "timer --dry-run prints custom Unit" \
        "Unit=myapp.service" "$output"

    # Default description when omitted
    output=$(timer \
        --name "nodesc-timer" \
        --on-calendar "hourly" \
        --output-dir "$tmpdir" \
        --dry-run 2>/dev/null)
    assert_contains "timer --dry-run uses default description when omitted" \
        "Description=Timer for nodesc-timer" "$output"

    # Custom wanted-by
    output=$(timer \
        --name "wanted-timer" \
        --on-calendar "daily" \
        --wanted-by "multi-user.target" \
        --output-dir "$tmpdir" \
        --dry-run 2>/dev/null)
    assert_contains "timer --dry-run prints custom WantedBy" \
        "WantedBy=multi-user.target" "$output"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(timer \
        --name "global-dry" \
        --on-calendar "daily" \
        --output-dir "$tmpdir" 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for timer" \
        "would write" "$output"
    assert_file_missing "IS_DRY_RUN=true timer does not create timer file" \
        "$tmpdir/global-dry.timer"

    rm -rf "$tmpdir"
}

# ─── check_port --dry-run ─────────────────────────────────────────────────────

test_check_port_dry_run() {
    local output exit_code

    output=$(check_port --port 8080 --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "check_port --dry-run returns 0" 0 "$exit_code"
    assert_contains "check_port --dry-run prints port check description" \
        "check if port 8080 is bound" "$output"

    # Different port number
    output=$(check_port --port 443 --dry-run 2>/dev/null)
    assert_contains "check_port --dry-run prints correct port number" \
        "check if port 443 is bound" "$output"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(check_port --port 9090 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for check_port" \
        "check if port 9090 is bound" "$output"
}

# ─── wait_for_port --dry-run ──────────────────────────────────────────────────

test_wait_for_port_dry_run() {
    local output exit_code

    # Default timeout and interval
    output=$(wait_for_port --host 127.0.0.1 --port 8080 --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "wait_for_port --dry-run returns 0" 0 "$exit_code"
    assert_contains "wait_for_port --dry-run prints poll message with host:port" \
        "poll 127.0.0.1:8080" "$output"
    assert_contains "wait_for_port --dry-run prints default timeout" \
        "30s" "$output"
    assert_contains "wait_for_port --dry-run prints default interval" \
        "2s" "$output"

    # Custom timeout and interval
    output=$(wait_for_port --host 10.0.0.1 --port 5432 --timeout 60 --interval 5 --dry-run 2>/dev/null)
    assert_contains "wait_for_port --dry-run prints custom host:port" \
        "poll 10.0.0.1:5432" "$output"
    assert_contains "wait_for_port --dry-run prints custom timeout" \
        "60s" "$output"
    assert_contains "wait_for_port --dry-run prints custom interval" \
        "5s" "$output"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(wait_for_port --host 127.0.0.1 --port 3306 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for wait_for_port" \
        "poll 127.0.0.1:3306" "$output"
}

# ─── bridge --dry-run ─────────────────────────────────────────────────────────

test_bridge_dry_run() {
    if ! command -v ip &>/dev/null; then
        echo "SKIP: bridge dry-run tests (ip command not found)"
        return 0
    fi

    local output exit_code

    # create with IP address
    output=$(bridge create --name lxcbr0 --ip 10.0.0.1/24 --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "bridge create --dry-run returns 0" 0 "$exit_code"
    assert_contains "bridge create --dry-run prints ip link add" \
        "ip link add lxcbr0 type bridge" "$output"
    assert_contains "bridge create --dry-run prints ip addr add for IP" \
        "ip addr add 10.0.0.1/24 dev lxcbr0" "$output"
    assert_contains "bridge create --dry-run prints ip link set up" \
        "ip link set lxcbr0 up" "$output"

    # create without IP address (omits ip addr add)
    output=$(bridge create --name lxcbr1 --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "bridge create --dry-run (no IP) returns 0" 0 "$exit_code"
    assert_contains "bridge create --dry-run (no IP) prints ip link add" \
        "ip link add lxcbr1 type bridge" "$output"

    # delete
    output=$(bridge delete --name lxcbr0 --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "bridge delete --dry-run returns 0" 0 "$exit_code"
    assert_contains "bridge delete --dry-run prints ip link set down" \
        "ip link set lxcbr0 down" "$output"
    assert_contains "bridge delete --dry-run prints ip link delete" \
        "ip link delete lxcbr0 type bridge" "$output"

    # add-interface
    output=$(bridge add-interface --name lxcbr0 --interface eth0 --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "bridge add-interface --dry-run returns 0" 0 "$exit_code"
    assert_contains "bridge add-interface --dry-run prints ip link set master" \
        "ip link set eth0 master lxcbr0" "$output"

    # remove-interface
    output=$(bridge remove-interface --name lxcbr0 --interface eth0 --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "bridge remove-interface --dry-run returns 0" 0 "$exit_code"
    assert_contains "bridge remove-interface --dry-run prints ip link set nomaster" \
        "ip link set eth0 nomaster" "$output"
}

# ─── forward --dry-run ────────────────────────────────────────────────────────

test_forward_dry_run() {
    if ! command -v iptables &>/dev/null; then
        echo "SKIP: forward dry-run tests (iptables command not found)"
        return 0
    fi

    local output exit_code

    # add: tcp with explicit to-port
    output=$(forward add --from-port 8080 --to-host 10.0.0.10 --to-port 80 --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "forward add --dry-run returns 0" 0 "$exit_code"
    assert_contains "forward add --dry-run prints ip_forward enable" \
        "echo 1 > /proc/sys/net/ipv4/ip_forward" "$output"
    assert_contains "forward add --dry-run prints DNAT PREROUTING rule" \
        "iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 10.0.0.10:80" "$output"
    assert_contains "forward add --dry-run prints MASQUERADE POSTROUTING rule" \
        "iptables -t nat -A POSTROUTING -j MASQUERADE" "$output"

    # add: udp protocol
    output=$(forward add --from-port 5353 --to-host 10.0.0.20 --protocol udp --dry-run 2>/dev/null)
    assert_contains "forward add --dry-run (udp) uses udp protocol in DNAT rule" \
        "-p udp --dport 5353" "$output"

    # add: to-port defaults to from-port when omitted
    output=$(forward add --from-port 2222 --to-host 10.0.0.10 --dry-run 2>/dev/null)
    assert_contains "forward add --dry-run defaults to-port to from-port" \
        "--to-destination 10.0.0.10:2222" "$output"

    # remove
    output=$(forward remove --from-port 8080 --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "forward remove --dry-run returns 0" 0 "$exit_code"
    assert_contains "forward remove --dry-run prints iptables -D PREROUTING" \
        "iptables -t nat -D PREROUTING" "$output"

    # remove: udp protocol
    output=$(forward remove --from-port 5353 --protocol udp --dry-run 2>/dev/null)
    assert_contains "forward remove --dry-run (udp) mentions protocol" \
        "-p udp" "$output"

    # list
    output=$(forward list --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "forward list --dry-run returns 0" 0 "$exit_code"
    assert_contains "forward list --dry-run prints iptables -L PREROUTING" \
        "iptables -t nat -L PREROUTING" "$output"
}

# ─── Error cases: validation still runs before dry-run output ─────────────────

test_dry_run_error_cases() {
    local exit_code

    # copy: requires at least source + destination (2 paths)
    copy --dry-run /only/one/path &>/dev/null; exit_code=$?
    assert_exit_code "copy --dry-run fails with only one path" 1 "$exit_code"

    # delete: requires at least one target
    delete --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "delete --dry-run fails with no targets" 1 "$exit_code"

    # move: requires at least source + destination (2 paths)
    move --dry-run /only/one/path &>/dev/null; exit_code=$?
    assert_exit_code "move --dry-run fails with only one path" 1 "$exit_code"

    # service: requires --name
    service --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "service --dry-run fails with no arguments" 1 "$exit_code"

    # service: requires --description
    service --name "test" --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "service --dry-run fails without --description" 1 "$exit_code"

    # service: requires --exec-start
    service --name "test" --description "Test" --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "service --dry-run fails without --exec-start" 1 "$exit_code"

    # timer: requires --name
    timer --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "timer --dry-run fails with no arguments" 1 "$exit_code"

    # timer: rejects names with invalid characters
    timer --name "invalid name!" --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "timer --dry-run fails with invalid name characters" 1 "$exit_code"

    # check_port: requires --port
    check_port --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "check_port --dry-run fails with no port" 2 "$exit_code"

    # check_port: rejects port numbers out of range
    check_port --port 99999 --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "check_port --dry-run fails with out-of-range port" 2 "$exit_code"

    # wait_for_port: requires --host
    wait_for_port --port 8080 --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "wait_for_port --dry-run fails with no host" 1 "$exit_code"

    # wait_for_port: requires --port
    wait_for_port --host localhost --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "wait_for_port --dry-run fails with no port" 1 "$exit_code"

    # wait_for_port: rejects invalid port number
    wait_for_port --host localhost --port 0 --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "wait_for_port --dry-run fails with port 0" 1 "$exit_code"
}

# ─── Run all tests ────────────────────────────────────────────────────────────

echo "=== Dry Run Function Tests ==="
echo ""

test_copy_dry_run
echo ""

test_delete_dry_run
echo ""

test_move_dry_run
echo ""

test_service_dry_run
echo ""

test_timer_dry_run
echo ""

test_check_port_dry_run
echo ""

test_wait_for_port_dry_run
echo ""

test_bridge_dry_run
echo ""

test_forward_dry_run
echo ""

test_dry_run_error_cases
echo ""

echo "Results: $PASS passed, $FAIL failed"
if (( FAIL > 0 )); then
    exit 1
fi
exit 0
