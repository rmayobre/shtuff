#!/usr/bin/env bash
# Tests monitor in command mode and PID mode under every installed interpreter
# (bash, zsh, busybox ash, dash). Runs without a terminal, so the animation itself
# is not exercised; it checks capture, status messages and exit codes.
#
#   bash tests/monitor_test.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0

# The script every interpreter runs. It prints one "key=value" line per check.
read -r -d '' CHECKS <<'EOS'
. "$SHTUFF_DIR/shtuff-core.sh" 2>/dev/null
LOG_TIMESTAMP=false
VERBOSE_FILE="$(mktemp)"
export VERBOSE_FILE

out=$(monitor --success_msg "ok-msg" -- sh -c 'echo CAPTURED; echo ERR >&2' 2>&1); rc=$?
echo "success_rc=$rc"
case "$out" in *ok-msg*) echo "success_msg=yes" ;; *) echo "success_msg=no" ;; esac
case "$out" in *CAPTURED*) echo "hidden=no" ;; *) echo "hidden=yes" ;; esac
grep -q CAPTURED "$VERBOSE_FILE" && echo "captured=yes" || echo "captured=no"

out=$(monitor --error_msg "fail-msg" -- sh -c 'exit 7' 2>&1); rc=$?
echo "fail_rc=$rc"
case "$out" in *fail-msg*) echo "fail_msg=yes" ;; *) echo "fail_msg=no" ;; esac

sleep 0.2 &
monitor $! --success_msg "pid-ok" >/dev/null 2>&1; echo "pid_rc=$?"

monitor --style nope -- true >/dev/null 2>&1; echo "badstyle_rc=$?"
monitor >/dev/null 2>&1; echo "noargs_rc=$?"
monitor abc >/dev/null 2>&1; echo "badpid_rc=$?"
rm -f "$VERBOSE_FILE"
EOS

expected="success_rc=0
success_msg=yes
hidden=yes
captured=yes
fail_rc=7
fail_msg=yes
pid_rc=0
badstyle_rc=1
noargs_rc=1
badpid_rc=1"

for shell in bash zsh "busybox ash" dash; do
    set -- $shell
    command -v "$1" >/dev/null 2>&1 || { echo "SKIP  $shell (not installed)"; continue; }
    actual=$(SHTUFF_DIR="$ROOT" $shell -c "$CHECKS" 2>/dev/null)
    if [[ "$actual" == "$expected" ]]; then
        echo "PASS  $shell"
    else
        echo "FAIL  $shell"
        diff <(echo "$expected") <(echo "$actual") | sed 's/^/        /'
        failures=$((failures + 1))
    fi
done

if (( failures > 0 )); then
    echo "monitor tests FAILED ($failures)"
    exit 1
fi
echo "monitor tests passed"
