# Papion

Scan GitHub Actions for safety issues — unpinned dependencies, missing SHA pins, and policy violations.

---

## What Papion checks

Papion evaluates policies against all action references, direct and transitive.

Built-in policies:

- **SHA pinning** — all references must be pinned to a full commit SHA, not a tag or branch
- **Allowed list** — only actions matching the allowed list are permitted
- **Disallowed list** — actions matching the disallowed list are always rejected

If an action appears in both lists, **disallowed takes precedence**.

---

## CLI

### Install

```sh
go install github.com/maruloop/papion@latest
```

### Usage

```sh
papion run org/repo@ref
```

**Examples:**

```sh
# Scan by tag
papion run actions/checkout@v4

# Scan by SHA
papion run actions/checkout@abc1234def5678

# Scan a specific version
papion run actions/setup-go@v5.0.0
```

### Output

Human-readable by default:

```
papion run actions/checkout@v4

  WARN  actions/checkout@v4
        Referenced by tag, not pinned to a SHA.
        Tip: use actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683

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

### Exit codes

| Code | Meaning |
|------|---------|
| `0`  | No findings |
| `1`  | One or more failures |
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

      - uses: maruloop/papion@v1
```

Override the ref to scan a specific tag or SHA:

```yaml
      - uses: maruloop/papion@v1
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

1. Downloads the action archive from GitHub (no full clone)
2. Parses `action.yml` and any composite steps
3. Evaluates rules against all referenced actions
4. Reports findings

Scans run locally — no data is sent to any server.

---

## License

MIT
