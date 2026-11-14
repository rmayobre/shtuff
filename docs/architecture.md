# Architecture

## Layout

```
shtuff/
├── shtuff-core.sh          # Local entry point: core modules only
├── shtuff-linux.sh         # Local entry point: core + linux modules
├── shtuff-core-remote.sh   # Remote entry point: core only
├── shtuff-linux-remote.sh  # Remote entry point: core + linux
├── src/
│   ├── manifest.txt        # Ordered module list
│   ├── loader.sh           # Shared local loader
│   ├── loader-remote.sh    # Shared remote loader
│   ├── core/               # Works on any platform
│   │   ├── graphics/       # ANSI colors, loading indicators
│   │   ├── logging/        # log_bash.sh, log_ash.sh
│   │   ├── networking/     # scan, poll
│   │   ├── packaging/      # install, update, uninstall, clean, dependencies, brew
│   │   ├── prompts/
│   │   └── utils/          # monitor, copy, move, delete, download, progress, stop
│   ├── linux/              # Linux-only
│   │   ├── containers/     # lxc/ and pct/
│   │   ├── gpu/
│   │   ├── networking/     # bridge, forward, network
│   │   ├── system/         # locale
│   │   └── systemd/        # service, timer
│   └── mac/                # reserved for macOS-only modules (empty)
├── docs/
├── examples/
└── tests/
```

Each platform directory holds one directory per feature. A feature directory holds
the implementation scripts, with one per interpreter only when the code differs.

## How loading works

1. An entry point (for example `shtuff-linux.sh`) sets `SHTUFF_PLATFORMS="core linux"`
   and, for local files, finds its own directory (`SHTUFF_DIR`).
2. It sources the shared loader (`src/loader.sh`, or `src/loader-remote.sh` after
   downloading it).
3. The loader picks the interpreter from `$BASH_VERSION` or `$ZSH_VERSION`,
   otherwise it assumes ash.
4. It reads `src/manifest.txt` line by line. Lines look like `core/utils/copy`
   (no `.sh`). A line is used only if its first directory is in `SHTUFF_PLATFORMS`.
5. For each module it looks for, in order: `<name>_<interpreter>.sh`,
   `<name>_ash.sh` (zsh only), then `<name>.sh` (bash only).
6. A module with no matching file is skipped and listed in `SHTUFF_SKIPPED`.
   Unless you are on bash, the loader then prints a short notice.

Modules are sourced at the top level, not inside a function, so `declare -r`
constants stay global.

The remote loader does the same, but it downloads `manifest.txt` and each module
with `curl -f` or `wget`, then `eval`s the text.

## Rules for each directory

- **`core/`** must not call anything from `linux/` or `mac/`, and must not need a
  Linux-only tool to load. Load `shtuff-core.sh` on its own to check.
- **`linux/`** may use any `core/` function.
- **`mac/`** is empty. Add `shtuff-mac.sh` and a `mac` entry in the loaders when
  the first macOS module exists.
- Cross-platform tools belong in `core/` even if they started on Linux. Homebrew
  is an example.

## Why the loader is POSIX

The entry points and loaders are parsed before any dispatch, by whatever shell
the user has: bash 3.2, zsh or BusyBox ash. They avoid arrays, `[[ ]]`, process
substitution and other bash-only syntax for that reason.
