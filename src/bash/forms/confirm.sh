#!/usr/bin/env bash

# Function: confirm
# Description: Prompts the user with a yes/no question, stores the result in
#              the global variable 'answer', and returns 0 for yes or 1 for no.
#              Uses whiptail if available for a graphical dialog; falls back to
#              a plain terminal prompt.
#
# Arguments:
#   $1 - prompt (string, required): The yes/no question displayed to the user.
#
# Globals:
#   answer (write): Set to "yes" if the user confirmed, "no" otherwise.
#
# Returns:
#   0 - User answered yes.
#   1 - User answered no.
#   2 - No prompt argument provided.
#
# Examples:
#   confirm "Do you want to continue?"
#   echo "You answered: $answer"
#
#   if confirm "Overwrite existing files?"; then
#       copy src/ dest/ || exit 1
#   fi
function confirm {
    local prompt="$1"

    if [[ -z "$prompt" ]]; then
        error "confirm: prompt argument is required"
        return 2
    fi

    if command -v whiptail &>/dev/null; then
        if whiptail --yesno "$prompt" 8 60; then
            answer="yes"
            return 0
        else
            answer="no"
            return 1
        fi
    else
        local reply
        while true; do
            read -r -p "${prompt} [y/n]: " reply
            case "${reply,,}" in
                y|yes)
                    answer="yes"
                    return 0
                    ;;
                n|no)
                    answer="no"
                    return 1
                    ;;
                *)
                    warn "Please enter y or n."
                    ;;
            esac
        done
    fi
}
