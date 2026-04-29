///|
fn make_target(
  owner : String,
  repo : String,
  git_ref : String,
) -> @papion.ScanTarget {
  { owner, repo, git_ref, path: None }
}

///|
fn warn_finding(target : String, message : String) -> @papion.Finding {
  {
    level: Warn,
    rule: "sha-pinning",
    target,
    context: None,
    message,
    suggestion: None,
  }
}

///|
fn fail_finding(target : String, message : String) -> @papion.Finding {
  {
    level: Fail,
    rule: "sha-pinning",
    target,
    context: None,
    message,
    suggestion: None,
  }
}

///|
test "format_human zero findings" {
  let result : @papion.ScanResult = {
    target: make_target("actions", "checkout", "v4"),
    findings: [],
    summary: { failures: 0, warnings: 0 },
  }
  assert_eq(format_human(result), "No findings")
}

///|
test "format_human single warning" {
  let result : @papion.ScanResult = {
    target: make_target("actions", "checkout", "v4"),
    findings: [
      warn_finding("actions/checkout@v4", "action ref is not pinned to a SHA"),
    ],
    summary: { failures: 0, warnings: 1 },
  }
  let output = format_human(result)
  assert_eq(
    output, "  WARN  actions/checkout@v4\n        action ref is not pinned to a SHA\n\n1 finding  (0 failures, 1 warning)",
  )
}

///|
test "format_human single failure" {
  let result : @papion.ScanResult = {
    target: make_target("actions", "checkout", "v4"),
    findings: [
      fail_finding("actions/checkout@v4", "action is not in the allowed list"),
    ],
    summary: { failures: 1, warnings: 0 },
  }
  let output = format_human(result)
  assert_eq(
    output, "  FAIL  actions/checkout@v4\n        action is not in the allowed list\n\n1 finding  (1 failure, 0 warnings)",
  )
}

///|
test "format_human with context" {
  let finding : @papion.Finding = {
    level: Fail,
    rule: "sha-pinning",
    target: "actions/github-script@v7",
    context: Some("composite step \"setup\""),
    message: "Not pinned to a SHA.",
    suggestion: None,
  }
  let result : @papion.ScanResult = {
    target: make_target("my-org", "my-action", "main"),
    findings: [finding],
    summary: { failures: 1, warnings: 0 },
  }
  let output = format_human(result)
  assert_eq(
    output, "  FAIL  actions/github-script@v7 (composite step \"setup\")\n        Not pinned to a SHA.\n\n1 finding  (1 failure, 0 warnings)",
  )
}

///|
test "format_human with suggestion" {
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
  let result : @papion.ScanResult = {
    target: make_target("actions", "checkout", "v4"),
    findings: [finding],
    summary: { failures: 0, warnings: 1 },
  }
  let output = format_human(result)
  assert_eq(
    output, "  WARN  actions/checkout@v4\n        Referenced by tag, not pinned to a SHA.\n        Tip: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683\n\n1 finding  (0 failures, 1 warning)",
  )
}

///|
test "format_human multiple findings" {
  let result : @papion.ScanResult = {
    target: make_target("my-org", "my-action", "main"),
    findings: [
      warn_finding(
        "actions/checkout@v4", "Referenced by tag, not pinned to a SHA.",
      ),
      fail_finding("actions/github-script@v7", "Not pinned to a SHA."),
    ],
    summary: { failures: 1, warnings: 1 },
  }
  let output = format_human(result)
  assert_eq(
    output, "  WARN  actions/checkout@v4\n        Referenced by tag, not pinned to a SHA.\n\n  FAIL  actions/github-script@v7\n        Not pinned to a SHA.\n\n2 findings  (1 failure, 1 warning)",
  )
}

///|
test "format_human plural failures and warnings" {
  let result : @papion.ScanResult = {
    target: make_target("my-org", "my-action", "main"),
    findings: [
      fail_finding("actions/checkout@v4", "msg1"),
      fail_finding("actions/setup-node@v4", "msg2"),
      warn_finding("actions/cache@v3", "msg3"),
      warn_finding("actions/upload-artifact@v3", "msg4"),
    ],
    summary: { failures: 2, warnings: 2 },
  }
  let output = format_human(result)
  assert_true(output.has_suffix("4 findings  (2 failures, 2 warnings)"))
}

