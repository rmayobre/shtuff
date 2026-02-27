#!/usr/bin/env bash

# Function: question
# Description: Prompts the user with a question and captures their input.
#
# Arguments:
#   $1 - prompt (string, required): The question text displayed to the user.
#
# Globals:
#   None
#
# Returns:
#   0 - Input read successfully.
#   1 - No prompt argument provided.
#
# Examples:
#   name=$(question "What is your name?")
#   echo "Hello, $name!"
#
#   port=$(question "Which port should the server listen on?")
function question {
    local prompt="$1"

    if [[ -z "$prompt" ]]; then
        error "question: prompt argument is required"
        return 1
    fi

    local answer
    read -r -p "${prompt} " answer
    echo "$answer"
}
