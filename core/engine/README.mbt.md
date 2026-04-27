# core/engine

Scan orchestrator. Wires parser, config, and rules into a single entry point.

## API

```mbt nocheck
pub fn scan(
  target : @papion.ScanTarget,
  action_yml_yaml : String,
  policy : @papion.Policy,
) -> Result[@papion.ScanResult, String]
```

- `target` — the action being scanned (`owner`, `repo`, `git_ref`)
- `action_yml_yaml` — raw YAML content of `action.yml`
- `policy` — papion policy; `scan` normalizes `allowed`/`disallowed` to lowercase and rejects patterns longer than 256 characters before evaluation

Returns `Ok(ScanResult)` with findings and summary, or `Err(message)` if the YAML is unparseable.

```mbt nocheck
pub fn scan_deep(
  target : @papion.ScanTarget,
  action_yml_yaml : String,
  policy : @papion.Policy,
  fetch_action_yml : (String, String, String, String?) -> Result[(String, String), String],
) -> Result[@papion.ScanResult, String]
```

Like `scan`, but also recursively follows composite step dependencies to detect findings across the full transitive dependency tree.

- `fetch_action_yml` — callback invoked as `(owner, repo, git_ref, path?)` to fetch the YAML content of a dependency; returns `(yaml_content, resolved_git_ref)` on success, or `Err(message)` to skip that dependency
- A hash map tracks already-scanned actions so each action is visited at most once, which prevents infinite loops when actions form a dependency cycle

Sub-actions that cannot be fetched or whose YAML cannot be parsed are silently skipped (best-effort).

## Behaviour

Before rule evaluation, `scan` and `scan_deep` normalize and validate the policy so both CLI callers and programmatic callers share the same invariants:

- `policy.allowed` and `policy.disallowed` are lowercased before glob matching
- every allowed/disallowed pattern must be at most 256 characters
- invalid policies fail fast with `Err(...)` rather than silently producing mismatched findings

### `scan` (shallow)

1. Parse `action_yml_yaml` with `@parser.parse_action_yml`
2. Normalize and validate `policy`
3. Extract action refs from composite steps with `@parser.extract_refs`
4. Evaluate each ref against the policy with `@rules.evaluate`
5. Count failures and warnings for the summary
6. Return `ScanResult { target, findings, summary }`

### `scan_deep` (recursive, with cycle detection)

1–4 same as `scan`; then for each ref not yet visited:

5. Add the ref to the `seen` map
6. Call `fetch_action_yml` to retrieve the dependency's YAML
7. Parse the dependency YAML and recursively evaluate its refs (steps 4–7)
8. Aggregate all findings; count failures and warnings for the summary
9. Return `ScanResult { target, findings, summary }`

Non-composite actions (e.g. `using: node20`) produce zero refs, so recursion terminates naturally at leaf nodes.

## Error handling

- Invalid YAML → `Err("...")`
- Empty action_yml_yaml → `Err("empty YAML document")`
- Invalid policy invariant (for example overlong pattern) → `Err("...")`
