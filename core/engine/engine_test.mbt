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
