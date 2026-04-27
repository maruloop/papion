///|
test "ActionRef json roundtrip" {
  let r : @papion.ActionRef = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
    path: None,
  }
  let json = @json.parse(r.to_json().stringify())
  let back : @papion.ActionRef = @json.from_json(json)
  assert_eq(r, back)
}

///|
test "ActionRef with path" {
  let r : @papion.ActionRef = {
    owner: "maruloop",
    repo: "papion",
    git_ref: "v1",
    path: Some("action"),
  }
  let json = @json.parse(r.to_json().stringify())
  let back : @papion.ActionRef = @json.from_json(json)
  assert_eq(r, back)
}

///|
test "RefKind json roundtrip" {
  let sha : @papion.RefKind = Sha
  let tag : @papion.RefKind = Tag
  let branch : @papion.RefKind = Branch
  let immutable_release : @papion.RefKind = ImmutableRelease
  let s_json = @json.parse(sha.to_json().stringify())
  let t_json = @json.parse(tag.to_json().stringify())
  let b_json = @json.parse(branch.to_json().stringify())
  let i_json = @json.parse(immutable_release.to_json().stringify())
  let s_back : @papion.RefKind = @json.from_json(s_json)
  let t_back : @papion.RefKind = @json.from_json(t_json)
  let b_back : @papion.RefKind = @json.from_json(b_json)
  let i_back : @papion.RefKind = @json.from_json(i_json)
  assert_eq(sha, s_back)
  assert_eq(tag, t_back)
  assert_eq(branch, b_back)
  assert_eq(immutable_release, i_back)
}

///|
test "FindingLevel json roundtrip" {
  let warn : @papion.FindingLevel = Warn
  let fail_ : @papion.FindingLevel = Fail
  let w_json = @json.parse(warn.to_json().stringify())
  let f_json = @json.parse(fail_.to_json().stringify())
  let w_back : @papion.FindingLevel = @json.from_json(w_json)
  let f_back : @papion.FindingLevel = @json.from_json(f_json)
  assert_eq(warn, w_back)
  assert_eq(fail_, f_back)
}

///|
test "Finding json roundtrip" {
  let f : @papion.Finding = {
    level: Warn,
    rule: "sha-pinning",
    target: "actions/checkout@v4",
    context: None,
    message: "Referenced by tag, not pinned to a SHA.",
    suggestion: Some(
      "actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683",
    ),
  }
  let json = @json.parse(f.to_json().stringify())
  let back : @papion.Finding = @json.from_json(json)
  assert_eq(f, back)
}

///|
test "Finding with context" {
  let f : @papion.Finding = {
    level: Fail,
    rule: "sha-pinning",
    target: "actions/github-script@v7",
    context: Some("composite step \"setup\""),
    message: "Not pinned to a SHA.",
    suggestion: None,
  }
  let json = @json.parse(f.to_json().stringify())
  let back : @papion.Finding = @json.from_json(json)
  assert_eq(f, back)
}

///|
test "Policy json roundtrip" {
  let p : @papion.Policy = {
    sha_pinning: true,
    allowed: ["actions/*", "github/*"],
    disallowed: ["some-org/unsafe-action"],
  }
  let json = @json.parse(p.to_json().stringify())
  let back : @papion.Policy = @json.from_json(json)
  assert_eq(p, back)
}

///|
test "Policy defaults" {
  let p = @papion.Policy::default()
  assert_eq(p.sha_pinning, true)
  assert_eq(p.allowed, ([] : Array[String]))
  assert_eq(p.disallowed, ([] : Array[String]))
}

///|
test "Policy normalized lowercases patterns" {
  let policy : @papion.Policy = {
    sha_pinning: true,
    allowed: ["Actions/*"],
    disallowed: ["Bad-Org/Unsafe"],
  }
  assert_eq(
    policy.normalized(),
    Ok({
      sha_pinning: true,
      allowed: ["actions/*"],
      disallowed: ["bad-org/unsafe"],
    }),
  )
}

///|
test "Policy normalized rejects overlong patterns" {
  let long_pattern = String::make(@papion.max_policy_pattern_len + 1, 'a')
  let policy : @papion.Policy = {
    sha_pinning: true,
    allowed: [long_pattern],
    disallowed: [],
  }
  match policy.normalized() {
    Err(_) => ()
    Ok(_) => fail("expected Err for overlong policy pattern")
  }
}

///|
test "ActionYml json roundtrip - node action" {
  let a : @papion.ActionYml = {
    name: "Checkout",
    description: Some("Checkout a repo"),
    runs: { runner: "node20", steps: None },
  }
  let json = @json.parse(a.to_json().stringify())
  let back : @papion.ActionYml = @json.from_json(json)
  assert_eq(a, back)
}

///|
test "ActionYml json roundtrip - composite action" {
  let step1 : @papion.CompositeStep = {
    uses: Some("actions/checkout@v4"),
    run: None,
    name: Some("checkout"),
  }
  let step2 : @papion.CompositeStep = {
    uses: None,
    run: Some("echo hello"),
    name: Some("greet"),
  }
  let a : @papion.ActionYml = {
    name: "My Composite",
    description: None,
    runs: { runner: "composite", steps: Some([step1, step2]) },
  }
  let json = @json.parse(a.to_json().stringify())
  let back : @papion.ActionYml = @json.from_json(json)
  assert_eq(a, back)
}

///|
test "ScanTarget json roundtrip" {
  let t : @papion.ScanTarget = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
  }
  let json = @json.parse(t.to_json().stringify())
  let back : @papion.ScanTarget = @json.from_json(json)
  assert_eq(t, back)
}

///|
test "Summary json roundtrip" {
  let s : @papion.Summary = { failures: 1, warnings: 2 }
  let json = @json.parse(s.to_json().stringify())
  let back : @papion.Summary = @json.from_json(json)
  assert_eq(s, back)
}

///|
test "ScanResult json roundtrip" {
  let finding : @papion.Finding = {
    level: Warn,
    rule: "sha-pinning",
    target: "actions/checkout@v4",
    context: None,
    message: "Referenced by tag, not pinned to a SHA.",
    suggestion: Some(
      "actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683",
    ),
  }
  let r : @papion.ScanResult = {
    target: { owner: "actions", repo: "checkout", git_ref: "v4" },
    findings: [finding],
    summary: { failures: 0, warnings: 1 },
  }
  let json = @json.parse(r.to_json().stringify())
  let back : @papion.ScanResult = @json.from_json(json)
  assert_eq(r, back)
}
