# Papion CLI Host Layer

`core/cli/` is the native host package for Papion. It is responsible for turning CLI input and host-side filesystem/network access into the pure data flow consumed by the core scan engine.

WS6 delivers the package shape, argument parsing, orchestration, exit-code policy, and native build wiring. The C FFI surface for HTTP, archive extraction, and TOML parsing is intentionally stubbed in this workspace; real host integrations land in WS8.

## Package Role

The CLI package lives inside the existing `maruloop/papion` MoonBit module so it can import:

- `maruloop/papion`
- `maruloop/papion/engine`
- `maruloop/papion/format`

The package is an `is-main` target for native builds.

## Command Contract

Supported command:

```text
papion run org/repo[/path]@ref [--format human|json] [--fail-on warn|fail|none] [--config path]
```

Rules:

- `org/repo[/path]@ref` is parsed by the CLI host.
- `path` is host-side only and is not included in `@papion.ScanTarget`.
- `ScanTarget` passed to the engine is `{ owner, repo, git_ref }`.
- `--format` defaults to `human`.
- `--fail-on` defaults to `fail`.
- `--config` is optional. When omitted, default policy is used (no file lookup). Config file search (`papion.toml`, `.github/papion.toml`) is deferred to WS8.

## Responsibilities

### Pure logic

- Parse command-line arguments into `RunOptions`.
- Decide output format.
- Map scan summary plus `fail-on` policy to process exit code.

These parts are covered by unit tests and run on the default `moon test` target.

### Native host integration

- Download the action tarball from `https://codeload.github.com/{owner}/{repo}/tar.gz/{git_ref}`.
- Extract `<tarball-root>[/path]/action.yml` from the tarball.
- Load TOML config and convert it to JSON for `engine.scan`.
- Print formatted scan output.

For WS6, these native pieces compile through C stubs and return placeholder errors where appropriate.

## Package Layout

```text
core/cli/
  README.md
  moon.pkg
  main_native.mbt       # native entry point (fn main, c_exit)
  main_wasm.mbt         # wasm stub entry point
  args.mbt              # argument parsing (CliError, RunOptions, parse_args)
  run.mbt               # orchestration (run, exit_code_for)
  github_native.mbt     # fetch_tarball via C FFI
  github_wasm.mbt       # fetch_tarball stub
  archive_native.mbt    # extract_action_yml via C FFI
  archive_wasm.mbt      # extract_action_yml stub
  config_native.mbt     # load_config stub (C FFI deferred to WS8)
  config_wasm.mbt       # load_config stub
  cwrap.c               # C glue stubs (papion_fetch_tarball, etc.)
  cli_wbtest.mbt        # whitebox unit tests
```

## Data Flow

1. `main_native.mbt` reads CLI args and calls `run`.
2. `args.mbt` parses `run` options; returns `ArgError` or `RuntimeError` on failure.
3. `run.mbt` orchestrates host calls:
   - fetch tarball
   - extract `action.yml`
   - load config JSON
   - call `engine.scan`
   - format result
   - determine exit code
4. `github_native.mbt`, `archive_native.mbt`, and `config_native.mbt` isolate native host dependencies.

## Native Dependencies

The package links native builds against:

- `libcurl`
- `libarchive`

The TOML path is also exposed through the same C stub layer so the MoonBit package boundary stays stable while the implementation evolves.

## WS6 Scope

Implemented in this workspace:

- README-driven package contract
- tested CLI argument parsing
- tested exit-code policy
- native package wiring and buildability
- stubbed host integrations with stable function signatures

Deferred to WS8:

- real HTTP download via `libcurl`
- real `tar.gz` extraction via `libarchive`
- real TOML parsing and JSON conversion

## Exit Codes

- `0`: clean scan, or findings suppressed by `--fail-on none`
- `1`: findings present at or above configured threshold
- `2`: CLI or host error
