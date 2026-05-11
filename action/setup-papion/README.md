# setup-papion

Install the [Papion](https://github.com/maruloop/papion) CLI on a GitHub Actions runner and add it to `PATH`. This action only installs — it does not run a scan. Compose it with your own `run:` steps.

## Usage

```yaml
- uses: maruloop/papion/action/setup-papion@v1

- run: papion run actions/checkout@v4
```

The `version` input defaults to the release that the action was tagged from. You can override it to install a different version:

```yaml
- uses: maruloop/papion/action/setup-papion@v1
  with:
    version: v0.2.0
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `version` | no | current release | Papion version to install. Accepts `vX.Y.Z` or `X.Y.Z`. Must be pinned to an explicit release tag — `latest` is not accepted. The default is rewritten to the concrete release tag by the release pipeline. |

## Outputs

| Output | Description |
|--------|-------------|
| `version` | The release tag that was installed (e.g. `v0.2.0`). |

## Supported runners

| Runner | Status |
|--------|--------|
| `ubuntu-*` (x86_64) | ✅ |
| `macos-14`+ (arm64) | ✅ |
| `windows-*` | ❌ not yet supported |
| Linux arm64 | ❌ not yet supported |
| macOS x86_64 (Intel) | ❌ not yet supported |

On unsupported runners the action fails immediately with a clear error message.

## Example: scan on every push

```yaml
name: Papion

on:
  push:
    branches: [main]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
      - uses: maruloop/papion/action/setup-papion@v1
      - run: papion run "${{ github.repository }}@${{ github.sha }}"
```

## Notes

- The action downloads `papion-<os>-<arch>.tar.gz` from the matching [GitHub Release](https://github.com/maruloop/papion/releases), extracts the binary, and prepends its directory to `$GITHUB_PATH`.
- `latest` is intentionally not accepted as a version value. Pinning to an explicit tag is required for reproducibility and supply-chain safety.
- Checksum verification is not yet performed (follow-up: publish `.sha256` files from the release pipeline).
- Caching is not performed at this version. The binary is small; re-download per job is intentional.
