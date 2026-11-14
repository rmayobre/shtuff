#!/usr/bin/env bash

# Function: selections
# Description: Displays a numbered list of choices, prompts the user to pick
#              one or more by number, and stores the selected values in the
#              global array 'answers'. Uses whiptail if available for a
#              graphical checklist; falls back to a plain terminal prompt.
#
# Arguments:
#   $1 - prompt (string, required): The question text displayed above the list.
#   --choice VALUE (string, required, repeatable): A choice to add to the list.
#                  May be specified multiple times; order is preserved.
#
# Globals:
#   answers (write): Set to an array of the choices the user selected, in the
#            order they were originally listed.
#
# Returns:
#   0 - One or more valid selections were made.
#   1 - Missing or invalid arguments (no prompt, unknown flag, no choices).
#
# Examples:
#   selections "Which packages would you like to install?" \
#       --choice "nodejs" \
#       --choice "curl" \
#       --choice "unzip"
#   printf 'You chose: %s\n' "${answers[@]}"
#
#   selections "Select environments to deploy to:" \
#       --choice "development" \
#       --choice "staging" \
#       --choice "production"
function selections {
    local prompt="$1"
    shift

    if [[ -z "$prompt" ]]; then
        error "selections: prompt argument is required"
        return 1
    fi

    local -a choices=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --choice)
                if [[ -z "$2" ]]; then
                    error "selections: --choice requires a value"
                    return 1
                fi
                choices+=("$2")
                shift 2
                ;;
            *)
                error "selections: unknown argument: $1"
                return 1
                ;;
        esac
    done

    if [[ ${#choices[@]} -eq 0 ]]; then
        error "selections: at least one --choice is required"
        return 1
    fi

    local i
    answers=()

    if command -v whiptail &>/dev/null; then
        local height=$(( ${#choices[@]} + 8 ))
        local list_height=${#choices[@]}
        local -a menu_items=()
        for (( i=0; i<${#choices[@]}; i++ )); do
            menu_items+=("$((i+1))" "${choices[$i]}" "OFF")
        done

        local raw
        while true; do
            raw=$(whiptail --checklist "$prompt" "$height" 60 "$list_height" \
                "${menu_items[@]}" 3>&1 1>&2 2>&3)
            if [[ $? -eq 0 && -n "$raw" ]]; then
                break
            fi
        done

        local -a tags=()
        eval "tags=($raw)"

        local tag
        for tag in "${tags[@]}"; do
            answers+=("${choices[$((tag-1))]}")
        done
    else
        printf "%s\n" "$prompt"
        for (( i=0; i<${#choices[@]}; i++ )); do
            printf "  %d) %s\n" "$((i+1))" "${choices[$i]}"
        done

        local input
        local -a tokens=()
        local token
        local valid
        while true; do
            read -r -p "Enter numbers [1-${#choices[@]}], separated by spaces or commas: " input
            tokens=(${input//,/ })

            if [[ ${#tokens[@]} -eq 0 ]]; then
                warn "Please enter at least one number between 1 and ${#choices[@]}."
                continue
            fi

            valid="true"
            for token in "${tokens[@]}"; do
                if ! [[ "$token" =~ ^[0-9]+$ ]] || \
                   (( token < 1 || token > ${#choices[@]} )); then
                    warn "Please enter only numbers between 1 and ${#choices[@]}."
                    valid="false"
                    break
                fi
            done

            [[ "$valid" == "true" ]] && break
        done

        for (( i=0; i<${#choices[@]}; i++ )); do
            for token in "${tokens[@]}"; do
                if (( token == i + 1 )); then
                    answers+=("${choices[$i]}")
                    break
                fi
            done
        done
    fi
}
