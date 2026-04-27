///|
test "scan unpinned ref produces sha-pinning failure" {
  let target : @papion.ScanTarget = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
  }
  let yaml_str =
    #|name: My Action
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: actions/checkout@v4
  let result = scan(target, yaml_str, @papion.Policy::default())
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
  let target : @papion.ScanTarget = {
    owner: "actions",
    repo: "checkout",
    git_ref: "11bd71901bbe5b1630ceea73d27597364c9af683",
  }
  let yaml_str =
    #|name: My Action
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
  let result = scan(target, yaml_str, @papion.Policy::default())
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
  let target : @papion.ScanTarget = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
  }
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
  let result = scan(target, yaml_str, policy)
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
  let target : @papion.ScanTarget = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
  }
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
  let result = scan(target, yaml_str, policy)
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
  let target : @papion.ScanTarget = {
    owner: "actions",
    repo: "setup-node",
    git_ref: "v4",
  }
  let yaml_str =
    #|name: Setup Node
    #|runs:
    #|  using: node20
  let result = scan(target, yaml_str, @papion.Policy::default())
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
  let target : @papion.ScanTarget = {
    owner: "my-org",
    repo: "my-action",
    git_ref: "main",
  }
  let yaml_str =
    #|name: Multi Step
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: actions/checkout@v4
    #|    - uses: actions/setup-node@v4
  let result = scan(target, yaml_str, @papion.Policy::default())
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
  let target : @papion.ScanTarget = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
  }
  let result = scan(target, ":\t bad\t:\n\t", @papion.Policy::default())
  match result {
    Err(_) => ()
    Ok(_) => fail("expected error for invalid YAML")
  }
}

///|
test "scan result target matches input" {
  let target : @papion.ScanTarget = {
    owner: "my-org",
    repo: "my-action",
    git_ref: "abc123",
  }
  let yaml_str =
    #|name: My Action
    #|runs:
    #|  using: node20
  let result = scan(target, yaml_str, @papion.Policy::default())
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => assert_eq(r.target, target)
  }
}

///|
test "scan uses injected ref kind resolver" {
  let target : @papion.ScanTarget = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
  }
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
  let result = scan(target, yaml_str, @papion.Policy::default(), resolve_ref_kind=fn(
    owner,
    repo,
    git_ref,
  ) {
    calls = calls + 1
    resolved_owner = owner
    resolved_repo = repo
    resolved_git_ref = git_ref
    ImmutableRelease
  })
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
test "scan skips ref kind resolver when sha_pinning is false" {
  let target : @papion.ScanTarget = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
  }
  let yaml_str =
    #|name: My Action
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: actions/checkout@v4
  let mut calls = 0
  let policy : @papion.Policy = {
    sha_pinning: false,
    allowed: [],
    disallowed: [],
  }
  let result = scan(target, yaml_str, policy, resolve_ref_kind=fn(_, _, _) {
    calls = calls + 1
    ImmutableRelease
  })
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(_) => assert_eq(calls, 0)
  }
}

///|
test "scan normalizes policy patterns before evaluation" {
  let target : @papion.ScanTarget = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
  }
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
  let result = scan(target, yaml_str, policy)
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => assert_eq(r.findings, [])
  }
}

///|
test "scan rejects overlong policy patterns" {
  let target : @papion.ScanTarget = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
  }
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
  match scan(target, yaml_str, policy) {
    Err(_) => ()
    Ok(_) => fail("expected Err for overlong policy pattern")
  }
}

// Helper: build a fetch table for recursive tests.
// Each entry maps "owner/repo@ref" (or "owner/repo/path@ref") to a YAML string.

///|
fn make_fetch_table(
  entries : Array[(String, String)],
) -> (String, String, String, String?) -> Result[String, String] {
  let table : Map[String, String] = {}
  for entry in entries {
    table[entry.0] = entry.1
  }
  fn(owner, repo, git_ref, path) {
    let key = match path {
      None => "\{owner}/\{repo}@\{git_ref}"
      Some(p) => "\{owner}/\{repo}/\{p}@\{git_ref}"
    }
    match table.get(key) {
      Some(yaml) => Ok(yaml)
      None => Err("not found: \{key}")
    }
  }
}

///|
test "recursive scan traverses direct dependency" {
  let target : @papion.ScanTarget = {
    owner: "org",
    repo: "action-a",
    git_ref: "v1",
  }
  let root_yaml =
    #|name: Action A
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-b@v2
  let dep_yaml =
    #|name: Action B
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: third-party/unsafe@branch-name
  let fetch = make_fetch_table([("org/action-b@v2", dep_yaml)])
  let result = scan(
    target,
    root_yaml,
    @papion.Policy::default(),
    fetch_action_yml=Some(fetch),
  )
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      assert_eq(r.summary.failures, 2)
      // root finding: org/action-b@v2 (branch)
      // transitive finding: third-party/unsafe@branch-name (branch)
      let has_context = r.findings.iter().any(fn(f) { f.context is Some(_) })
      assert_eq(has_context, true)
      let transitive = r.findings
        .iter()
        .filter(fn(f) { f.context is Some(_) })
        .collect()
      assert_eq(transitive.length(), 1)
      assert_eq(transitive[0].context, Some("org/action-b@v2"))
    }
  }
}

