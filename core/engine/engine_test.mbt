///|
fn unreachable_fetch(
  _owner : String,
  _repo : String,
  _git_ref : String,
  _path : String?,
) -> Result[String, String] {
  Err("unexpected recursive fetch")
}

///|
fn github_target(
  owner : String,
  repo : String,
  git_ref : String,
  path? : String? = None,
) -> @papion.ScanTarget {
  GitHub({ owner, repo, git_ref, path })
}

///|
test "scan unpinned ref produces sha-pinning failure" {
  let target : @papion.ScanTarget = github_target("actions", "checkout", "v4")
  let yaml_str =
    #|name: My Action
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: actions/checkout@v4
  let result = scan(
    target,
    yaml_str,
    @papion.Policy::default(),
    unreachable_fetch,
  )
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      assert_eq(r.summary.failures, 1)
      assert_eq(r.summary.warnings, 0)
      assert_eq(r.findings.length(), 1)
      assert_eq(r.findings[0].rule, "sha-pinning")
    }
  }
}

///|
test "scan pinned ref produces zero findings" {
  let target : @papion.ScanTarget = github_target(
    "actions", "checkout", "11bd71901bbe5b1630ceea73d27597364c9af683",
  )
  let yaml_str =
    #|name: My Action
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
  let result = scan(
    target,
    yaml_str,
    @papion.Policy::default(),
    unreachable_fetch,
  )
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      assert_eq(r.summary.failures, 0)
      assert_eq(r.summary.warnings, 0)
      assert_eq(r.findings, [])
    }
  }
}

///|
test "scan disallowed action produces failure" {
  let target : @papion.ScanTarget = github_target("actions", "checkout", "v4")
  let yaml_str =
    #|name: My Action
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
  let policy : @papion.Policy = {
    sha_pinning: true,
    allowed: [],
    disallowed: ["actions/checkout"],
  }
  let result = scan(target, yaml_str, policy, unreachable_fetch)
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      assert_eq(r.summary.failures, 1)
      assert_eq(r.findings[0].rule, "disallowed-list")
    }
  }
}

///|
test "scan allowed list restricts to listed actions" {
  let target : @papion.ScanTarget = github_target("actions", "checkout", "v4")
  let yaml_str =
    #|name: My Action
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
    #|    - uses: third-party/action@11bd71901bbe5b1630ceea73d27597364c9af683
  let policy : @papion.Policy = {
    sha_pinning: true,
    allowed: ["actions/*"],
    disallowed: [],
  }
  let result = scan(target, yaml_str, policy, unreachable_fetch)
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      assert_eq(r.summary.failures, 1)
      assert_eq(r.findings[0].rule, "allowed-list")
      assert_eq(
        r.findings[0].target,
        "third-party/action@11bd71901bbe5b1630ceea73d27597364c9af683",
      )
    }
  }
}

///|
test "scan node action produces zero findings" {
  let target : @papion.ScanTarget = github_target("actions", "setup-node", "v4")
  let yaml_str =
    #|name: Setup Node
    #|runs:
    #|  using: node20
  let result = scan(
    target,
    yaml_str,
    @papion.Policy::default(),
    unreachable_fetch,
  )
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      assert_eq(r.summary.failures, 0)
      assert_eq(r.summary.warnings, 0)
      assert_eq(r.findings, [])
    }
  }
}

///|
test "scan multiple unpinned refs aggregates findings" {
  let target : @papion.ScanTarget = github_target("my-org", "my-action", "main")
  let yaml_str =
    #|name: Multi Step
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: actions/checkout@v4
    #|    - uses: actions/setup-node@v4
  let result = scan(
    target,
    yaml_str,
    @papion.Policy::default(),
    unreachable_fetch,
  )
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      assert_eq(r.summary.failures, 2)
      assert_eq(r.findings.length(), 2)
    }
  }
}

