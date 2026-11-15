# System

Linux only.

> Generated from the header comments in `src/` by `docs/generate-reference.sh`. Edit the headers, not this file.

## `locale`

_Source: `src/linux/system/locale.sh`_

```text
Function: locale
Description: Configures the system locale by installing the necessary locale
             package, generating the locale, and setting it as the default via
             environment variables. Auto-detects the package manager.

Arguments:
  $1 - locale (string, required): The locale to configure
       (e.g. "en_US.UTF-8", "de_DE.UTF-8").
  --dry-run (flag, optional): Print the commands that would be executed without
      running them. Defaults to IS_DRY_RUN if not specified.

Globals:
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.

Returns:
  0 - Locale configured successfully.
  1 - Invalid arguments, unsupported package manager, or locale generation failed.

Examples:
  locale "en_US.UTF-8"
  locale "de_DE.UTF-8"
  locale "fr_FR.UTF-8" --dry-run
```
