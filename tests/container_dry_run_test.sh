#!/usr/bin/env bash
# Tests for --dry-run flag behaviors across all container functions (lxc_* and pct_*).
# Verifies that dry-run prints the expected commands without executing any of them.
# All container dry-run paths output the would-be commands to stdout and return 0
# before any real system checks (root privilege, binary availability) are performed,
# except lxc_config which runs pre-flight checks first and is skipped when LXC is absent.

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

# ─── lxc_create --dry-run ─────────────────────────────────────────────────────

test_lxc_create_dry_run() {
    local output exit_code

    # Minimal: default download template, dir storage
    output=$(lxc_create --name myct --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "lxc_create --dry-run returns 0" 0 "$exit_code"
    assert_contains "lxc_create --dry-run prints lxc-create command" \
        "lxc-create" "$output"
    assert_contains "lxc_create --dry-run includes container name" \
        '-n "myct"' "$output"
    assert_contains "lxc_create --dry-run uses default dir storage" \
        '-B "dir"' "$output"
    assert_contains "lxc_create --dry-run uses download template" \
        "-t download" "$output"
    assert_contains "lxc_create --dry-run includes default dist" \
        '--dist "debian"' "$output"
    assert_contains "lxc_create --dry-run includes default release" \
        '--release "trixie"' "$output"
    assert_contains "lxc_create --dry-run includes default arch" \
        '--arch "amd64"' "$output"

    # Custom distribution and release
    output=$(lxc_create --name webct --dist ubuntu --release jammy --arch arm64 --dry-run 2>/dev/null)
    assert_contains "lxc_create --dry-run uses custom dist" \
        '--dist "ubuntu"' "$output"
    assert_contains "lxc_create --dry-run uses custom release" \
        '--release "jammy"' "$output"
    assert_contains "lxc_create --dry-run uses custom arch" \
        '--arch "arm64"' "$output"

    # Custom (non-download) template
    output=$(lxc_create --name myct --template local --dry-run 2>/dev/null)
    assert_contains "lxc_create --dry-run uses custom template" \
        '-t "local"' "$output"

    # btrfs storage + disk-size: should include --bsize
    output=$(lxc_create --name myct --storage btrfs --disk-size 16 --dry-run 2>/dev/null)
    assert_contains "lxc_create --dry-run includes btrfs storage" \
        '-B "btrfs"' "$output"
    assert_contains "lxc_create --dry-run includes --bsize for btrfs" \
        '--bsize "16G"' "$output"

    # zfs storage + disk-size: should include --bsize
    output=$(lxc_create --name myct --storage zfs --disk-size 8 --dry-run 2>/dev/null)
    assert_contains "lxc_create --dry-run includes --bsize for zfs" \
        '--bsize "8G"' "$output"

    # disk-size without btrfs/zfs: --bsize should NOT appear
    output=$(lxc_create --name myct --storage dir --disk-size 20 --dry-run 2>/dev/null)
    if echo "$output" | grep -qF -- '--bsize'; then
        echo "FAIL: lxc_create --dry-run omits --bsize for dir storage" >&2
        FAIL=$(( FAIL + 1 ))
    else
        echo "PASS: lxc_create --dry-run omits --bsize for dir storage"
        PASS=$(( PASS + 1 ))
    fi

    # --hostname: should print config append command
    output=$(lxc_create --name myct --hostname myhost --dry-run 2>/dev/null)
    assert_contains "lxc_create --dry-run prints hostname config line" \
        "lxc.uts.name" "$output"
    assert_contains "lxc_create --dry-run includes hostname value" \
        "myhost" "$output"

    # --memory: should print config append command
    output=$(lxc_create --name myct --memory 1024 --dry-run 2>/dev/null)
    assert_contains "lxc_create --dry-run prints memory config line" \
        "lxc.cgroup2.memory.max" "$output"
    assert_contains "lxc_create --dry-run includes memory value" \
        "1024" "$output"

    # --cores: should print config append command with correct max index (cores-1)
    output=$(lxc_create --name myct --cores 4 --dry-run 2>/dev/null)
    assert_contains "lxc_create --dry-run prints cpuset config line" \
        "lxc.cgroup2.cpuset.cpus" "$output"
    assert_contains "lxc_create --dry-run includes correct core max index" \
        '"3"' "$output"

    # --password: should print password-setting sequence with masked password
    output=$(lxc_create --name myct --password secret --dry-run 2>/dev/null)
    assert_contains "lxc_create --dry-run prints lxc-start for password" \
        'lxc-start -n "myct"' "$output"
    assert_contains "lxc_create --dry-run prints chpasswd for password" \
        "chpasswd" "$output"
    assert_contains "lxc_create --dry-run masks the password" \
        "***" "$output"
    assert_contains "lxc_create --dry-run prints lxc-stop for password" \
        'lxc-stop -n "myct"' "$output"

    # All optional fields together
    output=$(lxc_create --name fullct \
        --dist ubuntu --release focal --arch amd64 \
        --hostname full.local --memory 2048 --cores 2 \
        --storage btrfs --disk-size 32 \
        --dry-run 2>/dev/null)
    assert_contains "lxc_create --dry-run (full) prints lxc-create" \
        "lxc-create" "$output"
    assert_contains "lxc_create --dry-run (full) includes bsize" \
        '--bsize "32G"' "$output"
    assert_contains "lxc_create --dry-run (full) includes hostname" \
        "full.local" "$output"
    assert_contains "lxc_create --dry-run (full) includes memory" \
        "2048" "$output"
    assert_contains "lxc_create --dry-run (full) includes core max index" \
        '"1"' "$output"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(lxc_create --name myct 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for lxc_create" \
        "lxc-create" "$output"
}

# ─── lxc_delete --dry-run ─────────────────────────────────────────────────────

test_lxc_delete_dry_run() {
    local output exit_code

    # Without --force
    output=$(lxc_delete --name myct --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "lxc_delete --dry-run returns 0" 0 "$exit_code"
    assert_contains "lxc_delete --dry-run prints lxc-destroy command" \
        "lxc-destroy" "$output"
    assert_contains "lxc_delete --dry-run includes container name" \
        '-n "myct"' "$output"
    # -f should NOT appear without --force
    if echo "$output" | grep -qF -- ' -f'; then
        echo "FAIL: lxc_delete --dry-run omits -f without --force" >&2
        FAIL=$(( FAIL + 1 ))
    else
        echo "PASS: lxc_delete --dry-run omits -f without --force"
        PASS=$(( PASS + 1 ))
    fi

    # With --force
    output=$(lxc_delete --name myct --force --dry-run 2>/dev/null)
    assert_contains "lxc_delete --force --dry-run includes -f flag" \
        "-f" "$output"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(lxc_delete --name myct 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for lxc_delete" \
        "lxc-destroy" "$output"
}

# ─── lxc_start --dry-run ──────────────────────────────────────────────────────

test_lxc_start_dry_run() {
    local output exit_code

    output=$(lxc_start --name myct --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "lxc_start --dry-run returns 0" 0 "$exit_code"
    assert_contains "lxc_start --dry-run prints lxc-start command" \
        "lxc-start" "$output"
    assert_contains "lxc_start --dry-run includes container name" \
        '-n "myct"' "$output"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(lxc_start --name myct 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for lxc_start" \
        "lxc-start" "$output"
}

# ─── lxc_exec --dry-run ───────────────────────────────────────────────────────

test_lxc_exec_dry_run() {
    local output exit_code

    # Single command
    output=$(lxc_exec --name myct --dry-run -- systemctl restart nginx 2>/dev/null)
    exit_code=$?
    assert_exit_code "lxc_exec --dry-run returns 0" 0 "$exit_code"
    assert_contains "lxc_exec --dry-run prints lxc-attach command" \
        "lxc-attach" "$output"
    assert_contains "lxc_exec --dry-run includes container name" \
        '-n "myct"' "$output"
    assert_contains "lxc_exec --dry-run includes command" \
        "systemctl restart nginx" "$output"

    # Multi-word shell command
    output=$(lxc_exec --name myct --dry-run -- bash -c "apt-get update" 2>/dev/null)
    assert_contains "lxc_exec --dry-run includes shell command" \
        "bash" "$output"
    assert_contains "lxc_exec --dry-run includes -c argument" \
        "apt-get update" "$output"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(lxc_exec --name myct -- echo hello 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for lxc_exec" \
        "lxc-attach" "$output"
}

# ─── lxc_enter --dry-run ──────────────────────────────────────────────────────

test_lxc_enter_dry_run() {
    local output exit_code

    # Default user (root) and shell (/bin/bash)
    output=$(lxc_enter --name myct --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "lxc_enter --dry-run returns 0" 0 "$exit_code"
    assert_contains "lxc_enter --dry-run prints conditional lxc-start" \
        'lxc-start -n "myct" (if not running)' "$output"
    assert_contains "lxc_enter --dry-run prints lxc-attach with su" \
        "lxc-attach" "$output"
    assert_contains "lxc_enter --dry-run uses default root user" \
        '"root"' "$output"
    assert_contains "lxc_enter --dry-run uses default bash shell" \
        '"/bin/bash"' "$output"

    # Custom user and shell
    output=$(lxc_enter --name myct --user deploy --shell /bin/sh --dry-run 2>/dev/null)
    assert_contains "lxc_enter --dry-run uses custom user" \
        '"deploy"' "$output"
    assert_contains "lxc_enter --dry-run uses custom shell" \
        '"/bin/sh"' "$output"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(lxc_enter --name myct 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for lxc_enter" \
        "lxc-attach" "$output"
}

# ─── lxc_config --dry-run ─────────────────────────────────────────────────────
# lxc_config checks for lxc-info and container existence before the dry-run path,
# so these tests require LXC to be installed and a real container to exist.
# They are skipped when the preconditions cannot be met.

test_lxc_config_dry_run() {
    if ! command -v lxc-info &>/dev/null; then
        echo "SKIP: lxc_config dry-run tests (lxc-info not found)"
        return 0
    fi

    # Verify the test container exists; skip if it doesn't
    local test_container="shtuff-test-$$"
    if ! lxc-info -n "$test_container" &>/dev/null; then
        echo "SKIP: lxc_config dry-run tests (test container '$test_container' does not exist)"
        return 0
    fi

    local output exit_code
    local config_file="/var/lib/lxc/${test_container}/config"

    output=$(lxc_config --name "$test_container" --hostname newhost --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "lxc_config --dry-run returns 0" 0 "$exit_code"
    assert_contains "lxc_config --dry-run prints hostname config update" \
        "lxc.uts.name = newhost in $config_file" "$output"

    output=$(lxc_config --name "$test_container" --memory 2048 --dry-run 2>/dev/null)
    assert_contains "lxc_config --dry-run prints memory config update" \
        "lxc.cgroup2.memory.max = 2048M in $config_file" "$output"

    output=$(lxc_config --name "$test_container" --cores 4 --dry-run 2>/dev/null)
    assert_contains "lxc_config --dry-run prints cpuset config update" \
        "lxc.cgroup2.cpuset.cpus = 0-3 in $config_file" "$output"

    output=$(lxc_config --name "$test_container" \
        --set lxc.net.0.type=veth --dry-run 2>/dev/null)
    assert_contains "lxc_config --dry-run prints arbitrary key update" \
        "lxc.net.0.type = veth in $config_file" "$output"

    output=$(lxc_config --name "$test_container" \
        --memory 1024 --cores 2 --hostname updated \
        --set lxc.start.auto=1 --dry-run 2>/dev/null)
    assert_contains "lxc_config --dry-run (combined) prints hostname" \
        "lxc.uts.name = updated in $config_file" "$output"
    assert_contains "lxc_config --dry-run (combined) prints memory" \
        "lxc.cgroup2.memory.max = 1024M in $config_file" "$output"
    assert_contains "lxc_config --dry-run (combined) prints cpuset" \
        "lxc.cgroup2.cpuset.cpus = 0-1 in $config_file" "$output"
    assert_contains "lxc_config --dry-run (combined) prints custom key" \
        "lxc.start.auto = 1 in $config_file" "$output"
}

# ─── lxc_network --dry-run ────────────────────────────────────────────────────

test_lxc_network_dry_run() {
    local output exit_code
    local config_file="/var/lib/lxc/myct/config"

    # Default type (veth), bridge (lxcbr0), index (0)
    output=$(lxc_network --name myct --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "lxc_network --dry-run returns 0" 0 "$exit_code"
    assert_contains "lxc_network --dry-run sets lxc.net.0.type" \
        "set lxc.net.0.type = veth in $config_file" "$output"
    assert_contains "lxc_network --dry-run sets lxc.net.0.link to default bridge" \
        "set lxc.net.0.link = lxcbr0 in $config_file" "$output"
    assert_contains "lxc_network --dry-run sets lxc.net.0.flags" \
        "set lxc.net.0.flags = up in $config_file" "$output"

    # With static IP
    output=$(lxc_network --name myct --ip 10.0.0.10/24 --dry-run 2>/dev/null)
    assert_contains "lxc_network --dry-run prints ipv4.address" \
        "set lxc.net.0.ipv4.address = 10.0.0.10/24 in $config_file" "$output"

    # With static IP + gateway
    output=$(lxc_network --name myct --ip 10.0.0.10/24 --gateway 10.0.0.1 --dry-run 2>/dev/null)
    assert_contains "lxc_network --dry-run prints ipv4.gateway" \
        "set lxc.net.0.ipv4.gateway = 10.0.0.1 in $config_file" "$output"

    # Gateway is ignored without --ip
    output=$(lxc_network --name myct --gateway 10.0.0.1 --dry-run 2>/dev/null)
    if echo "$output" | grep -qF -- "ipv4.gateway"; then
        echo "FAIL: lxc_network --dry-run omits gateway when no IP is set" >&2
        FAIL=$(( FAIL + 1 ))
    else
        echo "PASS: lxc_network --dry-run omits gateway when no IP is set"
        PASS=$(( PASS + 1 ))
    fi

    # Custom hwaddr
    output=$(lxc_network --name myct --hwaddr "00:16:3e:ab:cd:ef" --dry-run 2>/dev/null)
    assert_contains "lxc_network --dry-run prints hwaddr" \
        "set lxc.net.0.hwaddr = 00:16:3e:ab:cd:ef in $config_file" "$output"

    # Custom bridge and interface index
    output=$(lxc_network --name myct --bridge br1 --index 1 --dry-run 2>/dev/null)
    assert_contains "lxc_network --dry-run uses custom bridge" \
        "set lxc.net.1.link = br1 in $config_file" "$output"
    assert_contains "lxc_network --dry-run uses custom interface index" \
        "set lxc.net.1.type" "$output"

    # type=none: link and flags should NOT appear
    output=$(lxc_network --name myct --type none --dry-run 2>/dev/null)
    assert_contains "lxc_network --dry-run (type=none) sets type" \
        "set lxc.net.0.type = none in $config_file" "$output"
    if echo "$output" | grep -qF -- "lxc.net.0.link"; then
        echo "FAIL: lxc_network --dry-run (type=none) omits link setting" >&2
        FAIL=$(( FAIL + 1 ))
    else
        echo "PASS: lxc_network --dry-run (type=none) omits link setting"
        PASS=$(( PASS + 1 ))
    fi

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(lxc_network --name myct 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for lxc_network" \
        "lxc.net.0.type" "$output"
}

# ─── lxc_pull --dry-run ───────────────────────────────────────────────────────

test_lxc_pull_dry_run() {
    local output exit_code
    local expected_rootfs_src="/var/lib/lxc/myct/rootfs/etc/myapp.conf"

    output=$(lxc_pull /etc/myapp.conf /tmp/myapp.conf --name myct --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "lxc_pull --dry-run returns 0" 0 "$exit_code"
    assert_contains "lxc_pull --dry-run includes rootfs source path" \
        "$expected_rootfs_src" "$output"
    assert_contains "lxc_pull --dry-run includes host destination path" \
        "/tmp/myapp.conf" "$output"
    # The copy command is either rsync -a or cp (both acceptable)
    if echo "$output" | grep -qF -- "rsync" || echo "$output" | grep -qF -- "cp "; then
        echo "PASS: lxc_pull --dry-run uses rsync or cp"
        PASS=$(( PASS + 1 ))
    else
        echo "FAIL: lxc_pull --dry-run uses rsync or cp" >&2
        echo "  Actual output: $output" >&2
        FAIL=$(( FAIL + 1 ))
    fi

    # A different container and paths
    output=$(lxc_pull /var/log/app.log /tmp/app.log --name webct --dry-run 2>/dev/null)
    assert_contains "lxc_pull --dry-run uses correct container rootfs" \
        "/var/lib/lxc/webct/rootfs/var/log/app.log" "$output"
    assert_contains "lxc_pull --dry-run uses correct host dest" \
        "/tmp/app.log" "$output"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(lxc_pull /etc/hosts /tmp/hosts --name myct 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for lxc_pull" \
        "/var/lib/lxc/myct/rootfs/etc/hosts" "$output"
}

# ─── lxc_push --dry-run ───────────────────────────────────────────────────────

test_lxc_push_dry_run() {
    local output exit_code
    local expected_rootfs_dest="/var/lib/lxc/myct/rootfs/etc/myapp.conf"

    output=$(lxc_push /tmp/myapp.conf /etc/myapp.conf --name myct --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "lxc_push --dry-run returns 0" 0 "$exit_code"
    assert_contains "lxc_push --dry-run includes host source path" \
        "/tmp/myapp.conf" "$output"
    assert_contains "lxc_push --dry-run includes rootfs destination path" \
        "$expected_rootfs_dest" "$output"
    # The copy command is either rsync -a or cp (both acceptable)
    if echo "$output" | grep -qF -- "rsync" || echo "$output" | grep -qF -- "cp "; then
        echo "PASS: lxc_push --dry-run uses rsync or cp"
        PASS=$(( PASS + 1 ))
    else
        echo "FAIL: lxc_push --dry-run uses rsync or cp" >&2
        echo "  Actual output: $output" >&2
        FAIL=$(( FAIL + 1 ))
    fi

    # A different container and paths
    output=$(lxc_push /opt/app /opt/app --name webct --dry-run 2>/dev/null)
    assert_contains "lxc_push --dry-run uses correct container rootfs" \
        "/var/lib/lxc/webct/rootfs/opt/app" "$output"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(lxc_push /etc/hosts /etc/hosts --name myct 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for lxc_push" \
        "/var/lib/lxc/myct/rootfs/etc/hosts" "$output"
}

# ─── pct_create --dry-run ─────────────────────────────────────────────────────

test_pct_create_dry_run() {
    local tmpl="local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
    local output exit_code

    # Minimal: only required args (vmid + template); all other fields use defaults
    output=$(pct_create --vmid 100 --template "$tmpl" --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "pct_create --dry-run returns 0" 0 "$exit_code"
    assert_contains "pct_create --dry-run prints pct create command" \
        "pct create" "$output"
    assert_contains "pct_create --dry-run includes vmid" \
        "100" "$output"
    assert_contains "pct_create --dry-run includes template" \
        "$tmpl" "$output"
    assert_contains "pct_create --dry-run includes default memory" \
        "--memory 512" "$output"
    assert_contains "pct_create --dry-run includes default cores" \
        "--cores 1" "$output"
    assert_contains "pct_create --dry-run includes default storage" \
        "--storage local-lvm" "$output"
    assert_contains "pct_create --dry-run includes default rootfs" \
        "--rootfs local-lvm:8" "$output"

    # Custom memory, cores, storage, and disk-size
    output=$(pct_create --vmid 101 --template "$tmpl" \
        --memory 2048 --cores 4 --storage local-zfs --disk-size 32 \
        --dry-run 2>/dev/null)
    assert_contains "pct_create --dry-run uses custom memory" \
        "--memory 2048" "$output"
    assert_contains "pct_create --dry-run uses custom cores" \
        "--cores 4" "$output"
    assert_contains "pct_create --dry-run uses custom storage" \
        "--storage local-zfs" "$output"
    assert_contains "pct_create --dry-run uses custom rootfs size" \
        "--rootfs local-zfs:32" "$output"

    # With --hostname
    output=$(pct_create --vmid 102 --template "$tmpl" --hostname myapp --dry-run 2>/dev/null)
    assert_contains "pct_create --dry-run includes hostname" \
        '--hostname "myapp"' "$output"

    # With --password: password value must be masked
    output=$(pct_create --vmid 103 --template "$tmpl" --password secret --dry-run 2>/dev/null)
    assert_contains "pct_create --dry-run masks password" \
        "--password ***" "$output"
    if echo "$output" | grep -qF -- "secret"; then
        echo "FAIL: pct_create --dry-run does not expose password in plaintext" >&2
        FAIL=$(( FAIL + 1 ))
    else
        echo "PASS: pct_create --dry-run does not expose password in plaintext"
        PASS=$(( PASS + 1 ))
    fi

    # All optional fields together
    output=$(pct_create --vmid 104 --template "$tmpl" \
        --hostname fullapp --memory 1024 --cores 2 \
        --storage local-lvm --disk-size 16 --password secret \
        --dry-run 2>/dev/null)
    assert_contains "pct_create --dry-run (full) prints pct create" \
        "pct create" "$output"
    assert_contains "pct_create --dry-run (full) includes hostname" \
        '"fullapp"' "$output"
    assert_contains "pct_create --dry-run (full) includes rootfs size" \
        "--rootfs local-lvm:16" "$output"
    assert_contains "pct_create --dry-run (full) masks password" \
        "--password ***" "$output"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(pct_create --vmid 100 --template "$tmpl" 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for pct_create" \
        "pct create" "$output"
}

# ─── pct_delete --dry-run ─────────────────────────────────────────────────────

test_pct_delete_dry_run() {
    local output exit_code

    # Without flags
    output=$(pct_delete --vmid 100 --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "pct_delete --dry-run returns 0" 0 "$exit_code"
    assert_contains "pct_delete --dry-run prints pct destroy command" \
        "pct destroy" "$output"
    assert_contains "pct_delete --dry-run includes vmid" \
        "100" "$output"
    if echo "$output" | grep -qF -- "--force"; then
        echo "FAIL: pct_delete --dry-run omits --force without flag" >&2
        FAIL=$(( FAIL + 1 ))
    else
        echo "PASS: pct_delete --dry-run omits --force without flag"
        PASS=$(( PASS + 1 ))
    fi

    # With --force
    output=$(pct_delete --vmid 100 --force --dry-run 2>/dev/null)
    assert_contains "pct_delete --force --dry-run includes --force" \
        "--force" "$output"

    # With --purge
    output=$(pct_delete --vmid 100 --purge --dry-run 2>/dev/null)
    assert_contains "pct_delete --purge --dry-run includes --purge" \
        "--purge" "$output"

    # With both --force and --purge
    output=$(pct_delete --vmid 101 --force --purge --dry-run 2>/dev/null)
    assert_contains "pct_delete --force --purge --dry-run includes --force" \
        "--force" "$output"
    assert_contains "pct_delete --force --purge --dry-run includes --purge" \
        "--purge" "$output"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(pct_delete --vmid 100 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for pct_delete" \
        "pct destroy" "$output"
}

# ─── pct_start --dry-run ──────────────────────────────────────────────────────

test_pct_start_dry_run() {
    local output exit_code

    output=$(pct_start --vmid 100 --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "pct_start --dry-run returns 0" 0 "$exit_code"
    assert_contains "pct_start --dry-run prints pct start command" \
        "pct start 100" "$output"

    output=$(pct_start --vmid 200 --dry-run 2>/dev/null)
    assert_contains "pct_start --dry-run includes correct vmid" \
        "pct start 200" "$output"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(pct_start --vmid 100 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for pct_start" \
        "pct start 100" "$output"
}

# ─── pct_exec --dry-run ───────────────────────────────────────────────────────

test_pct_exec_dry_run() {
    local output exit_code

    # Simple command
    output=$(pct_exec --vmid 100 --dry-run -- systemctl restart nginx 2>/dev/null)
    exit_code=$?
    assert_exit_code "pct_exec --dry-run returns 0" 0 "$exit_code"
    assert_contains "pct_exec --dry-run prints pct exec command" \
        "pct exec 100" "$output"
    assert_contains "pct_exec --dry-run includes -- separator" \
        " -- " "$output"
    assert_contains "pct_exec --dry-run includes the command" \
        "systemctl restart nginx" "$output"

    # Multi-word bash invocation
    output=$(pct_exec --vmid 101 --dry-run -- bash -c "apt-get update" 2>/dev/null)
    assert_contains "pct_exec --dry-run includes bash -c" \
        "bash" "$output"
    assert_contains "pct_exec --dry-run includes shell command text" \
        "apt-get update" "$output"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(pct_exec --vmid 100 -- echo hello 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for pct_exec" \
        "pct exec 100" "$output"
}

# ─── pct_enter --dry-run ──────────────────────────────────────────────────────

test_pct_enter_dry_run() {
    local output exit_code

    # Default: root user → should print pct enter (not pct exec with su)
    output=$(pct_enter --vmid 100 --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "pct_enter --dry-run returns 0" 0 "$exit_code"
    assert_contains "pct_enter --dry-run prints conditional pct start" \
        "pct start 100 (if not running)" "$output"
    assert_contains "pct_enter --dry-run (root) prints pct enter" \
        "pct enter 100" "$output"
    # For root, should NOT use pct exec with su
    if echo "$output" | grep -qF -- "su -l"; then
        echo "FAIL: pct_enter --dry-run (root) uses pct enter, not su" >&2
        FAIL=$(( FAIL + 1 ))
    else
        echo "PASS: pct_enter --dry-run (root) uses pct enter, not su"
        PASS=$(( PASS + 1 ))
    fi

    # Non-root user → should print pct exec with su
    output=$(pct_enter --vmid 101 --user deploy --dry-run 2>/dev/null)
    assert_contains "pct_enter --dry-run (non-root) prints pct exec with su" \
        "pct exec 101" "$output"
    assert_contains "pct_enter --dry-run (non-root) includes su -l" \
        "su -l" "$output"
    assert_contains "pct_enter --dry-run (non-root) includes username" \
        '"deploy"' "$output"
    assert_contains "pct_enter --dry-run (non-root) includes default shell" \
        '"/bin/bash"' "$output"

    # Non-root with custom shell
    output=$(pct_enter --vmid 102 --user app --shell /bin/sh --dry-run 2>/dev/null)
    assert_contains "pct_enter --dry-run (custom shell) includes /bin/sh" \
        '"/bin/sh"' "$output"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(pct_enter --vmid 100 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for pct_enter" \
        "pct start 100 (if not running)" "$output"
}

# ─── pct_config --dry-run ─────────────────────────────────────────────────────

test_pct_config_dry_run() {
    local output exit_code

    # Pass flags through to pct set
    output=$(pct_config --vmid 100 --memory 2048 --cores 4 --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "pct_config --dry-run returns 0" 0 "$exit_code"
    assert_contains "pct_config --dry-run prints pct set command" \
        "pct set 100" "$output"
    assert_contains "pct_config --dry-run passes --memory through" \
        "--memory 2048" "$output"
    assert_contains "pct_config --dry-run passes --cores through" \
        "--cores 4" "$output"

    # Hostname passthrough
    output=$(pct_config --vmid 101 --hostname newname --dry-run 2>/dev/null)
    assert_contains "pct_config --dry-run passes --hostname through" \
        "--hostname newname" "$output"

    # Multiple combined flags
    output=$(pct_config --vmid 102 --memory 1024 --cores 2 --hostname myapp --dry-run 2>/dev/null)
    assert_contains "pct_config --dry-run (combined) passes --memory" \
        "--memory 1024" "$output"
    assert_contains "pct_config --dry-run (combined) passes --cores" \
        "--cores 2" "$output"
    assert_contains "pct_config --dry-run (combined) passes --hostname" \
        "--hostname myapp" "$output"

    # No settings: returns 0 with a warn (no output to assert, just exit code)
    pct_config --vmid 100 --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "pct_config --dry-run with no settings returns 0" 0 "$exit_code"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(pct_config --vmid 100 --memory 512 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for pct_config" \
        "pct set 100" "$output"
}

# ─── pct_network --dry-run ────────────────────────────────────────────────────

test_pct_network_dry_run() {
    local output exit_code

    # Default: bridge=vmbr0, index=0, no IP
    output=$(pct_network --vmid 100 --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "pct_network --dry-run returns 0" 0 "$exit_code"
    assert_contains "pct_network --dry-run prints pct set command" \
        "pct set 100" "$output"
    assert_contains "pct_network --dry-run includes --net0" \
        "--net0" "$output"
    assert_contains "pct_network --dry-run includes default bridge" \
        "bridge=vmbr0" "$output"
    assert_contains "pct_network --dry-run includes default interface name" \
        "name=eth0" "$output"

    # With static IP and gateway
    output=$(pct_network --vmid 100 --ip 192.168.1.100/24 --gateway 192.168.1.1 --dry-run 2>/dev/null)
    assert_contains "pct_network --dry-run includes ip" \
        "ip=192.168.1.100/24" "$output"
    assert_contains "pct_network --dry-run includes gateway" \
        "gw=192.168.1.1" "$output"

    # DHCP: no gateway even if provided
    output=$(pct_network --vmid 100 --ip dhcp --gateway 10.0.0.1 --dry-run 2>/dev/null)
    assert_contains "pct_network --dry-run (dhcp) includes ip=dhcp" \
        "ip=dhcp" "$output"
    if echo "$output" | grep -qF -- "gw="; then
        echo "FAIL: pct_network --dry-run (dhcp) omits gateway for DHCP" >&2
        FAIL=$(( FAIL + 1 ))
    else
        echo "PASS: pct_network --dry-run (dhcp) omits gateway for DHCP"
        PASS=$(( PASS + 1 ))
    fi

    # Custom bridge and interface index
    output=$(pct_network --vmid 101 --bridge vmbr1 --index 1 --dry-run 2>/dev/null)
    assert_contains "pct_network --dry-run uses custom bridge" \
        "bridge=vmbr1" "$output"
    assert_contains "pct_network --dry-run uses custom index in flag" \
        "--net1" "$output"
    assert_contains "pct_network --dry-run uses custom index in interface name" \
        "name=eth1" "$output"

    # With DNS nameserver
    output=$(pct_network --vmid 100 --ip 10.0.0.5/24 --dns "8.8.8.8 8.8.4.4" --dry-run 2>/dev/null)
    assert_contains "pct_network --dry-run prints nameserver command" \
        "--nameserver" "$output"
    assert_contains "pct_network --dry-run includes DNS values" \
        "8.8.8.8 8.8.4.4" "$output"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(pct_network --vmid 100 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for pct_network" \
        "pct set 100" "$output"
}

# ─── pct_pull --dry-run ───────────────────────────────────────────────────────

test_pct_pull_dry_run() {
    local output exit_code

    output=$(pct_pull /etc/myapp.conf /tmp/myapp.conf --vmid 100 --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "pct_pull --dry-run returns 0" 0 "$exit_code"
    assert_contains "pct_pull --dry-run prints pct pull command" \
        "pct pull 100" "$output"
    assert_contains "pct_pull --dry-run includes source path" \
        '"/etc/myapp.conf"' "$output"
    assert_contains "pct_pull --dry-run includes destination path" \
        '"/tmp/myapp.conf"' "$output"

    # Different vmid and paths
    output=$(pct_pull /var/log/app.log /tmp/app.log --vmid 200 --dry-run 2>/dev/null)
    assert_contains "pct_pull --dry-run uses correct vmid" \
        "pct pull 200" "$output"
    assert_contains "pct_pull --dry-run includes log source path" \
        '"/var/log/app.log"' "$output"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(pct_pull /etc/hosts /tmp/hosts --vmid 100 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for pct_pull" \
        "pct pull 100" "$output"
}

# ─── pct_push --dry-run ───────────────────────────────────────────────────────

test_pct_push_dry_run() {
    local output exit_code

    # Minimal
    output=$(pct_push /tmp/myapp.conf /etc/myapp.conf --vmid 100 --dry-run 2>/dev/null)
    exit_code=$?
    assert_exit_code "pct_push --dry-run returns 0" 0 "$exit_code"
    assert_contains "pct_push --dry-run prints pct push command" \
        "pct push 100" "$output"
    assert_contains "pct_push --dry-run includes source path" \
        '"/tmp/myapp.conf"' "$output"
    assert_contains "pct_push --dry-run includes destination path" \
        '"/etc/myapp.conf"' "$output"

    # With --perms
    output=$(pct_push /tmp/myapp.conf /etc/myapp.conf --vmid 100 --perms 0644 --dry-run 2>/dev/null)
    assert_contains "pct_push --dry-run includes --perms flag" \
        "--perms 0644" "$output"

    # With --user and --group
    output=$(pct_push /tmp/myapp.conf /etc/myapp.conf --vmid 100 \
        --user root --group www-data --dry-run 2>/dev/null)
    assert_contains "pct_push --dry-run includes --user flag" \
        "--user root" "$output"
    assert_contains "pct_push --dry-run includes --group flag" \
        "--group www-data" "$output"

    # All optional flags together
    output=$(pct_push /tmp/config.json /opt/app/config.json --vmid 101 \
        --perms 0640 --user deploy --group deploy --dry-run 2>/dev/null)
    assert_contains "pct_push --dry-run (full) includes perms" \
        "--perms 0640" "$output"
    assert_contains "pct_push --dry-run (full) includes user" \
        "--user deploy" "$output"
    assert_contains "pct_push --dry-run (full) includes group" \
        "--group deploy" "$output"

    # Global IS_DRY_RUN=true
    IS_DRY_RUN=true
    output=$(pct_push /tmp/hosts /etc/hosts --vmid 100 2>/dev/null)
    IS_DRY_RUN=false
    assert_contains "IS_DRY_RUN=true enables dry-run for pct_push" \
        "pct push 100" "$output"
}

# ─── Container error cases ────────────────────────────────────────────────────

test_container_error_cases() {
    local exit_code

    # lxc_create: requires --name
    lxc_create --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "lxc_create --dry-run fails with no name" 1 "$exit_code"

    # lxc_delete: requires --name
    lxc_delete --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "lxc_delete --dry-run fails with no name" 1 "$exit_code"

    # lxc_start: requires --name
    lxc_start --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "lxc_start --dry-run fails with no name" 1 "$exit_code"

    # lxc_exec: requires --name
    lxc_exec --dry-run -- echo hello &>/dev/null; exit_code=$?
    assert_exit_code "lxc_exec --dry-run fails with no name" 1 "$exit_code"

    # lxc_exec: requires a command after --
    lxc_exec --name myct --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "lxc_exec --dry-run fails with no command" 1 "$exit_code"

    # lxc_enter: requires --name
    lxc_enter --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "lxc_enter --dry-run fails with no name" 1 "$exit_code"

    # lxc_network: requires --name
    lxc_network --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "lxc_network --dry-run fails with no name" 1 "$exit_code"

    # lxc_network: rejects invalid --type
    lxc_network --name myct --type invalid --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "lxc_network --dry-run fails with invalid type" 1 "$exit_code"

    # lxc_pull: requires source, dest, and --name
    lxc_pull /etc/hosts --name myct --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "lxc_pull --dry-run fails with missing dest" 1 "$exit_code"

    lxc_pull /etc/hosts /tmp/hosts --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "lxc_pull --dry-run fails with no --name" 1 "$exit_code"

    # lxc_push: requires source, dest, and --name
    lxc_push /tmp/hosts --name myct --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "lxc_push --dry-run fails with missing dest" 1 "$exit_code"

    lxc_push /tmp/hosts /etc/hosts --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "lxc_push --dry-run fails with no --name" 1 "$exit_code"

    # pct_create: requires --vmid
    pct_create --template "local:vztmpl/test.tar.zst" --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "pct_create --dry-run fails with no vmid" 1 "$exit_code"

    # pct_create: requires --template
    pct_create --vmid 100 --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "pct_create --dry-run fails with no template" 1 "$exit_code"

    # pct_delete: requires --vmid
    pct_delete --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "pct_delete --dry-run fails with no vmid" 1 "$exit_code"

    # pct_start: requires --vmid
    pct_start --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "pct_start --dry-run fails with no vmid" 1 "$exit_code"

    # pct_exec: requires --vmid
    pct_exec --dry-run -- echo hello &>/dev/null; exit_code=$?
    assert_exit_code "pct_exec --dry-run fails with no vmid" 1 "$exit_code"

    # pct_exec: requires a command after --
    pct_exec --vmid 100 --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "pct_exec --dry-run fails with no command" 1 "$exit_code"

    # pct_enter: requires --vmid
    pct_enter --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "pct_enter --dry-run fails with no vmid" 1 "$exit_code"

    # pct_network: requires --vmid
    pct_network --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "pct_network --dry-run fails with no vmid" 1 "$exit_code"

    # pct_pull: requires source, dest, and --vmid
    pct_pull /etc/hosts --vmid 100 --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "pct_pull --dry-run fails with missing dest" 1 "$exit_code"

    pct_pull /etc/hosts /tmp/hosts --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "pct_pull --dry-run fails with no --vmid" 1 "$exit_code"

    # pct_push: requires source, dest, and --vmid
    pct_push /tmp/hosts --vmid 100 --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "pct_push --dry-run fails with missing dest" 1 "$exit_code"

    pct_push /tmp/hosts /etc/hosts --dry-run &>/dev/null; exit_code=$?
    assert_exit_code "pct_push --dry-run fails with no --vmid" 1 "$exit_code"
}

# ─── Run all tests ────────────────────────────────────────────────────────────

echo "=== LXC Container Dry Run Tests ==="
echo ""

test_lxc_create_dry_run
echo ""

test_lxc_delete_dry_run
echo ""

test_lxc_start_dry_run
echo ""

test_lxc_exec_dry_run
echo ""

test_lxc_enter_dry_run
echo ""

test_lxc_config_dry_run
echo ""

test_lxc_network_dry_run
echo ""

test_lxc_pull_dry_run
echo ""

test_lxc_push_dry_run
echo ""

echo "=== PCT Container Dry Run Tests ==="
echo ""

test_pct_create_dry_run
echo ""

test_pct_delete_dry_run
echo ""

test_pct_start_dry_run
echo ""

test_pct_exec_dry_run
echo ""

test_pct_enter_dry_run
echo ""

test_pct_config_dry_run
echo ""

test_pct_network_dry_run
echo ""

test_pct_pull_dry_run
echo ""

test_pct_push_dry_run
echo ""

echo "=== Container Error Cases ==="
echo ""

test_container_error_cases
echo ""

echo "Results: $PASS passed, $FAIL failed"
if (( FAIL > 0 )); then
    exit 1
fi
exit 0