///|
test "scan invalid YAML returns error" {
  let target : @papion.ScanTarget = github_target("actions", "checkout", "v4")
  let result = scan(
    target,
    ":\t bad\t:\n\t",
    @papion.Policy::default(),
    unreachable_fetch,
  )
  match result {
    Err(_) => ()
    Ok(_) => fail("expected error for invalid YAML")
  }
}

///|
test "scan result target matches input" {
  let target : @papion.ScanTarget = github_target(
    "my-org", "my-action", "abc123",
  )
  let yaml_str =
    #|name: My Action
    #|runs:
    #|  using: node20
  let result = scan(
    target,
    yaml_str,
    @papion.Policy::default(),
    unreachable_fetch,
  )
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => assert_eq(r.target, target)
  }
}

///|
test "scan uses injected ref kind resolver" {
  let target : @papion.ScanTarget = github_target("actions", "checkout", "v4")
  let yaml_str =
    #|name: My Action
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: actions/checkout@v4
  let mut calls = 0
  let mut resolved_owner = ""
  let mut resolved_repo = ""
  let mut resolved_git_ref = ""
  let result = scan(
    target,
    yaml_str,
    @papion.Policy::default(),
    unreachable_fetch,
    resolve_ref_kind=fn(owner, repo, git_ref) {
      calls = calls + 1
      resolved_owner = owner
      resolved_repo = repo
      resolved_git_ref = git_ref
      ImmutableRelease
    },
  )
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      assert_eq(calls, 1)
      assert_eq(resolved_owner, "actions")
      assert_eq(resolved_repo, "checkout")
      assert_eq(resolved_git_ref, "v4")
      assert_eq(r.findings, [])
    }
  }
}

///|
test "scan normalizes policy patterns before evaluation" {
  let target : @papion.ScanTarget = github_target("actions", "checkout", "v4")
  let yaml_str =
    #|name: My Action
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
  let policy : @papion.Policy = {
    sha_pinning: true,
    allowed: ["Actions/*"],
    disallowed: [],
  }
  let result = scan(target, yaml_str, policy, unreachable_fetch)
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => assert_eq(r.findings, [])
  }
}

///|
test "scan rejects overlong policy patterns" {
  let target : @papion.ScanTarget = github_target("actions", "checkout", "v4")
  let long_pattern = String::make(@papion.max_policy_pattern_len + 1, 'a')
  let yaml_str =
    #|name: My Action
    #|runs:
    #|  using: node20
  let policy : @papion.Policy = {
    sha_pinning: true,
    allowed: [long_pattern],
    disallowed: [],
  }
  match scan(target, yaml_str, policy, unreachable_fetch) {
    Err(_) => ()
    Ok(_) => fail("expected Err for overlong policy pattern")
  }
}

///|
test "scan_workflow scans step refs and reusable workflow job refs" {
  let target : @papion.ScanTarget = Local({
    path: "/tmp/repo/.github/workflows/ci.yml",
  })
  let yaml_str =
    #|name: CI
    #|jobs:
    #|  reusable:
    #|    uses: org/reusable/.github/workflows/build.yml@v1
    #|  scan:
    #|    runs-on: ubuntu-latest
    #|    steps:
    #|      - uses: actions/checkout@v4
  let result = scan_workflow(
    target,
    yaml_str,
    @papion.Policy::default(),
    unreachable_fetch,
  )
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      assert_eq(r.target, target)
      // both the reusable workflow job ref and the step ref produce findings
      // (mutable tag @v1 and @v4 respectively); the workflow is not recursed into
      assert_eq(r.summary.failures, 2)
      assert_eq(r.findings.length(), 2)
      let targets = r.findings.map(fn(f) { f.target })
      assert_true(targets.contains("actions/checkout@v4"))
      assert_true(
        targets.contains("org/reusable/.github/workflows/build.yml@v1"),
      )
    }
  }
}

