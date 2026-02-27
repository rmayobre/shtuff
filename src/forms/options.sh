#!/usr/bin/env bash

# Function: options
# Description: Displays a numbered list of choices, prompts the user to pick
#              one by number, and stores the selected value in the global
#              variable 'answer'.
#
# Arguments:
#   $1 - prompt (string, required): The question text displayed above the list.
#   --choice VALUE (string, required, repeatable): A choice to add to the list.
#                  May be specified multiple times; order is preserved.
#
# Globals:
#   answer (write): Set to the text of the choice the user selected.
#
# Returns:
#   0 - A valid selection was made.
#   1 - Missing or invalid arguments (no prompt, unknown flag, no choices).
#
# Examples:
#   options "What would you like to do?" \
#       --choice "Install" \
#       --choice "Update" \
#       --choice "Exit"
#   echo "You chose: $answer"
#
#   options "Select an environment:" \
#       --choice "development" \
#       --choice "staging" \
#       --choice "production"
function options {
    local prompt="$1"
    shift

    if [[ -z "$prompt" ]]; then
        error "options: prompt argument is required"
        return 1
    fi

    local -a choices=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --choice)
                if [[ -z "$2" ]]; then
                    error "options: --choice requires a value"
                    return 1
                fi
                choices+=("$2")
                shift 2
                ;;
            *)
                error "options: unknown argument: $1"
                return 1
                ;;
        esac
    done

    if [[ ${#choices[@]} -eq 0 ]]; then
        error "options: at least one --choice is required"
        return 1
    fi

    printf "%s\n" "$prompt"
    local i
    for (( i=0; i<${#choices[@]}; i++ )); do
        printf "  %d) %s\n" "$((i+1))" "${choices[$i]}"
    done

    local selection
    while true; do
        read -r -p "Enter number [1-${#choices[@]}]: " selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && \
           (( selection >= 1 && selection <= ${#choices[@]} )); then
            break
        fi
        warn "Please enter a number between 1 and ${#choices[@]}."
    done

    answer="${choices[$((selection-1))]}"
}
