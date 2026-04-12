///|
test "parse_action_ref basic owner/repo@ref" {
  let result = parse_action_ref("actions/checkout@v4")
  assert_eq(
    result,
    Ok({ owner: "actions", repo: "checkout", git_ref: "v4", path: None }),
  )
}

///|
test "parse_action_ref with sha" {
  let result = parse_action_ref(
    "actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683",
  )
  assert_eq(
    result,
    Ok({
      owner: "actions",
      repo: "checkout",
      git_ref: "11bd71901bbe5b1630ceea73d27597364c9af683",
      path: None,
    }),
  )
}

///|
test "parse_action_ref with path" {
  let result = parse_action_ref("maruloop/papion/action@v1")
  assert_eq(
    result,
    Ok({
      owner: "maruloop",
      repo: "papion",
      git_ref: "v1",
      path: Some("action"),
    }),
  )
}

///|
test "parse_action_ref with deep path" {
  let result = parse_action_ref("org/repo/some/deep/path@v2")
  assert_eq(
    result,
    Ok({
      owner: "org",
      repo: "repo",
      git_ref: "v2",
      path: Some("some/deep/path"),
    }),
  )
}

///|
test "parse_action_ref error missing @" {
  let result = parse_action_ref("actions/checkout")
  assert_eq(result, Err("missing '@' in uses string: \"actions/checkout\""))
}

///|
test "parse_action_ref error empty owner" {
  let result = parse_action_ref("/repo@v4")
  assert_eq(result, Err("empty owner in uses string: \"/repo@v4\""))
}

///|
test "parse_action_ref error empty repo" {
  let result = parse_action_ref("owner/@v4")
  assert_eq(result, Err("empty repo in uses string: \"owner/@v4\""))
}

///|
test "parse_action_ref error empty ref" {
  let result = parse_action_ref("owner/repo@")
  assert_eq(result, Err("empty ref in uses string: \"owner/repo@\""))
}

///|
test "parse_action_yml minimal node action" {
  let json_str =
    #|{"name":"Setup Node","runs":{"using":"node20"}}
  let result = parse_action_yml(json_str)
  assert_eq(
    result,
    Ok({
      name: "Setup Node",
      description: None,
      runs: { runner: "node20", steps: None },
    }),
  )
}

///|
test "parse_action_yml composite action with steps" {
  let json_str =
    #|{"name":"My Action","description":"does things","runs":{"using":"composite","steps":[{"uses":"actions/checkout@v4","name":"checkout"},{"run":"echo hello"}]}}
  let result = parse_action_yml(json_str)
  assert_eq(
    result,
    Ok({
      name: "My Action",
      description: Some("does things"),
      runs: {
        runner: "composite",
        steps: Some([
          {
            uses: Some("actions/checkout@v4"),
            run: None,
            name: Some("checkout"),
          },
          { uses: None, run: Some("echo hello"), name: None },
        ]),
      },
    }),
  )
}

///|
test "parse_action_yml malformed JSON" {
  let result = parse_action_yml("not json at all")
  match result {
    Err(_) => ()
    Ok(_) => fail("expected Err for malformed JSON")
  }
}

///|
test "extract_refs from composite action" {
  let yml : @papion.ActionYml = {
    name: "My Action",
    description: None,
    runs: {
      runner: "composite",
      steps: Some([
        { uses: Some("actions/checkout@v4"), run: None, name: None },
        { uses: None, run: Some("echo hi"), name: None },
        { uses: Some("actions/setup-node@v4"), run: None, name: None },
      ]),
    },
  }
  let refs = extract_refs(yml)
  assert_eq(refs.length(), 2)
  assert_eq(refs[0], {
    owner: "actions",
    repo: "checkout",
    git_ref: "v4",
    path: None,
  })
  assert_eq(refs[1], {
    owner: "actions",
    repo: "setup-node",
    git_ref: "v4",
    path: None,
  })
}

///|
test "extract_refs from node action returns empty" {
  let yml : @papion.ActionYml = {
    name: "Node Action",
    description: None,
    runs: { runner: "node20", steps: None },
  }
  let refs = extract_refs(yml)
  assert_eq(refs, [])
}
