# Papion CLI Packages

The CLI is split into shared orchestration plus target-specific host packages.

## Package Roles

- `core/cli`: target-agnostic argument parsing, orchestration, output-format selection, and exit-code policy.
- `core/native`: native executable plus host integrations for file I/O, environment variables, GitHub Contents API fetch, and TOML config loading.
- `core/wasm`: WASM/browser-facing stubs or host bindings.

This package split keeps native-only dependencies out of the shared CLI package. MoonBit can then report real `unused_package` regressions without package-wide suppression or `if false` keepalive references.

## Command Contract

Supported command:

```text
papion run org/repo[/path]@ref [--format human|json] [--fail-on warn|fail|none] [--config path]
```

Rules:

- `org/repo[/path]@ref` is parsed by the shared CLI package.
- `path` is host-side only and is not included in `@papion.ScanTarget`.
- `ScanTarget` passed to the engine is `{ owner, repo, git_ref }`.
- `--format` defaults to `human`.
- `--fail-on` defaults to `fail`.
- `--config` is optional. When omitted, default policy is used.
- The config path is explicit. Automatic config discovery (`papion.toml`, `.github/papion.toml`) is not part of this package yet.

## Native Host Integration

`core/native` provides the real host functions used by the native executable:

- Fetch `{path/}action.yml` (fallback: `{path/}action.yaml`) from `https://api.github.com/repos/{owner}/{repo}/contents/{path/}action.yml?ref={git_ref}`, where `path/` is omitted for repository-root actions.
- Decode the GitHub `content` field from base64 to raw action YAML bytes, then decode bytes as UTF-8.
- Load TOML config directly into `@papion.Policy`.
- Print formatted scan output and exit with the selected status code.

## Package Layout

```text
core/cli/
  README.md
  moon.pkg
  args.mbt              # shared argument parsing
  run.mbt               # shared orchestration via injected host functions
  cli_test.mbt          # target-agnostic CLI tests

core/native/
  moon.pkg              # native-only package
  main.mbt              # native entry point (fn main, c_exit)
  github.mbt            # GitHub Contents API fetch and YAML decode
  config.mbt            # load_config with native file read + TOML parsing
  fileio.mbt            # native file I/O helper used by config loading
  native_wbtest.mbt     # native host whitebox tests

core/wasm/
  moon.pkg              # JS/WASM package
  main.mbt              # WASM stub entry point
  github.mbt            # GitHub fetch stub
  config.mbt            # load_config stub

core/cli/testdata/
  papion.toml
```

## Data Flow

1. `core/native/main.mbt` reads CLI args and calls `@cli.run_with_host`.
2. `core/cli/args.mbt` parses `run` options; returns `ArgError` or `RuntimeError` on failure.
3. `core/cli/run.mbt` orchestrates injected host calls:
   - load config policy
   - fetch `action.yml` / `action.yaml`
   - call `engine.scan`
   - format result
   - determine exit code
4. `core/native` and `core/wasm` provide target-specific host functions.

## Test Strategy

- Default `moon test --deny-warn` covers target-agnostic CLI logic and the WASM stub package.
- Native host-layer tests run with `moon test --target native --deny-warn`.
- CI builds the native executable from `core/native` and runs smoke tests against `_build/native/debug/build/native/native.exe`.

## Exit Codes

- `0`: clean scan, or findings suppressed by `--fail-on none`
- `1`: findings present at or above configured threshold
- `2`: CLI or host error
