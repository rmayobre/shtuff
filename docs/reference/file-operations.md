# File operations

Copy, move and delete with a progress indicator. Append `|| exit 1` to propagate failures.

> Generated from the header comments in `src/` by `docs/generate-reference.sh`. Edit the headers, not this file.

## `copy`

_Source: `src/core/utils/copy.sh`_

```text
Function: copy
Description: Copies one or more source files or directories to a destination,
             displaying a per-item loading indicator as each source is copied.
             When more than one source is provided an overall progress bar is
             printed above the per-item output and updated in place after every
             completion. Directories are detected automatically and copied with
             cp -r. The last positional argument is treated as the destination.

Visual Output:
  Copying three files — the bar stays pinned on the first line and updates
  in place while per-item output scrolls below it:

    Copying [████████████████████████████████████████] 100% (3/3)  <- pinned, updates
    ✓ config.json copied
    ✓ settings.yaml copied
    ✓ env.conf copied

Arguments:
  SOURCE... DEST (string, required): Two or more positional paths. All paths
                 except the last are sources; the last is the destination.
  --style STYLE  (string, optional, default: "spinner"): Loading indicator style.
      Valid values: spinner, dots, bars, arrows, clock.
  --message MSG  (string, optional, default: "Copying"): Verb shown in both
                 the progress bar label and each per-item loading indicator.
  --dry-run      (flag, optional): Print the copy commands that would be executed
                 without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  DEFAULT_LOADING_STYLE (read): Fallback style used when --style is not provided.
  GREEN                 (read): ANSI color applied to the filled bar segment.
  RESET_COLOR           (read): ANSI reset sequence used to restore terminal color.
  IS_DRY_RUN            (read): When "true", enables dry-run mode by default.

Returns:
  0 - All items copied successfully.
  1 - Fewer than two paths provided, or cp failed for any item.

Examples:
  # Copy three config files into /etc/myapp/
  copy config.json settings.yaml env.conf /etc/myapp/

  # Copy a directory into a staging area
  copy src/ /tmp/staging/

  # Custom style and label
  copy --style dots --message "Deploying" dist/ /var/www/html/
```

## `move`

_Source: `src/core/utils/move.sh`_

```text
Function: move
Description: Moves one or more source files or directories to a destination,
             displaying a per-item loading indicator as each source is moved.
             When more than one source is provided an overall progress bar is
             printed above the per-item output and updated in place after every
             completion. The last positional argument is treated as the destination.

Visual Output:
  Moving three files — the bar stays pinned on the first line and updates
  in place while per-item output scrolls below it:

    Moving [████████████████████████████████████████] 100% (3/3)  <- pinned, updates
    ✓ app.log moved
    ✓ error.log moved
    ✓ debug.log moved

Arguments:
  SOURCE... DEST (string, required): Two or more positional paths. All paths
                 except the last are sources; the last is the destination.
  --style STYLE  (string, optional, default: "spinner"): Loading indicator style.
      Valid values: spinner, dots, bars, arrows, clock.
  --message MSG  (string, optional, default: "Moving"): Verb shown in both
                 the progress bar label and each per-item loading indicator.
  --dry-run      (flag, optional): Print the move commands that would be executed
                 without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  DEFAULT_LOADING_STYLE (read): Fallback style used when --style is not provided.
  GREEN                 (read): ANSI color applied to the filled bar segment.
  RESET_COLOR           (read): ANSI reset sequence used to restore terminal color.
  IS_DRY_RUN            (read): When "true", enables dry-run mode by default.

Returns:
  0 - All items moved successfully.
  1 - Fewer than two paths provided, or mv failed for any item.

Examples:
  # Move three log files into an archive directory
  move app.log error.log debug.log /var/log/archive/

  # Move a build artifact to a publish directory
  move dist/ /srv/releases/v2.0/

  # Custom style and label
  move --style bars --message "Archiving" monday.tar tuesday.tar /mnt/backup/
```

## `delete`

_Source: `src/core/utils/delete.sh`_

```text
Function: delete
Description: Removes one or more files or directories, displaying a per-item
             loading indicator as each target is deleted. When more than one
             target is provided an overall progress bar is printed above the
             per-item output and updated in place after every completion.
             Directories are detected automatically and removed with rm -rf.

Visual Output:
  Deleting three items — the bar stays pinned on the first line and updates
  in place while per-item output scrolls below it:

    Deleting [████████████████████████████████████████] 100% (3/3)  <- pinned, updates
    ✓ /tmp/myapp.zip deleted
    ✓ /tmp/myapp_extract deleted
    ✓ /tmp/patch.diff deleted

Arguments:
  TARGET...     (string, required): One or more positional paths to remove.
  --style STYLE (string, optional, default: "spinner"): Loading indicator style.
      Valid values: spinner, dots, bars, arrows, clock.
  --message MSG (string, optional, default: "Deleting"): Verb shown in both
                the progress bar label and each per-item loading indicator.
  --dry-run     (flag, optional): Print the delete commands that would be executed
                without running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  DEFAULT_LOADING_STYLE (read): Fallback style used when --style is not provided.
  GREEN                 (read): ANSI color applied to the filled bar segment.
  RESET_COLOR           (read): ANSI reset sequence used to restore terminal color.
  IS_DRY_RUN            (read): When "true", enables dry-run mode by default.

Returns:
  0 - All items removed successfully.
  1 - No targets provided, or rm failed for any item.

Examples:
  # Delete two temporary files
  delete /tmp/myapp.zip /tmp/patch.diff

  # Delete a temporary directory (detected and removed with rm -rf)
  delete /tmp/myapp_extract

  # Custom style and label
  delete --style dots --message "Cleaning up" /tmp/myapp_extract /tmp/myapp.zip
```
