# Papion CLI Host Layer

`core/cli/` is the native host package for Papion. It is responsible for turning CLI input and host-side filesystem/network access into the pure data flow consumed by the core scan engine.

WS8 completes the real host integrations for GitHub Contents API fetch, action YAML decode, and TOML config loading, while preserving the WS6 package shape, argument parsing, orchestration, and exit-code policy.

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
- `--config` is optional. When omitted, default policy is used.
- The config path is explicit. Automatic config discovery (`papion.toml`, `.github/papion.toml`) is not part of this package yet.

## Responsibilities

### Pure logic

- Parse command-line arguments into `RunOptions`.
- Decide output format.
- Map scan summary plus `fail-on` policy to process exit code.

These parts are covered by unit tests and run on the default `moon test` target.

### Native host integration

- Fetch `{path/}action.yml` (fallback: `{path/}action.yaml`) from `https://api.github.com/repos/{owner}/{repo}/contents/{path/}action.yml?ref={git_ref}`, where `path/` is omitted for repository-root actions.
- Decode the GitHub `content` field (base64) to raw action YAML bytes, then decode bytes as UTF-8.
- Load TOML config directly into `@papion.Policy`.
- Print formatted scan output.

These native pieces are implemented for native builds and remain stubbed on WASM targets.

## Package Layout

```text
core/cli/
  README.md
  moon.pkg
  main_native.mbt       # native entry point (fn main, c_exit)
  main_wasm.mbt         # wasm stub entry point
  args.mbt              # argument parsing (CliError, RunOptions, parse_args)
  run.mbt               # orchestration (run, exit_code_for)
  github_native.mbt     # fetch action.yml/action.yaml via GitHub Contents API and decode YAML text
  github_wasm.mbt       # GitHub fetch stub
  config_native.mbt     # load_config with native file read + TOML parsing
  config_wasm.mbt       # load_config stub
  fileio_native.mbt     # native file I/O helper (read_file) used by config loading
  cli_wbtest.mbt        # whitebox unit tests
  testdata/
    papion.toml
```

## Data Flow

1. `main_native.mbt` reads CLI args and calls `run`.
2. `args.mbt` parses `run` options; returns `ArgError` or `RuntimeError` on failure.
3. `run.mbt` orchestrates host calls:
   - fetch `action.yml`/`action.yaml` bytes from GitHub Contents API
   - decode YAML bytes to string
   - load config policy
   - call `engine.scan`
   - format result
   - determine exit code
4. `github_native.mbt` and `config_native.mbt` isolate native host dependencies.

## Native Dependencies

The package uses:

- `moonbitlang/async/http` (+ `moonbitlang/async/tls`) for HTTPS requests to GitHub Contents API
- `bobzhang/toml` for TOML parsing in MoonBit
- libc file I/O through `fileio_native.mbt` for config file reads

## Testdata Layout

```text
core/cli/testdata/
  papion.toml
```

These TOML fixtures are used by whitebox tests for config loading.

## Test Strategy

- Default `moon test` coverage is limited to target-agnostic logic that can run on the default MoonBit test target.
- CLI host-layer tests in `cli_wbtest.mbt` cover parsing, orchestration, exit-code policy, and config loading, and they are native/LLVM-only.
- Native-only host behavior is isolated behind `*_native.mbt` modules.
- CI covers those native-only CLI tests with `moon test --target native --deny-warn`.
- CI also builds the native binary and runs a small live smoke test against a real pinned GitHub Action reference.

## Exit Codes

- `0`: clean scan, or findings suppressed by `--fail-on none`
- `1`: findings present at or above configured threshold
- `2`: CLI or host error
