# core/engine

Scan orchestrator. Wires parser, config, and rules into a single entry point.

## API

```mbt nocheck
pub fn scan(
  target : @papion.ScanTarget,
  action_yml_yaml : String,
  policy : @papion.Policy,
  fetch_action_yml : (String, String, String, String?) -> Result[String, String],
  resolve_ref_kind? : (String, String, String) -> @papion.RefKind = ...,
) -> Result[@papion.ScanResult, String]
```

- `target` — the action being scanned (`owner`, `repo`, `git_ref`, optional `path`)
- `action_yml_yaml` — raw YAML content of `action.yml`
- `policy` — papion policy; `scan` normalizes `allowed`/`disallowed` to lowercase and rejects patterns longer than 256 characters before evaluation
- `fetch_action_yml` — required callback used for recursive traversal
- `resolve_ref_kind?` — optional callback to classify a ref as `Sha`, `Branch`, or `ImmutableRelease`; defaults to the pure classifier (`classify_ref`)

Returns `Ok(ScanResult)` with findings and summary, or `Err(message)` if the root YAML is unparseable.

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

`scan` recursively traverses composite action dependencies:

1. Normalize and validate `policy`
2. Start a BFS queue with the root `action_yml_yaml` at depth 0
3. For each queued node, extract refs and evaluate each against the policy
4. For each ref not yet visited, mark it visited and — when within depth/node limits — consume one traversal-budget slot, call `fetch_action_yml`, and enqueue the node if fetch succeeds
5. Transitive findings carry a `context` field set to `"via owner/repo@ref"` identifying the immediate parent action where the dependency was found
6. Return aggregated `ScanResult` across all traversed nodes

Traversal safeguards:

| Guard | Value | Constant |
|---|---|---|
| Max depth | 10 levels below root | `@papion.max_scan_depth` |
| Max nodes | 100 unique nodes scheduled for traversal; failed fetch attempts still consume the budget and already-queued nodes are drained without further expansion once the limit is reached | `@papion.max_scan_nodes` |
| Cycle detection | visited set keyed by `owner/repo[/path]@ref` | — |

Fetch errors skip the node silently. Policy findings are generated for every reference, including repeated references to already-visited nodes (policy evaluation) — only traversal (fetching) is deduplicated.
## Error handling

- Invalid root YAML → `Err("...")`
- Empty action_yml_yaml → `Err("empty YAML document")`
- Invalid policy invariant (for example overlong pattern) → `Err("...")`
- Invalid transitive YAML → skipped silently after fetch, no `Err(...)` returned
