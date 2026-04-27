# core/engine

Scan orchestrator. Wires parser, config, and rules into a single entry point. Supports optional BFS traversal of transitive composite-action dependencies.

## API

```mbt nocheck
pub fn scan(
  target : @papion.ScanTarget,
  action_yml_yaml : String,
  policy : @papion.Policy,
  resolve_ref_kind~ : (String, String, String) -> @papion.RefKind = ...,
  fetch_action_yml~ : ((String, String, String, String?) -> Result[String, String])? = None,
) -> Result[@papion.ScanResult, String]
```

- `target` — the action being scanned (`owner`, `repo`, `git_ref`)
- `action_yml_yaml` — raw YAML content of `action.yml`
- `policy` — papion policy; `scan` normalizes `allowed`/`disallowed` to lowercase and rejects patterns longer than 256 characters before evaluation
- `resolve_ref_kind~` — optional callback to classify a git ref as `Sha`, `Tag`, `Branch`, or `ImmutableRelease`; defaults to `@rules.classify_ref`
- `fetch_action_yml~` — optional callback `(owner, repo, git_ref, path?) -> Result[String, String]`; when provided, enables recursive BFS traversal of transitive dependencies

Returns `Ok(ScanResult)` with findings and summary, or `Err(message)` if the root YAML is unparseable.

## Behaviour

Before rule evaluation, `scan` normalizes and validates the policy so both CLI callers and programmatic callers share the same invariants:

- `policy.allowed` and `policy.disallowed` are lowercased before glob matching
- every allowed/disallowed pattern must be at most 256 characters
- invalid policies fail fast with `Err(...)` rather than silently producing mismatched findings

**Non-recursive mode** (default, `fetch_action_yml~` = `None`):

1. Parse `action_yml_yaml` with `@parser.parse_action_yml`
2. Normalize and validate `policy`
3. Extract action refs from composite steps with `@parser.extract_refs`
4. Evaluate each ref against the policy with `@rules.evaluate`
5. Count failures and warnings for the summary
6. Return `ScanResult { target, findings, summary }`

**Recursive mode** (`fetch_action_yml~` = `Some(fetch)`):

The engine performs a BFS traversal starting from the root action. For each action in the queue:

1. Parse the YAML; if the root fails, return `Err`; if a transitive node fails, skip it.
2. Extract and evaluate all refs (same as non-recursive).
3. For each ref not yet visited, fetch its `action.yml` via the callback and enqueue it.
4. Traversal is bounded by `max_scan_depth = 10` and `max_scan_nodes = 100` (defined in `core/papion.mbt`).
5. The visited set is keyed by `owner/repo[/path]@ref` to detect cycles.

**Dependency chain context**: transitive findings include a `context` field showing the full path from the root, e.g. `"org/action-b@v1 > org/action-c@v1"`. Root findings have `context = None`.

Non-composite actions (e.g. `using: node20`) produce zero findings from ref extraction but still result in a valid `ScanResult`.

## Error handling

- Invalid root YAML → `Err("...")`
- Empty action_yml_yaml → `Err("empty YAML document")`
- Invalid policy invariant (for example overlong pattern) → `Err("...")`
- Transitive fetch error → node silently skipped
- Transitive parse error → node silently skipped
- Cycle → visited set prevents re-enqueue; terminates
- Depth/node limit exceeded → no new children enqueued; already-queued nodes drain normally
