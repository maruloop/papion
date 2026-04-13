///|
test "parse_policy full config" {
  let json_str =
    #|{"sha_pinning":false,"allowed":["actions/*","github/*"],"disallowed":["bad-org/unsafe"]}
  let result = parse_policy(json_str)
  assert_eq(
    result,
    Ok({
      sha_pinning: false,
      allowed: ["actions/*", "github/*"],
      disallowed: ["bad-org/unsafe"],
    }),
  )
}

///|
test "parse_policy defaults on empty object" {
  let result = parse_policy("{}")
  assert_eq(result, Ok({ sha_pinning: true, allowed: [], disallowed: [] }))
}

///|
test "parse_policy malformed JSON" {
  let result = parse_policy("not json")
  match result {
    Err(_) => ()
    Ok(_) => fail("expected Err for malformed JSON")
  }
}

///|
test "parse_policy rejects non-object top-level JSON" {
  match parse_policy("[]") {
    Err(_) => ()
    Ok(_) => fail("expected Err for non-object top-level JSON")
  }
}

///|
test "parse_policy rejects non-bool sha_pinning" {
  let json_str =
    #|{"sha_pinning":"false"}
  match parse_policy(json_str) {
    Err(_) => ()
    Ok(_) => fail("expected Err for non-bool sha_pinning")
  }
}

///|
test "parse_policy rejects non-array allowed" {
  let json_str =
    #|{"allowed":"actions/*"}
  match parse_policy(json_str) {
    Err(_) => ()
    Ok(_) => fail("expected Err for non-array allowed")
  }
}

///|
test "parse_policy rejects non-array disallowed" {
  let json_str =
    #|{"disallowed":"bad-org/unsafe"}
  match parse_policy(json_str) {
    Err(_) => ()
    Ok(_) => fail("expected Err for non-array disallowed")
  }
}

///|
test "parse_policy rejects non-string entry in allowed" {
  let json_str =
    #|{"allowed":["actions/*",1]}
  match parse_policy(json_str) {
    Err(_) => ()
    Ok(_) => fail("expected Err for non-string entry in allowed")
  }
}

///|
test "parse_policy rejects non-string entry in disallowed" {
  let json_str =
    #|{"disallowed":["bad-org/unsafe",false]}
  match parse_policy(json_str) {
    Err(_) => ()
    Ok(_) => fail("expected Err for non-string entry in disallowed")
  }
}

///|
test "parse_policy nested policy key full config" {
  let json_str =
    #|{"policy":{"sha_pinning":false,"allowed":["actions/*"],"disallowed":["bad-org/unsafe"]}}
  let result = parse_policy(json_str)
  assert_eq(
    result,
    Ok({
      sha_pinning: false,
      allowed: ["actions/*"],
      disallowed: ["bad-org/unsafe"],
    }),
  )
}

///|
test "parse_policy nested policy key empty object uses defaults" {
  let json_str =
    #|{"policy":{}}
  let result = parse_policy(json_str)
  assert_eq(result, Ok({ sha_pinning: true, allowed: [], disallowed: [] }))
}

///|
test "matches_allowed empty list passes all" {
  let policy : @papion.Policy = {
    sha_pinning: true,
    allowed: [],
    disallowed: [],
  }
  let action_ref : @papion.ActionRef = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
    path: None,
  }
  assert_eq(matches_allowed(policy, action_ref), true)
}

///|
test "matches_allowed with matching pattern" {
  let policy : @papion.Policy = {
    sha_pinning: true,
    allowed: ["actions/*"],
    disallowed: [],
  }
  let action_ref : @papion.ActionRef = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
    path: None,
  }
  assert_eq(matches_allowed(policy, action_ref), true)
}

///|
test "matches_allowed case-insensitive" {
  let policy : @papion.Policy = {
    sha_pinning: true,
    allowed: ["Actions/*"],
    disallowed: [],
  }
  let action_ref : @papion.ActionRef = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
    path: None,
  }
  assert_eq(matches_allowed(policy, action_ref), true)
}

///|
test "matches_allowed no match returns false" {
  let policy : @papion.Policy = {
    sha_pinning: true,
    allowed: ["github/*"],
    disallowed: [],
  }
  let action_ref : @papion.ActionRef = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
    path: None,
  }
  assert_eq(matches_allowed(policy, action_ref), false)
}

///|
test "matches_disallowed with matching pattern" {
  let policy : @papion.Policy = {
    sha_pinning: true,
    allowed: [],
    disallowed: ["bad-org/*"],
  }
  let action_ref : @papion.ActionRef = {
    owner: "bad-org",
    repo: "evil-action",
    git_ref: "v1",
    path: None,
  }
  assert_eq(matches_disallowed(policy, action_ref), true)
}

///|
test "matches_disallowed case-insensitive" {
  let policy : @papion.Policy = {
    sha_pinning: true,
    allowed: [],
    disallowed: ["Bad-Org/*"],
  }
  let action_ref : @papion.ActionRef = {
    owner: "bad-org",
    repo: "evil-action",
    git_ref: "v1",
    path: None,
  }
  assert_eq(matches_disallowed(policy, action_ref), true)
}

///|
test "matches_disallowed no match returns false" {
  let policy : @papion.Policy = {
    sha_pinning: true,
    allowed: [],
    disallowed: ["other-org/*"],
  }
  let action_ref : @papion.ActionRef = {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
    path: None,
  }
  assert_eq(matches_disallowed(policy, action_ref), false)
}
