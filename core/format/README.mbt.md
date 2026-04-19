# core/format

Output formatters for scan results. Produces human-readable or JSON output from a `ScanResult`.

## API

```mbt nocheck
pub fn format_human(result : @papion.ScanResult) -> String
pub fn format_json(result : @papion.ScanResult) -> String
```

## Human format

```
  WARN  actions/checkout@v4
        Referenced by tag, not pinned to a SHA.
        Tip: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683

  FAIL  actions/github-script@v7 (used in composite step "setup")
        Not pinned to a SHA.

2 findings  (1 failure, 1 warning)
```

Rules:
- Each finding starts with 2-space indent, level label (`WARN` or `FAIL`), 2 spaces, then the target
- If the finding has a `context`, append ` (context)` to the target line
- Message on the next line, indented 8 spaces
- If the finding has a `suggestion`, add `Tip: suggestion` on the line after the message (8-space indent)
- Blank line between findings
- Summary line at the end: `N findings  (F failure(s), W warning(s))`
  - Use singular "finding"/"failure"/"warning" when the corresponding count is 1 (e.g. `1 finding  (1 failure, 0 warnings)`)
- Zero findings: `No findings`

## JSON format

```json
{
  "target": "owner/repo@ref",
  "ref": "ref",
  "findings": [
    {
      "level": "warn",
      "rule": "sha-pinning",
      "target": "owner/repo@ref",
      "context": "composite step \"setup\"",
      "message": "...",
      "suggestion": "..."
    }
  ],
  "summary": {
    "failures": 1,
    "warnings": 1
  }
}
```

Rules:
- `target` is `"owner/repo@ref"` string (not a nested object)
- `ref` is the `git_ref` from `ScanTarget`
- `level` values are lowercase: `"warn"` or `"fail"`
- Omit `context` and `suggestion` fields from findings when absent (`None`)
