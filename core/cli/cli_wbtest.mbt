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
  assert_eq(
    result,
    Err(ArgError("missing '@ref' in target: \"actions/checkout\"")),
  )
}

///|
test "parse_args error unknown command" {
  let result = parse_args(["scan", "actions/checkout@v4"])
  assert_eq(result, Err(ArgError("unknown command: \"scan\"")))
}

///|
test "parse_args error no args" {
  let result = parse_args([])
  assert_eq(result, Err(ArgError("missing command and target")))
}

///|
test "parse_args error command only" {
  let result = parse_args(["run"])
  assert_eq(result, Err(ArgError("missing command and target")))
}

///|
test "parse_args error missing format value" {
  let result = parse_args(["run", "actions/checkout@v4", "--format"])
  assert_eq(result, Err(ArgError("missing value for --format")))
}

///|
test "parse_args error missing fail-on value" {
  let result = parse_args(["run", "actions/checkout@v4", "--fail-on"])
  assert_eq(result, Err(ArgError("missing value for --fail-on")))
}

///|
test "parse_args error missing config value" {
  let result = parse_args(["run", "actions/checkout@v4", "--config"])
  assert_eq(result, Err(ArgError("missing value for --config")))
}

///|
test "parse_args error unknown flag" {
  let result = parse_args(["run", "actions/checkout@v4", "--unknown"])
  assert_eq(result, Err(ArgError("unknown flag: \"--unknown\"")))
}

///|
test "parse_args error invalid format value" {
  let result = parse_args(["run", "actions/checkout@v4", "--format", "xml"])
  assert_eq(result, Err(ArgError("invalid value for --format: \"xml\"")))
}

///|
test "parse_args error invalid fail-on value" {
  let result = parse_args(["run", "actions/checkout@v4", "--fail-on", "foo"])
  assert_eq(result, Err(ArgError("invalid value for --fail-on: \"foo\"")))
}

///|
test "parse_args short flag -f for format" {
  let result = parse_args(["run", "actions/checkout@v4", "-f", "json"])
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
test "parse_args short flag -F for fail-on" {
  let result = parse_args(["run", "actions/checkout@v4", "-F", "warn"])
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
test "parse_args split_target error missing owner" {
  let result = parse_args(["run", "@v1"])
  assert_eq(
    result,
    Err(ArgError("invalid target, expected org/repo[/path]@ref: \"@v1\"")),
  )
}

///|
test "parse_args split_target error empty owner" {
  let result = parse_args(["run", "/repo@v1"])
  assert_eq(
    result,
    Err(ArgError("invalid target, expected org/repo[/path]@ref: \"/repo@v1\"")),
  )
}

///|
test "parse_args split_target error empty repo" {
  let result = parse_args(["run", "org/@v1"])
  assert_eq(
    result,
    Err(ArgError("invalid target, expected org/repo[/path]@ref: \"org/@v1\"")),
  )
}

///|
test "parse_args split_target error empty path" {
  let result = parse_args(["run", "org/repo/@v1"])
  assert_eq(
    result,
    Err(
      ArgError("invalid target, expected org/repo[/path]@ref: \"org/repo/@v1\""),
    ),
  )
}

///|
test "parse_args split_target error empty ref" {
  let result = parse_args(["run", "org/repo@"])
  assert_eq(result, Err(ArgError("missing '@ref' in target: \"org/repo@\"")))
}

///|
test "run propagates arg error as ArgError" {
  let result = run(["run"])
  assert_eq(result, Err(ArgError("missing command and target")))
}

///|
test "load_config none returns default policy" {
  assert_eq(load_config(None), Ok(@papion.Policy::default()))
}

///|
test "load_config parses TOML fixture into policy" {
  let policy = match load_config(Some("cli/testdata/papion.toml")) {
    Ok(policy) => policy
    Err(err) => fail(err)
  }
  assert_eq(policy, {
    sha_pinning: false,
    allowed: ["actions/*", "github/*"],
    disallowed: ["bad-org/unsafe"],
  })
}

///|
test "load_config normalizes TOML patterns via shared policy helper" {
  let value = try? @toml.parse(
    (
      #|[policy]
      #|allowed = ["Actions/*"]
      #|disallowed = ["Bad-Org/Unsafe"]
    ),
  )
  let policy = match value {
    Ok(value) =>
      match parse_policy_toml(value) {
        Ok(policy) => policy
        Err(err) => fail(err)
      }
    Err(err) => fail(err.to_string())
  }
  assert_eq(policy.allowed, ["actions/*"])
  assert_eq(policy.disallowed, ["bad-org/unsafe"])
}

///|
test "github_contents_url encodes ref query parameter" {
  let url = match
    github_contents_url("maruloop", "papion", "release/a&b", "action.yml") {
    Ok(url) => url
    Err(err) => fail(err.1)
  }
  assert_eq(
    url, "https://api.github.com/repos/maruloop/papion/contents/action.yml?ref=release%2Fa%26b",
  )
}

///|
test "run config error fires before fetch" {
  match
    run(["run", "actions/checkout@v4", "--config", "cli/testdata/missing.toml"]) {
    Err(RuntimeError(_)) => ()
    Ok(_) => fail("expected RuntimeError for missing config")
    Err(ArgError(_)) => fail("expected RuntimeError for missing config")
  }
}

///|
test "run parse_args error on --config propagates before fetch" {
  let result = run(["run", "actions/checkout@v4", "--config"])
  assert_eq(result, Err(ArgError("missing value for --config")))
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
