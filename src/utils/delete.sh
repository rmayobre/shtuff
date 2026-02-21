#!/usr/bin/env bash

# Function: delete
# Description: Removes one or more files or directories, displaying a progress bar
#              that advances once per target item. Each item is removed with the
#              standard rm command; pass --recursive to remove directories (rm -r).
#
# Visual Output:
#   Deleting four of five items:
#
#     Deleting [████████████████████████████████░░░░░░░░]  80% (4/5)
#
#   All five items deleted:
#
#     Deleting [████████████████████████████████████████] 100% (5/5)
#
# Arguments:
#   --recursive   (flag, optional): Remove directories and their contents (rm -r).
#   --message MSG (string, optional, default: "Deleting"): Label shown on the progress bar.
#   --            (separator, optional): Treat all subsequent arguments as target paths,
#                 even if they begin with a hyphen.
#   TARGET...     (string, required): One or more paths to remove.
#                 May be listed before or after named flags.
#
# Globals:
#   GREEN       (read): ANSI color applied to the filled portion of the progress bar.
#   RESET_COLOR (read): ANSI reset sequence used to restore terminal color.
#
# Returns:
#   0 - All items removed successfully.
#   1 - No targets provided or rm failed for any item.
#
# Examples:
#   # Delete three temporary files
#   delete /tmp/myapp.zip /tmp/myapp.tar.gz /tmp/patch.diff
#
#   # Recursively delete build and cache directories
#   delete --recursive build/ .cache/ dist/
#
#   # Custom progress label
#   delete --message "Cleaning up" --recursive /tmp/myapp_extract /tmp/myapp_staging
function delete {
    local recursive=false
    local message="Deleting"
    local -a targets=()

    while (( "$#" )); do
        case "$1" in
            -r|--recursive)
                recursive=true
                shift
                ;;
            -m|--message)
                message="$2"
                shift 2
                ;;
            --)
                shift
                targets+=("$@")
                break
                ;;
            -*)
                error "delete: unknown option: $1"
                return 1
                ;;
            *)
                targets+=("$1")
                shift
                ;;
        esac
    done

    if (( ${#targets[@]} == 0 )); then
        error "delete: at least one target path is required"
        return 1
    fi

    local total=${#targets[@]}
    local rm_flags=()
    [[ "$recursive" == true ]] && rm_flags+=("-r")

    for (( i = 0; i < total; i++ )); do
        local target="${targets[$i]}"
        if ! rm "${rm_flags[@]}" "$target"; then
            error "delete: failed to remove '$target'"
            return 1
        fi
        progress --current $(( i + 1 )) --total "$total" --message "$message"
    done
}