///|
test "scan_workflow recursively fetches transitive action refs" {
  let target : @papion.ScanTarget = Local({
    path: "/tmp/repo/.github/workflows/ci.yml",
  })
  let workflow_yaml =
    #|name: CI
    #|jobs:
    #|  scan:
    #|    runs-on: ubuntu-latest
    #|    steps:
    #|      - uses: org/composite-action@v1
  let transitive_yaml =
    #|name: Composite
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: actions/checkout@v4
  let mut fetch_calls = 0
  let result = scan_workflow(target, workflow_yaml, @papion.Policy::default(), fn(
    owner,
    repo,
    git_ref,
    path,
  ) {
    fetch_calls = fetch_calls + 1
    if owner == "org" &&
      repo == "composite-action" &&
      git_ref == "v1" &&
      path == None {
      Ok(transitive_yaml)
    } else {
      Err("unexpected fetch")
    }
  })
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      assert_eq(fetch_calls, 2)
      assert_eq(r.summary.failures, 2)
      assert_eq(r.findings.length(), 2)
      assert_eq(r.findings[0].target, "org/composite-action@v1")
      assert_eq(r.findings[1].target, "actions/checkout@v4")
      assert_true(r.findings[1].context == Some("via org/composite-action@v1"))
    }
  }
}

// ---- recursive scan tests ----

///|
/// Shared helper: build a fetch callback from a lookup table keyed by
/// "owner/repo@git_ref". Returns Err for unknown keys.
fn make_fetch_table(
  table : Map[String, String],
) -> (String, String, String, String?) -> Result[String, String] {
  fn(owner, repo, git_ref, _path) {
    match table.get("\{owner}/\{repo}@\{git_ref}") {
      Some(yaml) => Ok(yaml)
      None =>
        Err("action not found in fetch table: \{owner}/\{repo}@\{git_ref}")
    }
  }
}

///|
test "scan reports direct and transitive findings" {
  let target : @papion.ScanTarget = github_target("org", "action-a", "sha_a")
  let a_yaml =
    #|name: Action A
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-b@v1
  let b_yaml =
    #|name: Action B
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-c@v1
  let c_yaml =
    #|name: Action C
    #|runs:
    #|  using: node20
  let fetch = make_fetch_table({
    "org/action-b@v1": b_yaml,
    "org/action-c@v1": c_yaml,
  })
  let result = scan(target, a_yaml, @papion.Policy::default(), fetch)
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      assert_eq(r.summary.failures, 2)
      assert_eq(r.findings.length(), 2)
      assert_eq(r.findings[0].target, "org/action-b@v1")
      assert_true(r.findings[0].context == None)
      assert_eq(r.findings[1].target, "org/action-c@v1")
      assert_true(r.findings[1].context == Some("via org/action-b@v1"))
    }
  }
}

///|
test "scan scans shared transitive dependency exactly once" {
  let target : @papion.ScanTarget = github_target("org", "action-a", "v1")
  let a_yaml =
    #|name: Action A
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-b@v1
    #|    - uses: org/action-c@v1
  let b_yaml =
    #|name: Action B
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-d@v1
  let c_yaml =
    #|name: Action C
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-d@v1
  let d_yaml =
    #|name: Action D
    #|runs:
    #|  using: node20
  let mut fetch_count = 0
  let fetch = fn(
    owner : String,
    repo : String,
    git_ref : String,
    _path : String?,
  ) -> Result[String, String] {
    fetch_count = fetch_count + 1
    let table : Map[String, String] = {
      "org/action-b@v1": b_yaml,
      "org/action-c@v1": c_yaml,
      "org/action-d@v1": d_yaml,
    }
    match table.get("\{owner}/\{repo}@\{git_ref}") {
      Some(yaml) => Ok(yaml)
      None => Err("not found")
    }
  }
  let result = scan(target, a_yaml, @papion.Policy::default(), fetch)
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      // B, C (from A) and D (from B and from C) each produce unpinned findings
      // D is referenced twice (by B and by C) so appears in findings twice
      assert_eq(r.summary.failures, 4)
      assert_eq(r.findings.length(), 4)
      // D's YAML is only fetched once despite being referenced twice
      assert_eq(fetch_count, 3)
    }
  }
}