///|
test "recursive scan shows full chain for deep dependency" {
  let target : @papion.ScanTarget = {
    owner: "org",
    repo: "action-a",
    git_ref: "v1",
  }
  let yaml_a =
    #|name: Action A
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-b@v1
  let yaml_b =
    #|name: Action B
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-c@v1
  let yaml_c =
    #|name: Action C
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: third-party/leaf@main
  let fetch = make_fetch_table([
    ("org/action-b@v1", yaml_b),
    ("org/action-c@v1", yaml_c),
  ])
  let result = scan(
    target,
    yaml_a,
    @papion.Policy::default(),
    fetch_action_yml=Some(fetch),
  )
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      let deep = r.findings
        .iter()
        .filter(fn(f) {
          match f.context {
            Some(ctx) => ctx.contains(">")
            None => false
          }
        })
        .collect()
      assert_eq(deep.length(), 1)
      assert_eq(deep[0].context, Some("org/action-b@v1 > org/action-c@v1"))
    }
  }
}

///|
test "recursive scan fetches shared dependency only once" {
  let target : @papion.ScanTarget = {
    owner: "org",
    repo: "action-a",
    git_ref: "v1",
  }
  let yaml_a =
    #|name: Action A
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-b@v1
    #|    - uses: org/action-c@v1
  let yaml_b =
    #|name: Action B
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/shared@v1
  let yaml_c =
    #|name: Action C
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/shared@v1
  let yaml_shared =
    #|name: Shared
    #|runs:
    #|  using: node20
  let mut fetch_count = 0
  fn fetch(owner, repo, git_ref, path) {
    let key = match path {
      None => "\{owner}/\{repo}@\{git_ref}"
      Some(p) => "\{owner}/\{repo}/\{p}@\{git_ref}"
    }
    if key == "org/shared@v1" {
      fetch_count = fetch_count + 1
    }
    let table = make_fetch_table([
      ("org/action-b@v1", yaml_b),
      ("org/action-c@v1", yaml_c),
      ("org/shared@v1", yaml_shared),
    ])
    table(owner, repo, git_ref, path)
  }

  let result = scan(
    target,
    yaml_a,
    @papion.Policy::default(),
    fetch_action_yml=Some(fetch),
  )
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(_) => assert_eq(fetch_count, 1)
  }
}

///|
test "recursive scan terminates on simple cycle" {
  let target : @papion.ScanTarget = {
    owner: "org",
    repo: "action-a",
    git_ref: "v1",
  }
  let yaml_a =
    #|name: Action A
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-b@v1
  let yaml_b =
    #|name: Action B
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-a@v1
  let fetch = make_fetch_table([
    ("org/action-b@v1", yaml_b),
    ("org/action-a@v1", yaml_a),
  ])
  let result = scan(
    target,
    yaml_a,
    @papion.Policy::default(),
    fetch_action_yml=Some(fetch),
  )
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => assert_eq(r.summary.failures > 0, true)
  }
}

///|
test "recursive scan terminates on longer cycle" {
  let target : @papion.ScanTarget = {
    owner: "org",
    repo: "action-a",
    git_ref: "v1",
  }
  let yaml_a =
    #|name: A
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-b@v1
  let yaml_b =
    #|name: B
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-c@v1
  let yaml_c =
    #|name: C
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-a@v1
  let fetch = make_fetch_table([
    ("org/action-b@v1", yaml_b),
    ("org/action-c@v1", yaml_c),
    ("org/action-a@v1", yaml_a),
  ])
  let result = scan(
    target,
    yaml_a,
    @papion.Policy::default(),
    fetch_action_yml=Some(fetch),
  )
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(_) => ()
  }
}

///|
test "recursive scan without fetch callback processes root only" {
  let target : @papion.ScanTarget = {
    owner: "org",
    repo: "action-a",
    git_ref: "v1",
  }
  let yaml_a =
    #|name: Action A
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-b@branch-ref
  let result = scan(target, yaml_a, @papion.Policy::default())
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      assert_eq(r.summary.failures, 1)
      assert_eq(r.findings[0].context, None)
    }
  }
}

///|
test "recursive scan root parse error propagates" {
  let target : @papion.ScanTarget = {
    owner: "org",
    repo: "action-a",
    git_ref: "v1",
  }
  let result = scan(
    target,
    ":\t bad yaml",
    @papion.Policy::default(),
    fetch_action_yml=Some(make_fetch_table([])),
  )
  match result {
    Err(_) => ()
    Ok(_) => fail("expected error for invalid root YAML")
  }
}

///|
test "recursive scan transitive parse error is skipped" {
  let target : @papion.ScanTarget = {
    owner: "org",
    repo: "action-a",
    git_ref: "v1",
  }
  let yaml_a =
    #|name: Action A
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: org/action-b@v1
  let fetch = make_fetch_table([("org/action-b@v1", ":\t invalid")])
  let result = scan(
    target,
    yaml_a,
    @papion.Policy::default(),
    fetch_action_yml=Some(fetch),
  )
  match result {
    Err(e) => fail("unexpected error: \{e}")
    Ok(r) => {
      assert_eq(r.summary.failures, 1)
      assert_eq(r.findings[0].context, None)
    }
  }
}
