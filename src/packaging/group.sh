#!/usr/bin/env bash

# Registry of dependency groups, kept in memory for the lifetime of the shell.
# Each value holds one member per line in the form:
#   <default-name>|<manager>=<name>|<manager>=<name>
# where <name> may be "none" to mean the package does not exist on that manager.
declare -gA SHTUFF_GROUPS

# Packages produced by the most recent _group_resolve / _group_resolve_others call.
declare -ga _GROUP_RESOLVED=()

# Function: group
# Description: Defines (or amends) a named group of packages held in memory. Each member has a
#              default package name and optional per-package-manager overrides, so one group
#              works across apt, dnf, yum, zypper, pacman, and apk. Groups are consumed with
#              the --group option of install, uninstall, and dependencies. This function only
#              records the definition; it never installs or removes anything.
#
#              Manager flags apply to the most recent --package. Calling group again with an
#              existing name merges into it; a --package whose default name is already a
#              member replaces that member. --remove entries are applied before additions.
#
# Arguments:
#   --name NAME (string, required): Name of the group to create or amend.
#   --package PKG (string, repeatable): Adds a member. PKG is the default package name used on
#        any manager without an override.
#   --apt NAME (string, optional): Package name to use on apt for the preceding --package.
#   --dnf NAME (string, optional): Package name to use on dnf for the preceding --package.
#   --yum NAME (string, optional): Package name to use on yum. Falls back to the --dnf name.
#   --zypper NAME (string, optional): Package name to use on zypper.
#   --pacman NAME (string, optional): Package name to use on pacman.
#   --apk NAME (string, optional): Package name to use on apk.
#        For any manager flag, NAME may be "none" to skip the package on that manager.
#   --remove PKG (string, repeatable, optional): Removes the member whose default name is PKG.
#
# Globals:
#   SHTUFF_GROUPS (write): Associative array of group name to member definitions.
#
# Returns:
#   0 - Group defined or amended.
#   1 - Missing or invalid arguments (nothing is modified).
#
# Examples:
#   group --name webserver \
#       --package nginx \
#       --package apache2 --dnf httpd --yum httpd --pacman apache \
#       --package ufw --dnf none --yum none
#   group --name webserver --remove ufw
group() {
    local name=""
    local cur=""
    local -a adds=()
    local -a removes=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name|-p|--package|-r|--remove|--apt|--dnf|--yum|--zypper|--pacman|--apk)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    error "group: $1 requires a value"
                    return 1
                fi
                ;;&
            -n|--name)
                if [[ ! "$2" =~ ^[A-Za-z0-9._-]+$ ]]; then
                    error "group: invalid group name: $2"
                    return 1
                fi
                name="$2"
                shift 2
                ;;
            -p|--package)
                if [[ ! "$2" =~ ^[A-Za-z0-9@._+:-]+$ ]]; then
                    error "group: invalid package name: $2"
                    return 1
                fi
                [[ -n "$cur" ]] && adds+=("$cur")
                cur="$2"
                shift 2
                ;;
            -r|--remove)
                if [[ ! "$2" =~ ^[A-Za-z0-9@._+:-]+$ ]]; then
                    error "group: invalid package name: $2"
                    return 1
                fi
                removes+=("$2")
                shift 2
                ;;
            --apt|--dnf|--yum|--zypper|--pacman|--apk)
                local mgr="${1#--}"
                if [[ -z "$cur" ]]; then
                    error "group: $1 must follow a --package"
                    return 1
                fi
                if [[ ! "$2" =~ ^[A-Za-z0-9@._+:-]+$ ]]; then
                    error "group: invalid package name for $mgr: $2"
                    return 1
                fi
                if [[ "$cur" == *"|${mgr}="* ]]; then
                    error "group: $1 given twice for the same --package"
                    return 1
                fi
                cur+="|${mgr}=$2"
                shift 2
                ;;
            *)
                error "group: unknown option: $1"
                return 1
                ;;
        esac
    done
    [[ -n "$cur" ]] && adds+=("$cur")

    if [[ -z "$name" ]]; then
        error "Usage: group --name NAME [--package PKG [--apt N] [--dnf N] ...]... [--remove PKG]..."
        return 1
    fi
    if [[ ${#adds[@]} -eq 0 && ${#removes[@]} -eq 0 ]]; then
        error "group: nothing to do; give at least one --package or --remove"
        return 1
    fi

    local entry
    for entry in "${removes[@]}"; do
        _group_remove_member "$name" "$entry"
    done
    for entry in "${adds[@]}"; do
        _group_set_member "$name" "$entry"
    done
    debug "Group '$name' now has: $(tr '\n' ' ' <<< "${SHTUFF_GROUPS[$name]}")"
    return 0
}

# Function: _group_remove_member
# Description: Removes the member with the given default name from a group.
#
# Arguments:
#   $1 - group (string, required): Group name.
#   $2 - package (string, required): Default package name of the member to remove.
#
# Globals:
#   SHTUFF_GROUPS (write): Group definitions.
#
# Returns:
#   0 - Always.
#
# Examples:
#   _group_remove_member webserver ufw
_group_remove_member() {
    local name="$1" pkg="$2" line out=""
    while IFS= read -r line; do
        [[ -z "$line" || "${line%%|*}" == "$pkg" ]] && continue
        out+="${line}"$'\n'
    done <<< "${SHTUFF_GROUPS[$name]-}"
    SHTUFF_GROUPS[$name]="$out"
}

# Function: _group_set_member
# Description: Adds a member line to a group, replacing any member with the same default name.
#
# Arguments:
#   $1 - group (string, required): Group name.
#   $2 - member (string, required): Member line, e.g. "apache2|dnf=httpd".
#
# Globals:
#   SHTUFF_GROUPS (write): Group definitions.
#
# Returns:
#   0 - Always.
#
# Examples:
#   _group_set_member webserver "apache2|dnf=httpd"
_group_set_member() {
    _group_remove_member "$1" "${2%%|*}"
    SHTUFF_GROUPS[$1]+="$2"$'\n'
}

# Function: _group_manager
# Description: Prints the name of the first supported package manager found on the system,
#              using the same precedence as install and uninstall.
#
# Returns:
#   0 - Manager name printed to stdout.
#   1 - No supported package manager found.
#
# Examples:
#   mgr=$(_group_manager)
_group_manager() {
    local mgr
    for mgr in apt dnf yum zypper pacman apk; do
        if command -v "$mgr" &> /dev/null; then
            echo "$mgr"
            return 0
        fi
    done
    error "Could not determine the primary package manager."
    return 1
}

# Function: _group_resolve
# Description: Resolves a group to the package names for the detected package manager.
#              Overrides win over the default name, yum falls back to the dnf override, and
#              members overridden with "none" are skipped. The result is stored in
#              _GROUP_RESOLVED.
#
# Arguments:
#   $1 - group (string, required): Group name.
#
# Globals:
#   SHTUFF_GROUPS (read): Group definitions.
#   _GROUP_RESOLVED (write): Resolved package names.
#
# Returns:
#   0 - Resolved (the result may be empty if every member is "none").
#   2 - Invalid or undefined group.
#   3 - No supported package manager.
#
# Examples:
#   _group_resolve webserver && install "${_GROUP_RESOLVED[@]}"
_group_resolve() {
    local name="$1" mgr line f key val pkg found dnf_name
    _GROUP_RESOLVED=()

    if [[ ! "$name" =~ ^[A-Za-z0-9._-]+$ ]]; then
        error "Invalid group name: $name"
        return 2
    fi
    if [[ -z "${SHTUFF_GROUPS[$name]+x}" ]]; then
        error "Unknown group: $name (define it with 'group --name $name ...')"
        return 2
    fi
    mgr=$(_group_manager) || return 3

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local -a fields=()
        IFS='|' read -ra fields <<< "$line"
        pkg="${fields[0]}"
        found=false
        dnf_name=""
        for f in "${fields[@]:1}"; do
            key="${f%%=*}"
            val="${f#*=}"
            if [[ "$key" == "$mgr" ]]; then
                pkg="$val"
                found=true
            elif [[ "$key" == "dnf" ]]; then
                dnf_name="$val"
            fi
        done
        if [[ "$found" == false && "$mgr" == "yum" && -n "$dnf_name" ]]; then
            pkg="$dnf_name"
        fi
        if [[ "$pkg" == "none" ]]; then
            debug "Group '$name': '${fields[0]}' is not available on $mgr, skipping"
            continue
        fi
        _GROUP_RESOLVED+=("$pkg")
    done <<< "${SHTUFF_GROUPS[$name]}"
    debug "Group '$name' on $mgr: ${_GROUP_RESOLVED[*]}"
    return 0
}

# Function: _group_resolve_others
# Description: Resolves every defined group except the ones named, collecting all of their
#              packages for the detected package manager into _GROUP_RESOLVED.
#
# Arguments:
#   $@ - groups (string, optional): Group names to leave out.
#
# Globals:
#   SHTUFF_GROUPS (read): Group definitions.
#   _GROUP_RESOLVED (write): Resolved package names.
#
# Returns:
#   0 - Resolved.
#   2 - A group failed to resolve (invalid or undefined).
#   3 - No supported package manager.
#
# Examples:
#   _group_resolve_others webserver
_group_resolve_others() {
    local -a all=()
    local g skip s
    for g in "${!SHTUFF_GROUPS[@]}"; do
        skip=false
        for s in "$@"; do
            [[ "$s" == "$g" ]] && skip=true
        done
        [[ "$skip" == false ]] || continue
        _group_resolve "$g" || return $?
        all+=("${_GROUP_RESOLVED[@]}")
    done
    _GROUP_RESOLVED=("${all[@]}")
}