///|
test "scan terminates on simple cycle A -> B -> A" {
  let target : @papion.ScanTarget = github_target("org", "action-a", "v1")
  let a_yaml =
    #|name: Action A
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-b@v1
  let b_yaml =
    #|name: Action B
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-a@v1
  let fetch = make_fetch_table({ "org/action-b@v1": b_yaml })
  let result = scan(target, a_yaml, @papion.Policy::default(), fetch)
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      // B (from A) and A (from B via cycle) are both unpinned
      assert_eq(r.summary.failures, 2)
      assert_eq(r.findings.length(), 2)
      assert_eq(r.findings[0].target, "org/action-b@v1")
      assert_true(r.findings[0].context == None)
      assert_eq(r.findings[1].target, "org/action-a@v1")
      assert_true(r.findings[1].context == Some("via org/action-b@v1"))
    }
  }
}

///|
test "scan terminates on longer cycle A -> B -> C -> A" {
  let target : @papion.ScanTarget = github_target("org", "action-a", "v1")
  let a_yaml =
    #|name: Action A
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-b@v1
  let b_yaml =
    #|name: Action B
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-c@v1
  let c_yaml =
    #|name: Action C
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-a@v1
  let fetch = make_fetch_table({
    "org/action-b@v1": b_yaml,
    "org/action-c@v1": c_yaml,
  })
  let result = scan(target, a_yaml, @papion.Policy::default(), fetch)
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      // B (from A), C (from B), A (from C) — all unpinned
      assert_eq(r.summary.failures, 3)
      assert_eq(r.findings.length(), 3)
      assert_eq(r.findings[2].target, "org/action-a@v1")
      assert_true(r.findings[2].context == Some("via org/action-c@v1"))
    }
  }
}

///|
test "scan stops at max_scan_depth" {
  // Build a chain of max_scan_depth + 2 nodes: action-0 (target) through
  // action-(max+1). The guard should prevent fetching action-(max+1).
  let max = @papion.max_scan_depth
  let target : @papion.ScanTarget = github_target("org", "action-0", "v1")
  // Pre-build fetch table: action-k (for k=1..max) uses action-(k+1)
  let fetch_table : Map[String, String] = {}
  let mut idx = 1
  while idx <= max {
    let next = idx + 1
    fetch_table["org/action-\{idx}@v1"] = "name: Action \{idx}\nruns:\n  using: composite\n  steps:\n    - uses: org/action-\{next}@v1\n"
    idx = idx + 1
  }
  let mut fetch_count = 0
  let fetch = fn(
    owner : String,
    repo : String,
    git_ref : String,
    _path : String?,
  ) -> Result[String, String] {
    fetch_count = fetch_count + 1
    match fetch_table.get("\{owner}/\{repo}@\{git_ref}") {
      Some(yaml) => Ok(yaml)
      None => Err("not found")
    }
  }
  let root_yaml = "name: Action 0\nruns:\n  using: composite\n  steps:\n    - uses: org/action-1@v1\n"
  let result = scan(target, root_yaml, @papion.Policy::default(), fetch)
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      // fetch is called for action-1 through action-max (max calls total);
      // action-(max+1) is evaluated (finding) but never fetched
      assert_eq(fetch_count, max)
      // Every node in the chain produces an unpinned finding, including
      // action-(max+1) which was evaluated but not fetched
      assert_eq(r.summary.failures, max + 1)
    }
  }
}

///|
test "scan invalid root YAML returns error" {
  let target : @papion.ScanTarget = github_target("org", "action-a", "v1")
  let never_fetch = fn(
    _owner : String,
    _repo : String,
    _git_ref : String,
    _path : String?,
  ) -> Result[String, String] {
    Err("should not be called")
  }
  let result = scan(
    target,
    ":\t bad\t:\n\t",
    @papion.Policy::default(),
    never_fetch,
  )
  match result {
    Err(_) => ()
    Ok(_) => fail("expected Err for invalid root YAML")
  }
}

