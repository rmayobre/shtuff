# Monitoring and utilities

`monitor` waits on a background PID and shows a loading indicator. Start the command with `&` and pass `$!`.

> Generated from the header comments in `src/` by `docs/generate-reference.sh`. Edit the headers, not this file.

## `monitor`

_Source: `src/core/utils/monitor.sh`_

```text
Function: monitor
Description: Monitors a background process by PID, displaying a loading indicator until it exits,
             then prints a success or error message based on its exit code.
             When LOG_LEVEL=verbose the loading indicator is suppressed so that streaming command
             output written to the console is not garbled by the spinner.

Arguments:
  $1 - pid (integer, required): Process ID of the background process to monitor.
  --message MSG (string, optional, default: "Processing"): Message shown alongside the loading indicator.
  --style STYLE (string, optional, default: "spinner"): Loading indicator style.
      Valid values: spinner, dots, bars, arrows, clock.
  --success_msg MSG (string, optional, default: "Process completed"): Message printed on success.
  --error_msg MSG (string, optional, default: "Process failed"): Message printed on failure.

Globals:
  DEFAULT_LOADING_STYLE (read): Fallback style used when --style is not provided.
  SPINNER_LOADING_STYLE (read): Constant identifying the spinner style.
  DOTS_LOADING_STYLE (read): Constant identifying the dots style.
  BARS_LOADING_STYLE (read): Constant identifying the bars style.
  ARROWS_LOADING_STYLE (read): Constant identifying the arrows style.
  CLOCK_LOADING_STYLE (read): Constant identifying the clock style.
  RESET_COLOR (read): ANSI reset sequence used to restore terminal color after the completion message.
  LOG_LEVEL (read): When set to "verbose", the loading indicator is skipped.
  VERBOSE_LEVEL (read): Constant identifying the verbose log level.

Returns:
  0 - The monitored process exited successfully.
  1 - No PID provided, PID does not exist, or unknown loading style specified.
  N - Exit code of the monitored process when it exits with a non-zero status.

Examples:
  some_long_command &
  monitor $! --message "Building project" --style spinner \
      --success_msg "Build complete!" --error_msg "Build failed!" || exit 1

  download_file &
  monitor $! --style dots --message "Downloading"
```

## `stop`

_Source: `src/core/utils/stop.sh`_

```text
Function: stop
Description: Sends a termination signal to a background process and waits for it to exit.

Arguments:
  $1 - pid (integer, required): Process ID of the background process to stop.

Globals:
  None

Returns:
  0 - Process terminated and waited on successfully.
  1 - No PID provided.
  N - Exit code returned by kill or wait if either command fails.

Examples:
  some_command &
  bg_pid=$!
  stop "$bg_pid"
```

## `download`

_Source: `src/core/utils/download.sh`_

```text
Function: download
Description: Downloads a file from a URL using curl (or wget as a fallback),
             displaying a loading indicator while the transfer is in progress.
             By default the file is saved in the same directory as the calling
             script; use --dir to override the destination.

Arguments:
  --url URL      (string, required): The URL of the file to download.
  --dir DIR      (string, optional, default: calling script's directory): Directory
                 in which to save the downloaded file. Created if it does not exist.
  --output NAME  (string, optional, default: basename of URL): Filename to use when
                 saving the downloaded file. Derived from the URL when not provided.
  --style STYLE  (string, optional, default: "spinner"): Loading indicator style.
      Valid values: spinner, dots, bars, arrows, clock.
  --message MSG  (string, optional, default: "Downloading"): Message shown alongside
                 the loading indicator.

Globals:
  DEFAULT_LOADING_STYLE (read): Fallback style used when --style is not provided.

Returns:
  0 - File downloaded successfully.
  1 - Missing required arguments, unresolvable filename, directory creation failure,
      no supported download tool available, or the download command failed.

Examples:
  download --url "https://example.com/archive.zip"
  download --url "https://example.com/archive.zip" --dir /tmp
  download --url "https://example.com/archive.zip" --dir /opt/myapp --output app.zip
  download --url "https://example.com/archive.zip" --style dots --message "Fetching release"
```

## `progress`

_Source: `src/core/utils/progress.sh`_

```text
Function: progress
Description: Draws or updates a progress bar in-place on the current terminal line.
             Call repeatedly with increasing --current values to animate the bar
             as work progresses. The bar finalizes (prints a trailing newline)
             automatically when --current equals --total, or immediately when
             --done is passed.

             When --lines-above N is provided the function moves the cursor up
             N lines before drawing, then restores the cursor to its original
             position afterward. This keeps the bar pinned at the top of a
             block of scrolling output (e.g. per-item monitor messages) without
             the caller needing to manage cursor movement itself.

Visual Output:
  In-progress (current = 4, total = 10, message = "Downloading", width = 40):

    Downloading [████████████████░░░░░░░░░░░░░░░░░░░░░░░░]  40% ( 4/10)

  Complete (current = 10, total = 10):

    Downloading [████████████████████████████████████████] 100% (10/10)

  Pinned bar (--lines-above 2) while per-item output scrolls below it:

    Copying [██████████████████████████░░░░░░░░░░░░░░]  50% (1/2)   <- stays here
    ✓ first.txt copied
    ⠸ Copying second.txt                                             <- monitor below

Arguments:
  --current N      (integer, required): Current step/value (0 to --total inclusive).
  --total N        (integer, required): Total steps/value representing 100%.
  --message MSG    (string, optional, default: "Progress"): Label printed before the bar.
  --width N        (integer, optional, default: 40): Number of fill characters in the bar.
  --lines-above N  (integer, optional, default: 0): Lines between the current cursor
                   position and the bar line. When non-zero, the cursor is moved up N
                   lines before drawing and restored to its original position afterward.
  --done           (flag, optional): Force a trailing newline, finalizing the bar output.
                   Automatically implied when --current equals --total.

Globals:
  GREEN       (read): ANSI color applied to the filled portion of the bar.
  RESET_COLOR (read): ANSI reset sequence used to restore terminal color.

Returns:
  0 - Success.
  1 - Missing or invalid argument: --current or --total absent or non-numeric,
      --total is zero, --width is zero or non-numeric, --lines-above is non-numeric,
      or --current exceeds --total.

Examples:
  # Iterate over a list of files and report progress after each one
  local files=(file1 file2 file3 file4 file5)
  local total=${#files[@]}
  for i in "${!files[@]}"; do
      process "${files[$i]}"
      progress --current $(( i + 1 )) --total "$total" --message "Processing files"
  done

  # Pinned bar above per-item monitor output (bar is i+2 lines above after item i)
  progress --current 0 --total "$total" --message "Copying"
  printf "\n"
  for (( i = 0; i < total; i++ )); do
      cp "${sources[$i]}" "$dest" &
      monitor $! --message "Copying ${sources[$i]}"
      progress --current $(( i + 1 )) --total "$total" --message "Copying" \
          --lines-above $(( i + 2 ))
  done
```
