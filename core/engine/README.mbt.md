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

## Behaviour

Before rule evaluation, `scan` normalizes and validates the policy so both CLI callers and programmatic callers share the same invariants:

- `policy.allowed` and `policy.disallowed` are lowercased before glob matching
- every allowed/disallowed pattern must be at most 256 characters
- invalid policies fail fast with `Err(...)` rather than silently producing mismatched findings

1. Parse `action_yml_yaml` with `@parser.parse_action_yml`
2. Normalize and validate `policy`
3. Extract action refs from composite steps with `@parser.extract_refs`
4. Evaluate each ref against the policy with `@rules.evaluate`
5. Count failures and warnings for the summary
6. Return `ScanResult { target, findings, summary }`

Non-composite actions (e.g. `using: node20`) produce zero findings from ref extraction but still apply rules to zero refs, so the result is always a valid `ScanResult`.

## Error handling

- Invalid YAML → `Err("...")`
- Empty action_yml_yaml → `Err("empty YAML document")`
- Invalid policy invariant (for example overlong pattern) → `Err("...")`
