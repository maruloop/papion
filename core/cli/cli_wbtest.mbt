///|
test "parse_args run owner repo ref" {
  let result = parse_args(["run", "actions/checkout@v4"])
  assert_eq(
    result,
    Ok({
      owner: "actions",
      repo: "checkout",
      path: None,
      git_ref: "v4",
      format: Human,
      fail_on: Fail,
      config: None,
    }),
  )
}

///|
test "parse_args run with path" {
  let result = parse_args(["run", "maruloop/papion/action@v1"])
  assert_eq(
    result,
    Ok({
      owner: "maruloop",
      repo: "papion",
      path: Some("action"),
      git_ref: "v1",
      format: Human,
      fail_on: Fail,
      config: None,
    }),
  )
}

///|
test "parse_args json format" {
  let result = parse_args(["run", "actions/checkout@v4", "--format", "json"])
  assert_eq(
    result,
    Ok({
      owner: "actions",
      repo: "checkout",
      path: None,
      git_ref: "v4",
      format: Json,
      fail_on: Fail,
      config: None,
    }),
  )
}

///|
test "parse_args fail_on warn" {
  let result = parse_args(["run", "actions/checkout@v4", "--fail-on", "warn"])
  assert_eq(
    result,
    Ok({
      owner: "actions",
      repo: "checkout",
      path: None,
      git_ref: "v4",
      format: Human,
      fail_on: Warn,
      config: None,
    }),
  )
}

///|
test "parse_args fail_on none" {
  let result = parse_args(["run", "actions/checkout@v4", "--fail-on", "none"])
  assert_eq(
    result,
    Ok({
      owner: "actions",
      repo: "checkout",
      path: None,
      git_ref: "v4",
      format: Human,
      fail_on: NoneLevel,
      config: None,
    }),
  )
}

///|
test "parse_args error missing ref" {
  let result = parse_args(["run", "actions/checkout"])
  assert_eq(result, Err("missing '@ref' in target: \"actions/checkout\""))
}

///|
test "parse_args error unknown command" {
  let result = parse_args(["scan", "actions/checkout@v4"])
  assert_eq(result, Err("unknown command: \"scan\""))
}

///|
test "exit_code_for fail_on fail clean" {
  assert_eq(exit_code_for({ failures: 0, warnings: 0 }, Fail), 0)
}

///|
test "exit_code_for fail_on fail with failure" {
  assert_eq(exit_code_for({ failures: 1, warnings: 0 }, Fail), 1)
}

///|
test "exit_code_for fail_on warn warning only" {
  assert_eq(exit_code_for({ failures: 0, warnings: 1 }, Warn), 1)
}

///|
test "exit_code_for fail_on warn clean" {
  assert_eq(exit_code_for({ failures: 0, warnings: 0 }, Warn), 0)
}

///|
test "exit_code_for fail_on none ignores findings" {
  assert_eq(exit_code_for({ failures: 2, warnings: 3 }, NoneLevel), 0)
}