///|
test "scan stops at max_scan_nodes for wide fan-out" {
  // Root uses max_scan_nodes + 5 children. The discovery budget should prevent
  // scheduling beyond max_scan_nodes, so at most max_scan_nodes - 1 child fetch
  // attempts occur (root counts as node 1 in the traversal budget).
  let max = @papion.max_scan_nodes
  let target : @papion.ScanTarget = github_target("org", "action-root", "v1")
  let child_count = max + 5
  let mut root_yaml = "name: Root\nruns:\n  using: composite\n  steps:\n"
  let mut k = 0
  while k < child_count {
    root_yaml = root_yaml + "    - uses: org/action-child-\{k}@v1\n"
    k = k + 1
  }
  let child_yaml = "name: Child\nruns:\n  using: node20\n"
  let mut fetch_count = 0
  let fetch = fn(
    _owner : String,
    _repo : String,
    _git_ref : String,
    _path : String?,
  ) -> Result[String, String] {
    fetch_count = fetch_count + 1
    Ok(child_yaml)
  }
  let result = scan(target, root_yaml, @papion.Policy::default(), fetch)
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      // All child_count refs produce unpinned findings regardless of node cap
      assert_eq(r.findings.length(), child_count)
      // Fetch attempts are capped: only max - 1 children fit in the budget
      assert_eq(fetch_count, max - 1)
    }
  }
}

///|
test "scan stops failed fetch attempts at max_scan_nodes for wide fan-out" {
  let max = @papion.max_scan_nodes
  let target : @papion.ScanTarget = github_target("org", "action-root", "v1")
  let child_count = max + 5
  let mut root_yaml = "name: Root\nruns:\n  using: composite\n  steps:\n"
  let mut k = 0
  while k < child_count {
    root_yaml = root_yaml + "    - uses: org/missing-child-\{k}@v1\n"
    k = k + 1
  }
  let mut fetch_count = 0
  let fetch = fn(
    _owner : String,
    _repo : String,
    _git_ref : String,
    _path : String?,
  ) -> Result[String, String] {
    fetch_count = fetch_count + 1
    Err("not found")
  }
  let result = scan(target, root_yaml, @papion.Policy::default(), fetch)
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      assert_eq(r.findings.length(), child_count)
      // Failed fetches still consume the traversal budget.
      assert_eq(fetch_count, max - 1)
    }
  }
}

///|
test "scan case-insensitive dedup prevents repeated fetch" {
  let target : @papion.ScanTarget = github_target("Org", "Action-A", "v1")
  let a_yaml =
    #|name: Action A
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-b@v1
    #|    - uses: ORG/ACTION-B@v1
  let b_yaml =
    #|name: Action B
    #|runs:
    #|  using: node20
  let mut fetch_count = 0
  let fetch = fn(
    _owner : String,
    _repo : String,
    _git_ref : String,
    _path : String?,
  ) -> Result[String, String] {
    fetch_count = fetch_count + 1
    Ok(b_yaml)
  }
  let result = scan(target, a_yaml, @papion.Policy::default(), fetch)
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      // Both refs produce findings (policy evaluation always runs)
      assert_eq(r.findings.length(), 2)
      // But action-b is fetched only once despite different casing
      assert_eq(fetch_count, 1)
    }
  }
}

///|
test "scan normalizes root key for mixed-case root cycle" {
  let target : @papion.ScanTarget = github_target("Org", "Action-A", "v1")
  let a_yaml =
    #|name: Action A
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-a@v1
  let mut fetch_count = 0
  let fetch = fn(
    _owner : String,
    _repo : String,
    _git_ref : String,
    _path : String?,
  ) -> Result[String, String] {
    fetch_count = fetch_count + 1
    Ok(a_yaml)
  }
  let result = scan(target, a_yaml, @papion.Policy::default(), fetch)
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      // The self-reference is still evaluated once.
      assert_eq(r.findings.length(), 1)
      // But the root action is not re-fetched when casing differs.
      assert_eq(fetch_count, 0)
    }
  }
}

