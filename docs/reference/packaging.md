# Package management

Detects apt, dnf, yum, zypper, pacman, apk and Homebrew automatically. Each call runs in the background behind a loading indicator.

> Generated from the header comments in `src/` by `docs/generate-reference.sh`. Edit the headers, not this file.

## `install`

_Source: `src/core/packaging/install.sh`_

```text
Function: install
Description: Detects the system's package manager and installs one or more packages.
             Runs the package manager command in the background and displays a loading
             indicator via monitor while the installation is in progress.

Arguments:
  $@ - packages (string, required): One or more package names to install, separated by spaces.
  --message MSG (string, optional): Message shown during the loading indicator.
  --style STYLE (string, optional, default: DEFAULT_LOADING_STYLE): Loading indicator style.
  --success_msg MSG (string, optional): Message shown on successful completion.
  --error_msg MSG (string, optional): Message shown on failure.

Globals:
  DEFAULT_LOADING_STYLE (read): Fallback loading indicator style.
  VERBOSE_FILE (write): Raw package manager output is appended here.

Returns:
  0 - All packages installed successfully.
  1 - No packages specified, unknown option, or no supported package manager found.

Examples:
  install curl
  install nodejs npm unzip
  install nodejs npm --message "Installing Node.js" --success_msg "Node.js installed"
```

## `update`

_Source: `src/core/packaging/update.sh`_

```text
Function: update
Description: Detects the system's package manager and upgrades all installed packages
             to their latest versions. Runs the package manager command in the background
             and displays a loading indicator via monitor while the update is in progress.

Arguments:
  --message MSG (string, optional, default: "Updating system packages"): Message shown
      during the loading indicator.
  --style STYLE (string, optional, default: DEFAULT_LOADING_STYLE): Loading indicator style.
  --success_msg MSG (string, optional, default: "System packages updated"): Message shown
      on successful completion.
  --error_msg MSG (string, optional, default: "Failed to update system packages"): Message
      shown on failure.

Globals:
  DEFAULT_LOADING_STYLE (read): Fallback loading indicator style.
  VERBOSE_FILE (write): Raw package manager output is appended here.

Returns:
  0 - System update completed successfully.
  1 - No supported package manager found or update failed.

Examples:
  update
  update --message "Updating packages" --success_msg "All packages updated"
```

## `uninstall`

_Source: `src/core/packaging/uninstall.sh`_

```text
Function: uninstall
Description: Detects the system's package manager and removes one or more installed packages.
             Runs the package manager command in the background and displays a loading
             indicator via monitor while the removal is in progress.

Arguments:
  $@ - packages (string, required): One or more package names to remove, separated by spaces.
  --message MSG (string, optional): Message shown during the loading indicator.
  --style STYLE (string, optional, default: DEFAULT_LOADING_STYLE): Loading indicator style.
  --success_msg MSG (string, optional): Message shown on successful completion.
  --error_msg MSG (string, optional): Message shown on failure.

Globals:
  DEFAULT_LOADING_STYLE (read): Fallback loading indicator style.
  VERBOSE_FILE (write): Raw package manager output is appended here.

Returns:
  0 - All packages removed successfully.
  1 - No packages specified, unknown option, or no supported package manager found.

Examples:
  uninstall nginx
  uninstall nodejs npm
  uninstall nginx --message "Removing nginx" --success_msg "nginx removed"
```

## `clean`

_Source: `src/core/packaging/clean.sh`_

```text
Function: clean
Description: Detects the system's package manager and removes unused dependencies and
             package caches. Runs the cleanup command in the background and displays a
             loading indicator via monitor while the cleanup is in progress.

Arguments:
  --message MSG (string, optional, default: "Cleaning packages"): Message shown
      during the loading indicator.
  --style STYLE (string, optional, default: DEFAULT_LOADING_STYLE): Loading indicator style.
  --success_msg MSG (string, optional, default: "Package cleanup complete"): Message shown
      on successful completion.
  --error_msg MSG (string, optional, default: "Package cleanup failed"): Message shown
      on failure.

Globals:
  DEFAULT_LOADING_STYLE (read): Fallback loading indicator style.
  VERBOSE_FILE (write): Raw package manager output is appended here.

Returns:
  0 - Cleanup completed successfully.
  1 - No supported package manager found or cleanup failed.

Examples:
  clean
  clean --message "Removing unused packages" --success_msg "Cleanup done"
```

## `dependencies`

_Source: `src/core/packaging/dependencies.sh`_

```text
Function: dependencies
Description: Updates system packages, then installs one or more packages individually
             with graceful per-package failure handling. Each package is installed with
             its own loading indicator. Packages that fail to install are skipped with
             a warning rather than aborting the entire operation. When more than one
             package is specified, an overall progress bar is pinned above the per-item
             output.

Arguments:
  $@ - packages (string, required): One or more package names to install.

Globals:
  SPINNER_LOADING_STYLE (read): Loading style used for monitor indicators.
  GREEN (read): ANSI color applied to the filled bar segment via progress.
  RESET_COLOR (read): ANSI reset sequence used by progress and monitor.

Returns:
  0 - Function completed. Individual package failures are warned but do not
      cause a non-zero return.
  1 - No packages specified.

Examples:
  dependencies curl nodejs npm unzip
  dependencies apache2 httpd curl
```
