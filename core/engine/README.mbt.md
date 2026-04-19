# core/engine

Scan orchestrator. Wires parser, config, and rules into a single entry point.

## API

```mbt nocheck
pub fn scan(
  target : @papion.ScanTarget,
  action_yml_yaml : String,
  config_json : String,
) -> Result[@papion.ScanResult, String]
```

- `target` — the action being scanned (`owner`, `repo`, `git_ref`)
- `action_yml_yaml` — raw YAML content of `action.yml`
- `config_json` — papion policy as JSON (empty string uses defaults)

Returns `Ok(ScanResult)` with findings and summary, or `Err(message)` if the YAML or config is unparseable.

## Behaviour

1. Parse `action_yml_yaml` with `@parser.parse_action_yml`
2. Parse `config_json` with `@config.parse_policy` (empty string → default policy)
3. Extract action refs from composite steps with `@parser.extract_refs`
4. Evaluate each ref against the policy with `@rules.evaluate`
5. Count failures and warnings for the summary
6. Return `ScanResult { target, findings, summary }`

Non-composite actions (e.g. `using: node20`) produce zero findings from ref extraction but still apply rules to zero refs, so the result is always a valid `ScanResult`.

## Error handling

- Invalid YAML → `Err("...")`
- Invalid config JSON → `Err("...")`
- Empty action_yml_yaml → `Err("empty YAML document")`
- Empty config_json → uses default policy (sha_pinning=true, no allowed/disallowed lists)