///|
test "scan skips resolver when sha_pinning disabled" {
  let target : @papion.ScanTarget = github_target("org", "action-a", "v1")
  let a_yaml =
    #|name: Action A
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-b@main
    #|    - uses: org/action-c@main
  let b_yaml =
    #|name: Action B
    #|runs:
    #|  using: node20
  let c_yaml =
    #|name: Action C
    #|runs:
    #|  using: node20
  let fetch = make_fetch_table({
    "org/action-b@main": b_yaml,
    "org/action-c@main": c_yaml,
  })
  let policy : @papion.Policy = {
    sha_pinning: false,
    allowed: [],
    disallowed: [],
  }
  let mut resolve_calls = 0
  let result = scan(target, a_yaml, policy, fetch, resolve_ref_kind=fn(
    _owner,
    _repo,
    _git_ref,
  ) {
    resolve_calls = resolve_calls + 1
    ImmutableRelease
  })
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      assert_eq(resolve_calls, 0)
      assert_eq(r.findings, [])
    }
  }
}

///|
test "scan root path participates in visited-key identity" {
  let target : @papion.ScanTarget = github_target(
    "org",
    "action-a",
    "v1",
    path=Some("subdir"),
  )
  let root_yaml =
    #|name: Action A
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-a@v1
  let fetched_root_yaml =
    #|name: Root Repo Action
    #|runs:
    #|  using: node20
  let mut fetch_count = 0
  let fetch = fn(
    _owner : String,
    _repo : String,
    _git_ref : String,
    _path : String?,
  ) -> Result[String, String] {
    fetch_count = fetch_count + 1
    Ok(fetched_root_yaml)
  }
  let result = scan(target, root_yaml, @papion.Policy::default(), fetch)
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      assert_eq(r.findings.length(), 1)
      // The root path keeps owner/repo@ref distinct from owner/repo/path@ref,
      // so the repo-root action is still fetched once.
      assert_eq(fetch_count, 1)
    }
  }
}

///|
test "scan normalizes action paths in traversal keys" {
  let target : @papion.ScanTarget = github_target(
    "org",
    "action-a",
    "v1",
    path=Some("subdir"),
  )
  let root_yaml =
    #|name: Action A
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-a//subdir/@v1
  let mut fetch_count = 0
  let fetch = fn(
    _owner : String,
    _repo : String,
    _git_ref : String,
    _path : String?,
  ) -> Result[String, String] {
    fetch_count = fetch_count + 1
    Ok(
      (
        #|name: Root Repo Action
        #|runs:
        #|  using: node20
      ),
    )
  }
  let result = scan(target, root_yaml, @papion.Policy::default(), fetch)
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      assert_eq(r.findings.length(), 1)
      assert_eq(fetch_count, 0)
    }
  }
}

///|
test "scan normalizes action paths in transitive context" {
  let target : @papion.ScanTarget = github_target("org", "action-a", "v1")
  let root_yaml =
    #|name: Action A
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-b//subdir/@v1
  let b_yaml =
    #|name: Action B
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-c@v1
  let c_yaml =
    #|name: Action C
    #|runs:
    #|  using: node20
  let fetch = make_fetch_table({
    "org/action-b@v1": b_yaml,
    "org/action-c@v1": c_yaml,
  })
  let result = scan(target, root_yaml, @papion.Policy::default(), fetch)
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      assert_eq(r.findings.length(), 2)
      assert_true(r.findings[1].context == Some("via org/action-b/subdir@v1"))
    }
  }
}

// ---- local ref traversal tests ----

///|
fn local_target(path : String) -> @papion.ScanTarget {
  @papion.Local({ path, })
}

///|
/// Build a fetch_local callback from a table keyed by abs_path.
fn make_local_fetch_table(
  table : Map[String, String],
) -> (String, String) -> Result[(String, String), String] {
  fn(base_dir : String, rel_path : String) -> Result[(String, String), String] {
    let abs_path = "\{base_dir}/\{rel_path}"
    match table.get(abs_path) {
      Some(yaml) => Ok((abs_path, yaml))
      None => Err("local action not found: \{abs_path}")
    }
  }
}

