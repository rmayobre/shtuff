#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/../shtuff.sh"

FAILED=0
VERBOSE_FILE=$(mktemp)

assert_eq() {
    if [[ "$2" != "$3" ]]; then
        echo "Test FAILED: $1 (expected '$3', got '$2')" >&2
        FAILED=1
    fi
}

assert_fails() {
    if "${@:2}" &>/dev/null; then
        echo "Test FAILED: $1 (expected non-zero exit)" >&2
        FAILED=1
    fi
}

resolve_as() {
    TEST_MANAGER="$1"
    _group_manager() { echo "$TEST_MANAGER"; }
    _group_resolve "$2" || return 1
    echo "${_GROUP_RESOLVED[*]}"
}

group --name web \
    --package nginx \
    --package apache2 --dnf httpd --pacman apache \
    --package ufw --dnf none --yum none

assert_eq "apt uses default names"    "$(resolve_as apt web)"    "nginx apache2 ufw"
assert_eq "dnf override and none"     "$(resolve_as dnf web)"    "nginx httpd"
assert_eq "yum falls back to dnf"     "$(resolve_as yum web)"    "nginx httpd"
assert_eq "pacman override"           "$(resolve_as pacman web)" "nginx apache ufw"

group --name web --remove ufw --package apache2 --apk apache2-bin
assert_eq "merge replaces member"     "$(resolve_as apk web)"    "nginx apache2-bin"
assert_eq "remove drops member"       "$(resolve_as apt web)"    "nginx apache2"

assert_fails "manager flag before package" group --name x --dnf httpd
assert_fails "missing name"                group --package nginx
assert_fails "bad package name"            group --name x --package 'a b'
assert_fails "duplicate manager flag"      group --name x --package a --dnf b --dnf c
assert_fails "unknown group"               _group_resolve nope

# install / uninstall / dependencies wiring (package manager calls stubbed)
LOG=$(mktemp)
_group_manager() { echo apt; }
_install_apt()   { sleep 0.3; [[ " $* " == *" badpkg "* ]] && return 1; echo "install $*" >> "$LOG"; }
_uninstall_apt() { sleep 0.3; echo "uninstall $*" >> "$LOG"; }
update()         { :; }
command() { [[ "$1" == "-v" && "$2" == "apt" ]] && return 0; builtin command "$@"; }

group --name a --package curl --package git
group --name b --package git --package vim

install --group a >/dev/null 2>&1
assert_eq "install --group"     "$(tail -1 "$LOG")" "install curl git"

dependencies --group b >/dev/null 2>&1
assert_eq "dependencies --group" "$(tail -1 "$LOG")" "install vim"

# install returns distinct codes
install badpkg >/dev/null 2>&1
assert_eq "install failure code"      "$?" "4"
install --group missing >/dev/null 2>&1
assert_eq "install unknown group code" "$?" "2"
install >/dev/null 2>&1
assert_eq "install usage code"        "$?" "1"

# dependencies stops at the first failure and returns install's code
before=$(wc -l < "$LOG")
dependencies okpkg badpkg lastpkg >/dev/null 2>&1
assert_eq "dependencies returns install code" "$?" "4"
assert_eq "dependencies stops at first failure" "$(tail -1 "$LOG")" "install okpkg"
assert_eq "dependencies skips remaining packages" "$(( $(wc -l < "$LOG") - before ))" "1"

if ! dependencies --skip-failures badpkg lastpkg >/dev/null 2>&1; then
    echo "Test FAILED: dependencies --skip-failures should return 0" >&2
    FAILED=1
fi
assert_eq "dependencies --skip-failures continues" "$(tail -1 "$LOG")" "install lastpkg"

update() { return 1; }
assert_fails "dependencies fails when update fails" dependencies okpkg
if ! dependencies --skip-failures okpkg >/dev/null 2>&1; then
    echo "Test FAILED: dependencies --skip-failures should ignore update failure" >&2
    FAILED=1
fi
unset -f update

uninstall --group a >/dev/null
assert_eq "uninstall keeps shared" "$(tail -1 "$LOG")" "uninstall curl"
assert_fails "group discarded after uninstall" _group_resolve a

uninstall --group b >/dev/null
assert_eq "uninstall releases shared" "$(tail -1 "$LOG")" "uninstall git vim"

group --name c --package git --package vim
group --name d --package git
uninstall --group c --force >/dev/null
assert_eq "uninstall --force" "$(tail -1 "$LOG")" "uninstall git vim"

assert_fails "install unknown group" install --group missing

rm -f "$LOG" "$VERBOSE_FILE"
if [[ $FAILED -eq 0 ]]; then
    echo "Group Functions - Passed!"
else
    exit 1
fi