///|
fn get_str(json : Json, key : String) -> String? {
  match json {
    Object(obj) =>
      match obj.get(key) {
        Some(String(s)) => Some(s)
        _ => None
      }
    _ => None
  }
}

///|
fn get_num(json : Json, key : String) -> Double? {
  match json {
    Object(obj) =>
      match obj.get(key) {
        Some(Number(n, ..)) => Some(n)
        _ => None
      }
    _ => None
  }
}

///|
test "format_json zero findings" {
  let result : @papion.ScanResult = {
    target: make_target("actions", "checkout", "v4"),
    findings: [],
    summary: { failures: 0, warnings: 0 },
  }
  let output = format_json(result)
  let parsed = @json.parse(output)
  assert_eq(get_str(parsed, "target"), Some("actions/checkout@v4"))
  assert_eq(get_str(parsed, "ref"), Some("v4"))
  match parsed {
    Object(obj) =>
      match obj.get("findings") {
        Some(Array(arr)) => assert_eq(arr.length(), 0)
        _ => fail("expected findings array")
      }
    _ => fail("expected JSON object")
  }
  match parsed {
    Object(obj) =>
      match obj.get("summary") {
        Some(s) => {
          assert_eq(get_num(s, "failures"), Some(0.0))
          assert_eq(get_num(s, "warnings"), Some(0.0))
        }
        _ => fail("expected summary")
      }
    _ => fail("expected JSON object")
  }
}

///|
test "format_json finding with all fields" {
  let finding : @papion.Finding = {
    level: Warn,
    rule: "sha-pinning",
    target: "actions/checkout@v4",
    context: Some("step context"),
    message: "not pinned",
    suggestion: Some("pin to sha"),
  }
  let result : @papion.ScanResult = {
    target: make_target("actions", "checkout", "v4"),
    findings: [finding],
    summary: { failures: 0, warnings: 1 },
  }
  let output = format_json(result)
  let parsed = @json.parse(output)
  match parsed {
    Object(obj) =>
      match obj.get("findings") {
        Some(Array(arr)) => {
          assert_eq(arr.length(), 1)
          assert_eq(get_str(arr[0], "level"), Some("warn"))
          assert_eq(get_str(arr[0], "rule"), Some("sha-pinning"))
          assert_eq(
            get_str(arr[0], "target"),
            Some("actions/checkout@v4"),
          )
          assert_eq(get_str(arr[0], "context"), Some("step context"))
          assert_eq(get_str(arr[0], "message"), Some("not pinned"))
          assert_eq(get_str(arr[0], "suggestion"), Some("pin to sha"))
        }
        _ => fail("expected findings array")
      }
    _ => fail("expected JSON object")
  }
}

///|
test "format_json finding omits absent optional fields" {
  let finding : @papion.Finding = {
    level: Fail,
    rule: "allowed-list",
    target: "third-party/action@v1",
    context: None,
    message: "not in allowed list",
    suggestion: None,
  }
  let result : @papion.ScanResult = {
    target: make_target("actions", "checkout", "v4"),
    findings: [finding],
    summary: { failures: 1, warnings: 0 },
  }
  let output = format_json(result)
  let parsed = @json.parse(output)
  match parsed {
    Object(obj) =>
      match obj.get("findings") {
        Some(Array(arr)) =>
          match arr[0] {
            Object(finding_obj) => {
              assert_eq(get_str(arr[0], "level"), Some("fail"))
              match finding_obj.get("context") {
                None => ()
                Some(_) => fail("expected no context field")
              }
              match finding_obj.get("suggestion") {
                None => ()
                Some(_) => fail("expected no suggestion field")
              }
            }
            _ => fail("expected finding object")
          }
        _ => fail("expected findings array")
      }
    _ => fail("expected JSON object")
  }
}

///|
test "format_json output is valid JSON" {
  let result : @papion.ScanResult = {
    target: make_target(
      "my-org", "my-action", "abc123def456abc123def456abc123def456abc1",
    ),
    findings: [
      {
        level: Fail,
        rule: "sha-pinning",
        target: "actions/checkout@v4",
        context: Some("checkout step"),
        message: "not pinned",
        suggestion: None,
      },
    ],
    summary: { failures: 1, warnings: 0 },
  }
  let output = format_json(result)
  // Parsing should not throw
  let _ = @json.parse(output)
  assert_true(true)
}
