///|
test "parse_args run owner repo ref" {
  let result = parse_args(["run", "actions/checkout@v4"])
  @test.assert_eq(
    result,
    Ok({
      owner: "actions",
      repo: "checkout",
      path: None,
      git_ref: Some("v4"),
      allow_ref_fallback: false,
      format: Human,
      fail_on: Fail,
      config: None,
    }),
  )
}

///|
test "percent_decode_url_path_segment decodes percent-escaped segment" {
  @test.assert_eq(
    percent_decode_url_path_segment("release%2Fv1"),
    Ok("release/v1"),
  )
}

///|
test "percent_decode_url_path_segment rejects invalid escape" {
  @test.assert_eq(
    percent_decode_url_path_segment("release%"),
    Err("invalid GitHub URL: invalid percent-encoding"),
  )
}

///|
test "parse_args run with path" {
  let result = parse_args(["run", "maruloop/papion/action@v1"])
  @test.assert_eq(
    result,
    Ok({
      owner: "maruloop",
      repo: "papion",
      path: Some("action"),
      git_ref: Some("v1"),
      allow_ref_fallback: false,
      format: Human,
      fail_on: Fail,
      config: None,
    }),
  )
}

///|
test "parse_args json format" {
  let result = parse_args(["run", "actions/checkout@v4", "--format", "json"])
  @test.assert_eq(
    result,
    Ok({
      owner: "actions",
      repo: "checkout",
      path: None,
      git_ref: Some("v4"),
      allow_ref_fallback: false,
      format: Json,
      fail_on: Fail,
      config: None,
    }),
  )
}

///|
test "parse_args fail_on warn" {
  let result = parse_args(["run", "actions/checkout@v4", "--fail-on", "warn"])
  @test.assert_eq(
    result,
    Ok({
      owner: "actions",
      repo: "checkout",
      path: None,
      git_ref: Some("v4"),
      allow_ref_fallback: false,
      format: Human,
      fail_on: Warn,
      config: None,
    }),
  )
}

///|
test "parse_args fail_on none" {
  let result = parse_args(["run", "actions/checkout@v4", "--fail-on", "none"])
  @test.assert_eq(
    result,
    Ok({
      owner: "actions",
      repo: "checkout",
      path: None,
      git_ref: Some("v4"),
      allow_ref_fallback: false,
      format: Human,
      fail_on: NoneLevel,
      config: None,
    }),
  )
}

///|
test "parse_args short flag -f for format" {
  let result = parse_args(["run", "actions/checkout@v4", "-f", "json"])
  @test.assert_eq(
    result,
    Ok({
      owner: "actions",
      repo: "checkout",
      path: None,
      git_ref: Some("v4"),
      allow_ref_fallback: false,
      format: Json,
      fail_on: Fail,
      config: None,
    }),
  )
}

///|
test "parse_args short flag -F for fail-on" {
  let result = parse_args(["run", "actions/checkout@v4", "-F", "warn"])
  @test.assert_eq(
    result,
    Ok({
      owner: "actions",
      repo: "checkout",
      path: None,
      git_ref: Some("v4"),
      allow_ref_fallback: false,
      format: Human,
      fail_on: Warn,
      config: None,
    }),
  )
}

///|
test "parse_args error no args" {
  let result = parse_args([])
  @test.assert_eq(result, Err(ArgError("missing command and target")))
}

///|
test "parse_args error command only" {
  let result = parse_args(["run"])
  @test.assert_eq(result, Err(ArgError("missing command and target")))
}

///|
test "parse_args run owner repo without ref" {
  let result = parse_args(["run", "actions/checkout"])
  @test.assert_eq(
    result,
    Ok({
      owner: "actions",
      repo: "checkout",
      path: None,
      git_ref: None,
      allow_ref_fallback: false,
      format: Human,
      fail_on: Fail,
      config: None,
    }),
  )
}

///|
test "parse_args run github url without ref" {
  let result = parse_args(["run", "https://github.com/actions/checkout"])
  @test.assert_eq(
    result,
    Ok({
      owner: "actions",
      repo: "checkout",
      path: None,
      git_ref: None,
      allow_ref_fallback: false,
      format: Human,
      fail_on: Fail,
      config: None,
    }),
  )
}

///|
test "parse_args run github url ignores query and fragment" {
  let result = parse_args([
    "run", "https://github.com/actions/checkout?tab=readme#top",
  ])
  @test.assert_eq(
    result,
    Ok({
      owner: "actions",
      repo: "checkout",
      path: None,
      git_ref: None,
      allow_ref_fallback: false,
      format: Human,
      fail_on: Fail,
      config: None,
    }),
  )
}

