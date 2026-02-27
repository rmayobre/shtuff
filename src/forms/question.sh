#!/usr/bin/env bash

# Function: question
# Description: Prompts the user with a question and stores their input in the
#              global variable 'answer'.
#
# Arguments:
#   $1 - prompt (string, required): The question text displayed to the user.
#
# Globals:
#   answer (write): Set to the string the user entered at the prompt.
#
# Returns:
#   0 - Input read successfully.
#   1 - No prompt argument provided.
#
# Examples:
#   question "What is your name?"
#   echo "Hello, $answer!"
#
#   question "Which port should the server listen on?"
function question {
    local prompt="$1"

    if [[ -z "$prompt" ]]; then
        error "question: prompt argument is required"
        return 1
    fi

    answer=""
    read -r -p "${prompt} " answer
}
