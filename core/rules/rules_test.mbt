///|
test "classify_ref 40-char lowercase hex is Sha" {
  let sha = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
  assert_eq(classify_ref(sha), @papion.RefKind::Sha)
}

///|
test "classify_ref 40-char uppercase hex is Sha" {
  let sha = "A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2"
  assert_eq(classify_ref(sha), @papion.RefKind::Sha)
}

///|
test "classify_ref 40-char mixed-case hex is Sha" {
  let sha = "a1B2c3D4e5F6a1B2c3D4e5F6a1B2c3D4e5F6a1B2"
  assert_eq(classify_ref(sha), @papion.RefKind::Sha)
}

///|
test "classify_ref tag-like ref is Branch" {
  assert_eq(classify_ref("v4"), @papion.RefKind::Branch)
}

///|
test "classify_ref branch-like ref is Branch" {
  assert_eq(classify_ref("main"), @papion.RefKind::Branch)
}

///|
test "classify_ref 39-char hex is Branch" {
  let short = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b"
  assert_eq(classify_ref(short), @papion.RefKind::Branch)
}

///|
test "classify_ref 41-char hex is Branch" {
  let long = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b20"
  assert_eq(classify_ref(long), @papion.RefKind::Branch)
}

///|
test "classify_ref empty string is Branch" {
  assert_eq(classify_ref(""), @papion.RefKind::Branch)
}

///|
test "check_sha_pinning SHA ref passes" {
  let action_ref : @papion.ActionRef = {
    owner: "actions",
    repo: "checkout",
    git_ref: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
    path: None,
  }
  let policy = @papion.Policy::default()
  assert_eq(check_sha_pinning(action_ref, policy), [])
}

///|
test "check_sha_pinning non-SHA ref fails" {
  let action_ref : @papion.ActionRef = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
    path: None,
  }
  let policy = @papion.Policy::default()
  let findings = check_sha_pinning(action_ref, policy)
  assert_eq(findings.length(), 1)
  assert_eq(findings[0].level, @papion.FindingLevel::Fail)
  assert_eq(findings[0].rule, "sha-pinning")
  assert_eq(findings[0].target, "actions/checkout@v4")
}

///|
test "check_sha_pinning disabled skips" {
  let action_ref : @papion.ActionRef = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
    path: None,
  }
  let policy : @papion.Policy = {
    sha_pinning: false,
    allowed: [],
    disallowed: [],
  }
  assert_eq(check_sha_pinning(action_ref, policy), [])
}

///|
test "check_allowed empty list passes all" {
  let action_ref : @papion.ActionRef = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
    path: None,
  }
  let policy : @papion.Policy = {
    sha_pinning: true,
    allowed: [],
    disallowed: [],
  }
  assert_eq(check_allowed(action_ref, policy), [])
}

///|
test "check_allowed matching pattern passes" {
  let action_ref : @papion.ActionRef = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
    path: None,
  }
  let policy : @papion.Policy = {
    sha_pinning: true,
    allowed: ["actions/*"],
    disallowed: [],
  }
  assert_eq(check_allowed(action_ref, policy), [])
}

///|
test "check_allowed no match fails" {
  let action_ref : @papion.ActionRef = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
    path: None,
  }
  let policy : @papion.Policy = {
    sha_pinning: true,
    allowed: ["github/*"],
    disallowed: [],
  }
  let findings = check_allowed(action_ref, policy)
  assert_eq(findings.length(), 1)
  assert_eq(findings[0].level, @papion.FindingLevel::Fail)
  assert_eq(findings[0].rule, "allowed-list")
  assert_eq(findings[0].target, "actions/checkout@v4")
}

///|
test "check_disallowed matching pattern fails" {
  let action_ref : @papion.ActionRef = {
    owner: "bad-org",
    repo: "evil-action",
    git_ref: "v1",
    path: None,
  }
  let policy : @papion.Policy = {
    sha_pinning: true,
    allowed: [],
    disallowed: ["bad-org/*"],
  }
  let findings = check_disallowed(action_ref, policy)
  assert_eq(findings.length(), 1)
  assert_eq(findings[0].level, @papion.FindingLevel::Fail)
  assert_eq(findings[0].rule, "disallowed-list")
  assert_eq(findings[0].target, "bad-org/evil-action@v1")
}

///|
test "check_disallowed no match passes" {
  let action_ref : @papion.ActionRef = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
    path: None,
  }
  let policy : @papion.Policy = {
    sha_pinning: true,
    allowed: [],
    disallowed: ["bad-org/*"],
  }
  assert_eq(check_disallowed(action_ref, policy), [])
}

///|
test "evaluate SHA ref empty policy produces no findings" {
  let action_ref : @papion.ActionRef = {
    owner: "actions",
    repo: "checkout",
    git_ref: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
    path: None,
  }
  let policy = @papion.Policy::default()
  assert_eq(evaluate(action_ref, policy), [])
}

///|
test "evaluate non-SHA ref default policy produces sha-pinning finding" {
  let action_ref : @papion.ActionRef = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
    path: None,
  }
  let policy = @papion.Policy::default()
  let findings = evaluate(action_ref, policy)
  assert_eq(findings.length(), 1)
  assert_eq(findings[0].rule, "sha-pinning")
}

///|
test "evaluate non-SHA ref not in allowed list produces two findings" {
  let action_ref : @papion.ActionRef = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
    path: None,
  }
  let policy : @papion.Policy = {
    sha_pinning: true,
    allowed: ["github/*"],
    disallowed: [],
  }
  let findings = evaluate(action_ref, policy)
  assert_eq(findings.length(), 2)
  assert_eq(findings[0].rule, "sha-pinning")
  assert_eq(findings[1].rule, "allowed-list")
}

///|
test "evaluate action in both allowed and disallowed produces disallowed finding" {
  let action_ref : @papion.ActionRef = {
    owner: "actions",
    repo: "checkout",
    git_ref: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
    path: None,
  }
  let policy : @papion.Policy = {
    sha_pinning: true,
    allowed: ["actions/*"],
    disallowed: ["actions/*"],
  }
  let findings = evaluate(action_ref, policy)
  assert_eq(findings.length(), 1)
  assert_eq(findings[0].rule, "disallowed-list")
}

///|
test "check_sha_pinning with path includes path in target" {
  let action_ref : @papion.ActionRef = {
    owner: "myorg",
    repo: "actions",
    git_ref: "v2",
    path: Some("deploy"),
  }
  let policy = @papion.Policy::default()
  let findings = check_sha_pinning(action_ref, policy)
  assert_eq(findings.length(), 1)
  assert_eq(findings[0].target, "myorg/actions/deploy@v2")
}

///|
test "evaluate with path includes path in finding target" {
  let action_ref : @papion.ActionRef = {
    owner: "myorg",
    repo: "actions",
    git_ref: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
    path: Some("sub"),
  }
  let policy : @papion.Policy = {
    sha_pinning: true,
    allowed: ["github/*"],
    disallowed: [],
  }
  let findings = evaluate(action_ref, policy)
  assert_eq(findings.length(), 1)
  assert_eq(findings[0].rule, "allowed-list")
  assert_eq(
    findings[0].target,
    "myorg/actions/sub@a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
  )
}

///|
test "evaluate all passing produces no findings" {
  let action_ref : @papion.ActionRef = {
    owner: "actions",
    repo: "checkout",
    git_ref: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
    path: None,
  }
  let policy : @papion.Policy = {
    sha_pinning: true,
    allowed: ["actions/*"],
    disallowed: ["bad-org/*"],
  }
  assert_eq(evaluate(action_ref, policy), [])
}
