# Contributing

## Adding a module

1. Put the file in the right directory: `src/core/<feature>/` if it works on every
   platform, otherwise `src/linux/<feature>/`.
2. If it is written for bash only, name it `<name>.sh`. If it needs separate
   implementations per shell, add `<name>_bash.sh`, `<name>_ash.sh` or `<name>_zsh.sh`.
   If one file works unchanged in bash, zsh and ash (like `colors_posix.sh`), name it
   `<name>_posix.sh`. zsh falls back to `<name>_ash.sh` when it has no `_zsh` file.
3. Add one line to `src/manifest.txt`, without `.sh`, in load order:
   `core/utils/mything`. Modules that use another module's functions or constants
   must come after it.
4. Add a header comment to every function (below).
5. Run `./docs/generate-reference.sh` to refresh the reference pages.
6. Update [platform support](platform-support.md) if behavior differs by OS.

## Function header format

Every function in `src/` needs this block directly above it:

```bash
# Function: function_name
# Description: One-line description of what the function does.
#
# Arguments:
#   --flag-name NAME (string, required): Description of the argument.
#   --other-flag VALUE (integer, optional, default: 5): Description.
#   $1 - name (string, required): Positional form only when truly positional.
#
# Globals:
#   VAR_NAME (read): Global variable this function reads.
#   OTHER_VAR (write): Global variable this function writes.
#
# Returns:
#   0 - Success
#   1 - Invalid arguments or validation failure
#
# Examples:
#   function_name --flag-name "value" --other-flag 10
```

- Document arguments by name unless they are positional.
- List every global the function reads or writes. Omit the section only if there are none.
- List every exit code the function can return.
- Give at least one realistic example.

## Logging

Inside `src/`, send user-facing output through `info`, `warn`, `error` and
`debug`, not bare `echo` or `printf`. Call `error` just before any non-zero
`return`, so callers see why.

## Portability checklist

- Do not use `declare -A`, `${var,,}`, `${arr[-1]}` or `&>>` in `core/` code that must
  run on macOS's bash 3.2.
- Avoid `sed -i` without a suffix, `readlink -f`, `grep -P` and `date -d`. They differ
  on BSD and BusyBox.
- Do not call `tput`; use ANSI escapes guarded by a TTY check, as `monitor` does.
- Public functions are documented in [`AGENTS.md`](../AGENTS.md). Names starting with `_` are private.

## Testing

```bash
bash -n path/to/file.sh                 # syntax
shellcheck path/to/file.sh              # lint, if installed
bash tests/file_operations_test.sh      # runs against shtuff-core.sh
```

Check that a new `core/` module does not need `linux/`:

```bash
bash -c 'source ./shtuff-core.sh; echo "skipped=[$SHTUFF_SKIPPED]"; type your_function'
```

Check the Linux entry point and the remote loader:

```bash
bash -c 'source ./shtuff-linux.sh; type service'
SHTUFF_BASE_URL=file://$PWD bash -c 'source ./shtuff-linux-remote.sh; type service'
```

Check the POSIX loader and logging under a minimal shell:

```bash
SHTUFF_DIR=$PWD dash -c '. ./shtuff-core.sh; info ok'
```

Please test on Alpine (`docker run --rm -it alpine sh`, then `apk add bash curl`)
and on macOS when you touch platform-specific code.
