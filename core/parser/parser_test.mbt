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
test "parse_action_ref error relative path" {
  let result = parse_action_ref("./some/local/action")
  assert_eq(
    result,
    Err("relative path action not supported: \"./some/local/action\""),
  )
}

///|
test "parse_action_ref error empty path" {
  let result = parse_action_ref("owner/repo/@ref")
  assert_eq(result, Err("empty path in uses string: \"owner/repo/@ref\""))
}

///|
test "parse_action_yml minimal node action" {
  let yaml_str =
    #|name: Setup Node
    #|runs:
    #|  using: node20
  let result = parse_action_yml(yaml_str)
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
  let yaml_str =
    #|name: My Action
    #|description: does things
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: actions/checkout@v4
    #|      name: checkout
    #|    - run: echo hello
  let result = parse_action_yml(yaml_str)
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
test "parse_action_yml malformed YAML" {
  let result = parse_action_yml(":\t bad yaml\t:\n\t")
  match result {
    Err(_) => ()
    Ok(_) => fail("expected Err for malformed YAML")
  }
}

///|
test "parse_action_yml multi-document YAML rejected" {
  let yaml_str =
    #|name: My Action
    #|runs:
    #|  using: node20
    #|---
    #|name: Second Document
    #|runs:
    #|  using: node20
  let result = parse_action_yml(yaml_str)
  assert_eq(result, Err("expected exactly one YAML document in action.yml"))
}

///|
test "parse_action_yml invalid description type" {
  let yaml_str =
    #|name: My Action
    #|description:
    #|  nested: map
    #|runs:
    #|  using: node20
  let result = parse_action_yml(yaml_str)
  assert_eq(result, Err("invalid 'description' field: expected string"))
}

///|
test "parse_action_yml invalid steps type" {
  let yaml_str =
    #|name: My Action
    #|runs:
    #|  using: composite
    #|  steps: bad
  let result = parse_action_yml(yaml_str)
  assert_eq(result, Err("invalid 'steps' field: expected array"))
}

///|
test "parse_action_yml null uses in step rejected" {
  let yaml_str =
    #|name: My Action
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses: ~
  let result = parse_action_yml(yaml_str)
  assert_eq(result, Err("invalid 'uses' field in step: expected string"))
}

///|
test "parse_action_yml invalid uses type in step" {
  let yaml_str =
    #|name: My Action
    #|runs:
    #|  using: composite
    #|  steps:
    #|    - uses:
    #|        nested: object
  let result = parse_action_yml(yaml_str)
  assert_eq(result, Err("invalid 'uses' field in step: expected string"))
}

///|
test "parse_action_yml yaml boolean name coercion" {
  // The yaml library follows YAML 1.2: only "true"/"false" are booleans.
  // Bare "on" is parsed as a string, so it passes through unchanged.
  // Explicit true is parsed as Boolean(true) and coerced to "true".
  let yaml_str =
    #|name: true
    #|runs:
    #|  using: node20
  let result = parse_action_yml(yaml_str)
  match result {
    Ok(yml) => assert_eq(yml.name, "true")
    Err(e) => fail("expected Ok but got Err: \{e}")
  }
}

///|
test "parse_action_yml yaml integer description coercion" {
  let yaml_str =
    #|name: My Action
    #|description: 42
    #|runs:
    #|  using: node20
  let result = parse_action_yml(yaml_str)
  match result {
    Ok(yml) => assert_eq(yml.description, Some("42"))
    Err(e) => fail("expected Ok but got Err: \{e}")
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
test "extract_refs skips relative path steps" {
  let yml : @papion.ActionYml = {
    name: "My Action",
    description: None,
    runs: {
      runner: "composite",
      steps: Some([
        { uses: Some("./local/action"), run: None, name: None },
        { uses: Some("actions/checkout@v4"), run: None, name: None },
        { uses: Some("./another/local"), run: None, name: None },
      ]),
    },
  }
  let refs = extract_refs(yml)
  assert_eq(refs.length(), 1)
  assert_eq(refs[0], {
    owner: "actions",
    repo: "checkout",
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
