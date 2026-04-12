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
test "FindingLevel json roundtrip" {
  let warn : @papion.FindingLevel = Warn
  let fail_ : @papion.FindingLevel = Fail
  let w_back : @papion.FindingLevel = @json.from_json(warn.to_json())
  let f_back : @papion.FindingLevel = @json.from_json(fail_.to_json())
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
test "ActionYml json roundtrip - node action" {
  let a : @papion.ActionYml = {
    name: "Checkout",
    description: Some("Checkout a repo"),
    runs: { runner: "node20", steps: [] },
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
    runs: { runner: "composite", steps: [step1, step2] },
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