///|
test "scan_workflow traverses local composite and finds GitHub action" {
  let target = local_target("/repo/.github/workflows/ci.yml")
  let workflow_yaml =
    #|name: CI
    #|jobs:
    #|  build:
    #|    runs-on: ubuntu-latest
    #|    steps:
    #|      - uses: ./actions/my-action
  let local_action_yaml =
    #|name: My Action
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: actions/checkout@v4
  let fetch_local = make_local_fetch_table({
    "/repo/.github/workflows/./actions/my-action": local_action_yaml,
  })
  let result = scan_workflow(
    target,
    workflow_yaml,
    @papion.Policy::default(),
    unreachable_fetch,
    fetch_local~,
  )
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      assert_eq(r.findings.length(), 1)
      assert_eq(r.findings[0].rule, "sha-pinning")
      assert_eq(r.findings[0].target, "actions/checkout@v4")
    }
  }
}

///|
test "scan_workflow emits Warn for unresolvable local ref" {
  let target = local_target("/repo/.github/workflows/ci.yml")
  let workflow_yaml =
    #|name: CI
    #|jobs:
    #|  build:
    #|    runs-on: ubuntu-latest
    #|    steps:
    #|      - uses: ./actions/missing
  let fetch_local = fn(
    _base_dir : String,
    rel_path : String,
  ) -> Result[(String, String), String] {
    Err("not found: \{rel_path}")
  }
  let result = scan_workflow(
    target,
    workflow_yaml,
    @papion.Policy::default(),
    unreachable_fetch,
    fetch_local~,
  )
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      assert_eq(r.findings.length(), 1)
      assert_eq(r.findings[0].level, Warn)
      assert_eq(r.findings[0].rule, "local-ref-unresolvable")
      assert_eq(r.findings[0].target, "./actions/missing")
    }
  }
}

///|
test "scan local ref cycle terminates via visited-set" {
  // a references b; b references /repo/abs/a/action.yml (same as root).
  // The host resolves all relative paths to stable abs keys so the engine
  // visited-set catches the cycle on the second visit to a.
  let target = local_target("/repo/abs/a/action.yml")
  let a_yaml =
    #|name: A
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: ./b
  let b_yaml =
    #|name: B
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: ./a
  let abs_b = "/repo/abs/b/action.yml"
  let abs_a = "/repo/abs/a/action.yml"
  let fetch_local = fn(
    _base_dir : String,
    rel_path : String,
  ) -> Result[(String, String), String] {
    if rel_path == "./b" {
      Ok((abs_b, b_yaml))
    } else if rel_path == "./a" {
      // cycle back to a — same abs_path as root, visited set skips
      Ok((abs_a, a_yaml))
    } else {
      Err("unexpected: \{rel_path}")
    }
  }
  let result = scan(
    target,
    a_yaml,
    @papion.Policy::default(),
    unreachable_fetch,
    fetch_local~,
  )
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) =>
      // No GitHub findings, no unresolvable warnings — cycle terminates cleanly
      assert_eq(r.findings.length(), 0)
  }
}

///|
test "scan local ref without base_dir (GitHub root) is silently skipped" {
  // When the engine root is a GitHub target, local refs have no base_dir
  // and the default fetch_local returns an error — but the engine only
  // emits a warning when base_dir is Some(). GitHub roots have base_dir=None.
  let target = github_target("org", "action-a", "v1")
  let yaml_str =
    #|name: My Action
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: ./local/step
    #|    - uses: actions/checkout@v4
  let result = scan(
    target,
    yaml_str,
    @papion.Policy::default(),
    unreachable_fetch,
  )
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      // Only the GitHub ref produces a finding; local ref is silently ignored
      assert_eq(r.findings.length(), 1)
      assert_eq(r.findings[0].rule, "sha-pinning")
      assert_eq(r.findings[0].target, "actions/checkout@v4")
    }
  }
}