///|
test "parse_args run github url strips trailing dot git" {
  let result = parse_args(["run", "https://github.com/actions/checkout.git"])
  @test.assert_eq(
    result,
    Ok({
      owner: "actions",
      repo: "checkout",
      path: None,
      git_ref: None,
      allow_ref_fallback: false,
      format: Human,
      fail_on: Fail,
      config: None,
    }),
  )
}

///|
test "parse_args run github tree url with ref and path" {
  let result = parse_args([
    "run", "https://github.com/actions/checkout/tree/v6.0.2/action",
  ])
  @test.assert_eq(
    result,
    Ok({
      owner: "actions",
      repo: "checkout",
      path: Some("action"),
      git_ref: Some("v6.0.2"),
      allow_ref_fallback: true,
      format: Human,
      fail_on: Fail,
      config: None,
    }),
  )
}

///|
test "parse_args run github tree url decodes percent-escaped ref and path" {
  let result = parse_args([
    "run", "https://github.com/actions/checkout/tree/release%2Fv1/sub%20dir",
  ])
  @test.assert_eq(
    result,
    Ok({
      owner: "actions",
      repo: "checkout",
      path: Some("sub dir"),
      git_ref: Some("release/v1"),
      allow_ref_fallback: true,
      format: Human,
      fail_on: Fail,
      config: None,
    }),
  )
}

///|
test "parse_args error unknown command" {
  let result = parse_args(["scan", "actions/checkout@v4"])
  @test.assert_eq(result, Err(ArgError("unknown command: \"scan\"")))
}

///|
test "parse_args error missing format value" {
  let result = parse_args(["run", "actions/checkout@v4", "--format"])
  @test.assert_eq(result, Err(ArgError("missing value for --format")))
}

///|
test "parse_args error missing fail-on value" {
  let result = parse_args(["run", "actions/checkout@v4", "--fail-on"])
  @test.assert_eq(result, Err(ArgError("missing value for --fail-on")))
}

///|
test "parse_args error missing config value" {
  let result = parse_args(["run", "actions/checkout@v4", "--config"])
  @test.assert_eq(result, Err(ArgError("missing value for --config")))
}

///|
test "parse_args error unknown flag" {
  let result = parse_args(["run", "actions/checkout@v4", "--unknown"])
  @test.assert_eq(result, Err(ArgError("unknown flag: \"--unknown\"")))
}

///|
test "parse_args error invalid format value" {
  let result = parse_args(["run", "actions/checkout@v4", "--format", "xml"])
  @test.assert_eq(result, Err(ArgError("invalid value for --format: \"xml\"")))
}

///|
test "parse_args error invalid fail-on value" {
  let result = parse_args(["run", "actions/checkout@v4", "--fail-on", "foo"])
  @test.assert_eq(result, Err(ArgError("invalid value for --fail-on: \"foo\"")))
}

///|
test "parse_args split_target error missing owner" {
  let result = parse_args(["run", "@v1"])
  @test.assert_eq(result, Err(ArgError("invalid target: expected owner/repo")))
}

///|
test "parse_args split_target error empty owner" {
  let result = parse_args(["run", "/repo@v1"])
  @test.assert_eq(result, Err(ArgError("owner is empty")))
}

///|
test "parse_args split_target error empty repo" {
  let result = parse_args(["run", "org/@v1"])
  @test.assert_eq(result, Err(ArgError("repo is empty")))
}

///|
test "parse_args split_target error empty path" {
  let result = parse_args(["run", "org/repo/@v1"])
  @test.assert_eq(result, Err(ArgError("path is empty")))
}

///|
test "parse_args split_target error empty ref" {
  let result = parse_args(["run", "org/repo@"])
  @test.assert_eq(result, Err(ArgError("missing ref after '@'")))
}

///|
test "parse_args github blob url is rejected" {
  let result = parse_args([
    "run", "https://github.com/actions/checkout/blob/main/action.yml",
  ])
  @test.assert_eq(
    result,
    Err(
      ArgError(
        "blob URLs are not supported; use tree URLs or owner/repo[/path]@ref format",
      ),
    ),
  )
}

///|
test "run_with_host propagates arg error before host calls" {
  let mut load_config_called = false
  let mut fetch_called = false
  let result = run_with_host(
    ["run"],
    fn(_config_path) {
      load_config_called = true
      Ok(@papion.Policy::default())
    },
    fn(_owner, _repo, _git_ref, _path, _allow_ref_fallback) {
      fetch_called = true
      Ok(("", "unused", None))
    },
  )
  @test.assert_eq(result, Err(ArgError("missing command and target")))
  @test.assert_eq(load_config_called, false)
  @test.assert_eq(fetch_called, false)
}

