# Papion

Scan GitHub Actions for policy violations.

---

## What Papion checks

Papion evaluates policies against all action references, direct and transitive.

Built-in policies:

- **SHA pinning** — all references must be pinned to a full commit SHA, not a tag or branch
- **Allowed list** — only actions matching the allowed list are permitted
- **Disallowed list** — actions matching the disallowed list are always rejected

If an action appears in both lists, **disallowed takes precedence**.

---

## Configuration

Papion looks for configuration in the following order (first found wins):

1. `--config` flag (if provided)
2. `.github/papion.toml`
3. `papion.toml` (repo root)

```toml
[policy]
sha_pinning = true  # default: true

allowed = [
  "actions/*",
  "github/*",
]

disallowed = [
  "some-org/unsafe-action",
]
```

If an action matches both `allowed` and `disallowed`, **disallowed takes precedence**.

---

## CLI

### Install

```sh
# Homebrew
brew install maruloop/tap/papion

# GitHub Releases (macOS, Linux, Windows)
# Download the binary for your platform from:
# https://github.com/maruloop/papion/releases/latest
curl -fsSL https://github.com/maruloop/papion/releases/latest/download/papion-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m) -o papion && chmod +x papion

# Docker
docker run --rm ghcr.io/maruloop/papion run actions/checkout@v4

# From source
git clone https://github.com/maruloop/papion.git
cd papion/core
moon build --target native
cp ./_build/native/debug/build/native/native.exe ../papion
```

### Usage

```sh
papion run org/repo[/path]@ref
```

Local targets are also supported:

```sh
papion run ./.github
papion run ./.github/workflows/release.yml
papion run ./action/action.yml
```

Strings starting with `./`, `../`, or `/` are treated as local paths. Local scans still recurse through transitive `uses:` references via GitHub, so the root file is local but nested action dependencies are fetched the same way as repository scans.

**Examples:**

```sh
# Scan by tag
papion run actions/checkout@v4

# Scan by SHA
papion run actions/checkout@abc1234def5678

# Scan a sub-path action (e.g. this repo's own action)
papion run maruloop/papion/action@v1

# Scan a specific version
papion run actions/setup-go@v5.0.0

# Scan a local workflow file
papion run ./.github/workflows/release.yml

# Scan every workflow and action under a local .github directory
papion run ./.github

# Use a custom config file
papion run actions/checkout@v4 --config path/to/papion.toml

# Exit 1 on warnings or failures (default: fail)
papion run actions/checkout@v4 --fail-on warn

# Never exit 1 due to findings (useful for reporting only)
papion run actions/checkout@v4 --fail-on none
```

### Output

Human-readable by default:

```
papion run actions/checkout@v4

  WARN  actions/checkout@v4
        Referenced by tag, not pinned to a SHA.
        Tip: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683

  FAIL  actions/github-script@v7 (used in composite step "setup")
        Not pinned to a SHA.

2 findings  (1 failure, 1 warning)
```

JSON output with `--format json`:

```sh
papion run actions/checkout@v4 --format json
```

```json
{
  "target": "actions/checkout@v4",
  "ref": "v4",
  "findings": [
    {
      "level": "warn",
      "rule": "sha-pinning",
      "target": "actions/checkout@v4",
      "message": "Referenced by tag, not pinned to a SHA.",
      "suggestion": "actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683"
    },
    {
      "level": "fail",
      "rule": "sha-pinning",
      "target": "actions/github-script@v7",
      "context": "composite step \"setup\"",
      "message": "Not pinned to a SHA."
    }
  ],
  "summary": {
    "failures": 1,
    "warnings": 1
  }
}
```

### Flags

| Flag | Short | Default | Description |
|------|-------|---------|-------------|
| `--config` | | — | Path to config file |
| `--format` | `-f` | `human` | Output format: `human` or `json` |
| `--fail-on` | `-F` | `fail` | Minimum level to exit 1: `warn`, `fail`, or `none` |

### Exit codes

| Code | Meaning |
|------|---------|
| `0`  | No findings at or above `--fail-on` level |
| `1`  | One or more findings at or above `--fail-on` level |
| `2`  | Scan error (network, invalid target, etc.) |

---

## GitHub Action

Add Papion to your workflow as an action maintainer to scan your own action on every push.

By default it scans the current repository at the current commit ref. You can override the ref with the `ref` input.

```yaml
# .github/workflows/papion.yml
name: Papion

on:
  push:
    branches: [main]
  schedule:
    - cron: '0 0 * * 1'  # weekly

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683

      - uses: maruloop/papion/action@v1
```

Override the ref to scan a specific tag or SHA:

```yaml
      - uses: maruloop/papion/action@v1
        with:
          ref: v2.1.0
```

### Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `ref` | no | Ref to scan (default: current commit SHA) |
| `format` | no | Output format: `human` (default) or `json` |
| `fail-on` | no | Minimum level to fail the job: `warn` or `fail` (default: `fail`) |

---

## How it works

Papion CLI is built as a MoonBit native binary, with a Docker image available as a fallback.

CLI users do not need a Go or WASM runtime.

The same MoonBit core for parsing, rules, and engine logic also compiles to WASM/JS for browser and Cloudflare Worker usage.

At runtime Papion:

1. Downloads the action archive from GitHub (no full clone)
2. Resolves `org/repo[/path]@ref` to the target `action.yml`
3. Parses `action.yml` and any composite steps
4. Evaluates rules against all referenced actions
5. Reports findings

Scans run locally — no data is sent to any server.

---

## License

MIT
