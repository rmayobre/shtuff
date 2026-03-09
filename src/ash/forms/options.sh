#!/bin/sh

# Function: options
# Description: Displays a numbered list of choices, prompts the user to pick
#              one by number, and stores the selected value in the global
#              variable 'answer'. Uses whiptail if available for a graphical
#              menu; falls back to a plain terminal prompt.
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
options() {
    local prompt="$1"
    shift

    if [ -z "$prompt" ]; then
        error "options: prompt argument is required"
        return 1
    fi

    local _count=0

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --choice)
                if [ -z "$2" ]; then
                    error "options: --choice requires a value"
                    return 1
                fi
                _count=$(( _count + 1 ))
                eval "_choice_${_count}=\$2"
                shift 2
                ;;
            *)
                error "options: unknown argument: $1"
                return 1
                ;;
        esac
    done

    if [ "$_count" -eq 0 ]; then
        error "options: at least one --choice is required"
        return 1
    fi

    local _selection

    if command -v whiptail >/dev/null 2>&1; then
        local _height=$(( _count + 7 ))
        # Build menu items as positional parameters for whiptail
        set --
        local _i=1
        while [ "$_i" -le "$_count" ]; do
            eval "_cv=\$_choice_${_i}"
            set -- "$@" "$_i" "$_cv"
            _i=$(( _i + 1 ))
        done
        while true; do
            _selection=$(whiptail --menu "$prompt" "$_height" 60 "$_count" "$@" 3>&1 1>&2 2>&3)
            if [ $? -eq 0 ] && [ -n "$_selection" ]; then
                break
            fi
        done
    else
        printf "%s\n" "$prompt"
        local _i=1
        while [ "$_i" -le "$_count" ]; do
            eval "_cv=\$_choice_${_i}"
            printf "  %d) %s\n" "$_i" "$_cv"
            _i=$(( _i + 1 ))
        done
        while true; do
            printf "Enter number [1-%d]: " "$_count"
            read -r _selection
            case "$_selection" in
                ''|*[!0-9]*)
                    warn "Please enter a number between 1 and ${_count}."
                    continue
                    ;;
            esac
            if [ "$_selection" -ge 1 ] && [ "$_selection" -le "$_count" ]; then
                break
            fi
            warn "Please enter a number between 1 and ${_count}."
        done
    fi

    eval "answer=\$_choice_${_selection}"
}