///|
test "run_with_host uses resolved git ref from host fetch" {
  let mut captured_owner = ""
  let mut captured_repo = ""
  let mut captured_git_ref = None
  let mut captured_path = None
  let mut captured_allow_ref_fallback = false
  let result = run_with_host(
    ["run", "actions/checkout@v4", "--format", "json"],
    fn(_config_path) { Ok(@papion.Policy::default()) },
    fn(owner, repo, git_ref, path, allow_ref_fallback) {
      captured_owner = owner
      captured_repo = repo
      captured_git_ref = git_ref
      captured_path = path
      captured_allow_ref_fallback = allow_ref_fallback
      Ok(
        (
          (
            #|name: Setup Node
            #|runs:
            #|  using: node20
          ),
          "release/v1",
          None,
        ),
      )
    },
  )
  match result {
    Ok(outcome) => {
      @test.assert_eq(captured_owner, "actions")
      @test.assert_eq(captured_repo, "checkout")
      @test.assert_eq(captured_git_ref, Some("v4"))
      @test.assert_eq(captured_path, None)
      @test.assert_eq(captured_allow_ref_fallback, false)
      assert_true(
        outcome.output.contains("\"target\":\"actions/checkout@release/v1\""),
      )
      assert_true(outcome.output.contains("\"ref\":\"release/v1\""))
    }
    Err(err) => fail(err.to_string())
  }
}

///|
test "run_with_host passes allow_ref_fallback for github tree urls" {
  let mut captured_allow_ref_fallback = false
  let mut captured_path = None
  let result = run_with_host(
    [
      "run", "https://github.com/actions/checkout/tree/release/v1/action", "--format",
      "json",
    ],
    fn(_config_path) { Ok(@papion.Policy::default()) },
    fn(_owner, _repo, _git_ref, _path, allow_ref_fallback) {
      captured_allow_ref_fallback = allow_ref_fallback
      captured_path = _path
      Ok(
        (
          (
            #|name: Setup Node
            #|runs:
            #|  using: node20
          ),
          "release/v1",
          Some("action"),
        ),
      )
    },
  )
  match result {
    Ok(outcome) => {
      @test.assert_eq(captured_allow_ref_fallback, true)
      @test.assert_eq(captured_path, Some("v1/action"))
      assert_true(
        outcome.output.contains(
          "\"target\":\"actions/checkout/action@release/v1\"",
        ),
      )
    }
    Err(err) => fail(err.to_string())
  }
}

///|
test "run_with_host passes custom ref kind resolver into engine" {
  let mut resolver_called = false
  let mut resolved_owner = ""
  let mut resolved_repo = ""
  let mut resolved_git_ref = ""
  let result = run_with_host(
    ["run", "actions/checkout@v4", "--format", "json"],
    fn(_config_path) { Ok(@papion.Policy::default()) },
    fn(_owner, _repo, _git_ref, _path, _allow_ref_fallback) {
      Ok(
        (
          (
            #|name: Composite
            #|runs:
            #|  using: composite
            #|  steps:
            #|    - uses: actions/checkout@v4
          ),
          "v4",
          None,
        ),
      )
    },
    resolve_ref_kind=fn(owner, repo, git_ref) {
      resolver_called = true
      resolved_owner = owner
      resolved_repo = repo
      resolved_git_ref = git_ref
      @papion.RefKind::ImmutableRelease
    },
  )
  match result {
    Ok(outcome) => {
      @test.assert_eq(resolver_called, true)
      @test.assert_eq(resolved_owner, "actions")
      @test.assert_eq(resolved_repo, "checkout")
      @test.assert_eq(resolved_git_ref, "v4")
      assert_true(outcome.output.contains("\"findings\":[]"))
    }
    Err(err) => fail(err.to_string())
  }
}

///|
test "exit_code_for fail_on fail clean" {
  @test.assert_eq(exit_code_for({ failures: 0, warnings: 0 }, Fail), 0)
}

///|
test "exit_code_for fail_on fail with failure" {
  @test.assert_eq(exit_code_for({ failures: 1, warnings: 0 }, Fail), 1)
}

///|
test "exit_code_for fail_on warn warning only" {
  @test.assert_eq(exit_code_for({ failures: 0, warnings: 1 }, Warn), 1)
}

///|
test "exit_code_for fail_on warn clean" {
  @test.assert_eq(exit_code_for({ failures: 0, warnings: 0 }, Warn), 0)
}

///|
test "exit_code_for fail_on none ignores findings" {
  @test.assert_eq(exit_code_for({ failures: 2, warnings: 3 }, NoneLevel), 0)
}
