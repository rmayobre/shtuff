# Prompts

Interactive input. Results are stored in the global `$answer` (or the `$answers` array for `selections`).

> Generated from the header comments in `src/` by `docs/generate-reference.sh`. Edit the headers, not this file.

## `question`

_Source: `src/core/prompts/question.sh`_

```text
Function: question
Description: Prompts the user with a question and stores their input in the
             global variable 'answer'. Uses whiptail if available for a
             graphical dialog; falls back to a plain terminal prompt.

Arguments:
  $1 - prompt (string, required): The question text displayed to the user.

Globals:
  answer (write): Set to the string the user entered at the prompt.

Returns:
  0 - Input read successfully.
  1 - No prompt argument provided.

Examples:
  question "What is your name?"
  echo "Hello, $answer!"

  question "Which port should the server listen on?"
```

## `options`

_Source: `src/core/prompts/options.sh`_

```text
Function: options
Description: Displays a numbered list of choices, prompts the user to pick
             one by number, and stores the selected value in the global
             variable 'answer'. Uses whiptail if available for a graphical
             menu; falls back to a plain terminal prompt.

Arguments:
  $1 - prompt (string, required): The question text displayed above the list.
  --choice VALUE (string, required, repeatable): A choice to add to the list.
                 May be specified multiple times; order is preserved.

Globals:
  answer (write): Set to the text of the choice the user selected.

Returns:
  0 - A valid selection was made.
  1 - Missing or invalid arguments (no prompt, unknown flag, no choices).

Examples:
  options "What would you like to do?" \
      --choice "Install" \
      --choice "Update" \
      --choice "Exit"
  echo "You chose: $answer"

  options "Select an environment:" \
      --choice "development" \
      --choice "staging" \
      --choice "production"
```

## `selections`

_Source: `src/core/prompts/selections.sh`_

```text
Function: selections
Description: Displays a numbered list of choices, prompts the user to pick
             one or more by number, and stores the selected values in the
             global array 'answers'. Uses whiptail if available for a
             graphical checklist; falls back to a plain terminal prompt.

Arguments:
  $1 - prompt (string, required): The question text displayed above the list.
  --choice VALUE (string, required, repeatable): A choice to add to the list.
                 May be specified multiple times; order is preserved.

Globals:
  answers (write): Set to an array of the choices the user selected, in the
           order they were originally listed.

Returns:
  0 - One or more valid selections were made.
  1 - Missing or invalid arguments (no prompt, unknown flag, no choices).

Examples:
  selections "Which packages would you like to install?" \
      --choice "nodejs" \
      --choice "curl" \
      --choice "unzip"
  printf 'You chose: %s\n' "${answers[@]}"

  selections "Select environments to deploy to:" \
      --choice "development" \
      --choice "staging" \
      --choice "production"
```

## `confirm`

_Source: `src/core/prompts/confirm.sh`_

```text
Function: confirm
Description: Prompts the user with a yes/no question, stores the result in
             the global variable 'answer', and returns 0 for yes or 1 for no.
             Uses whiptail if available for a graphical dialog; falls back to
             a plain terminal prompt.

Arguments:
  $1 - prompt (string, required): The yes/no question displayed to the user.

Globals:
  answer (write): Set to "yes" if the user confirmed, "no" otherwise.

Returns:
  0 - User answered yes.
  1 - User answered no.
  2 - No prompt argument provided.

Examples:
  confirm "Do you want to continue?"
  echo "You answered: $answer"

  if confirm "Overwrite existing files?"; then
      copy src/ dest/ || exit 1
  fi
```
