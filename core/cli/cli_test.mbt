///|
fn github_target(
  owner : String,
  repo : String,
  git_ref? : String? = None,
  path? : String? = None,
  allow_ref_fallback? : Bool = false,
) -> RunTarget {
  GitHub({ owner, repo, git_ref, path, allow_ref_fallback })
}

///|
fn no_local_target(_path : String) -> Result[Array[LocalScanUnit], String] {
  Err("unexpected local read")
}

///|
test "parse_args run owner repo ref" {
  let result = parse_args(["run", "actions/checkout@v4"])
  assert_eq(
    result,
    Ok({
      target: github_target("actions", "checkout", git_ref=Some("v4")),
      format: Human,
      fail_on: Fail,
      config: None,
    }),
  )
}

///|
test "percent_decode_url_path_segment decodes percent-escaped segment" {
  assert_eq(percent_decode_url_path_segment("release%2Fv1"), Ok("release/v1"))
}

///|
test "percent_decode_url_path_segment rejects invalid escape" {
  assert_eq(
    percent_decode_url_path_segment("release%"),
    Err("invalid GitHub URL: invalid percent-encoding"),
  )
}

///|
test "parse_args run with path" {
  let result = parse_args(["run", "maruloop/papion/action@v1"])
  assert_eq(
    result,
    Ok({
      target: github_target(
        "maruloop",
        "papion",
        git_ref=Some("v1"),
        path=Some("action"),
      ),
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
      target: github_target("actions", "checkout", git_ref=Some("v4")),
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
      target: github_target("actions", "checkout", git_ref=Some("v4")),
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
      target: github_target("actions", "checkout", git_ref=Some("v4")),
      format: Human,
      fail_on: NoneLevel,
      config: None,
    }),
  )
}

///|
test "parse_args short flag -f for format" {
  let result = parse_args(["run", "actions/checkout@v4", "-f", "json"])
  assert_eq(
    result,
    Ok({
      target: github_target("actions", "checkout", git_ref=Some("v4")),
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
      target: github_target("actions", "checkout", git_ref=Some("v4")),
      format: Human,
      fail_on: Warn,
      config: None,
    }),
  )
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
test "parse_args run owner repo without ref" {
  let result = parse_args(["run", "actions/checkout"])
  assert_eq(
    result,
    Ok({
      target: github_target("actions", "checkout"),
      format: Human,
      fail_on: Fail,
      config: None,
    }),
  )
}

///|
test "parse_args run github url without ref" {
  let result = parse_args(["run", "https://github.com/actions/checkout"])
  assert_eq(
    result,
    Ok({
      target: github_target("actions", "checkout"),
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
  assert_eq(
    result,
    Ok({
      target: github_target("actions", "checkout"),
      format: Human,
      fail_on: Fail,
      config: None,
    }),
  )
}

///|
test "parse_args run github url strips trailing dot git" {
  let result = parse_args(["run", "https://github.com/actions/checkout.git"])
  assert_eq(
    result,
    Ok({
      target: github_target("actions", "checkout"),
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
  assert_eq(
    result,
    Ok({
      target: github_target(
        "actions",
        "checkout",
        git_ref=Some("v6.0.2"),
        path=Some("action"),
        allow_ref_fallback=true,
      ),
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
  assert_eq(
    result,
    Ok({
      target: github_target(
        "actions",
        "checkout",
        git_ref=Some("release/v1"),
        path=Some("sub dir"),
        allow_ref_fallback=true,
      ),
      format: Human,
      fail_on: Fail,
      config: None,
    }),
  )
}

///|
test "parse_args local action path" {
  let result = parse_args(["run", "./action/action.yml"])
  assert_eq(
    result,
    Ok({
      target: Local({ path: "./action/action.yml" }),
      format: Human,
      fail_on: Fail,
      config: None,
    }),
  )
}

///|
test "parse_args local workflow path" {
  let result = parse_args(["run", "../repo/.github/workflows/release.yml"])
  assert_eq(
    result,
    Ok({
      target: Local({ path: "../repo/.github/workflows/release.yml" }),
      format: Human,
      fail_on: Fail,
      config: None,
    }),
  )
}

///|
test "parse_args local absolute path" {
  let result = parse_args(["run", "/tmp/repo/.github"])
  assert_eq(
    result,
    Ok({
      target: Local({ path: "/tmp/repo/.github" }),
      format: Human,
      fail_on: Fail,
      config: None,
    }),
  )
}

///|
test "parse_args error unknown command" {
  let result = parse_args(["scan", "actions/checkout@v4"])
  assert_eq(result, Err(ArgError("unknown command: \"scan\"")))
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
test "parse_args split_target error missing owner" {
  let result = parse_args(["run", "@v1"])
  assert_eq(result, Err(ArgError("invalid target: expected owner/repo")))
}

///|
test "parse_args absolute path is treated as local target" {
  let result = parse_args(["run", "/repo@v1"])
  assert_eq(
    result,
    Ok({
      target: Local({ path: "/repo@v1" }),
      format: Human,
      fail_on: Fail,
      config: None,
    }),
  )
}

///|
test "parse_args split_target error empty repo" {
  let result = parse_args(["run", "org/@v1"])
  assert_eq(result, Err(ArgError("repo is empty")))
}

///|
test "parse_args split_target error empty path" {
  let result = parse_args(["run", "org/repo/@v1"])
  assert_eq(result, Err(ArgError("path is empty")))
}

///|
test "parse_args split_target error empty ref" {
  let result = parse_args(["run", "org/repo@"])
  assert_eq(result, Err(ArgError("missing ref after '@'")))
}

///|
test "parse_args github blob url is rejected" {
  let result = parse_args([
    "run", "https://github.com/actions/checkout/blob/main/action.yml",
  ])
  assert_eq(
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
    no_local_target,
  )
  assert_eq(result, Err(ArgError("missing command and target")))
  assert_eq(load_config_called, false)
  assert_eq(fetch_called, false)
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
    no_local_target,
  )
  match result {
    Ok(outcome) => {
      assert_eq(captured_owner, "actions")
      assert_eq(captured_repo, "checkout")
      assert_true(captured_git_ref == Some("v4"))
      assert_true(captured_path == None)
      assert_eq(captured_allow_ref_fallback, false)
      assert_true(outcome.output.contains("\"git_ref\":\"release/v1\""))
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
    no_local_target,
  )
  match result {
    Ok(outcome) => {
      assert_eq(captured_allow_ref_fallback, true)
      assert_true(captured_path == Some("v1/action"))
      assert_true(outcome.output.contains("\"path\":\"action\""))
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
    no_local_target,
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
      assert_eq(resolver_called, true)
      assert_eq(resolved_owner, "actions")
      assert_eq(resolved_repo, "checkout")
      assert_eq(resolved_git_ref, "v4")
      assert_true(outcome.output.contains("\"findings\":[]"))
    }
    Err(err) => fail(err.to_string())
  }
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

///|
test "run_with_host local single-file json output is an array" {
  let action_yaml =
    #|name: My Action
    #|runs:
    #|  using: node20
  let result = run_with_host(
    ["run", "./action.yml", "--format", "json"],
    fn(_) { Ok(@papion.Policy::default()) },
    fn(_, _, _, _, _) { Err("unexpected github fetch") },
    fn(_path) {
      Ok([{ kind: Action, abs_path: "/repo/action.yml", yaml: action_yaml }])
    },
  )
  match result {
    Ok(outcome) => assert_true(outcome.output.has_prefix("["))
    Err(err) => fail(err.to_string())
  }
}

///|
test "run_with_host local multi-file json output is an array" {
  let action_yaml =
    #|name: My Action
    #|runs:
    #|  using: node20
  let result = run_with_host(
    ["run", "./.github", "--format", "json"],
    fn(_) { Ok(@papion.Policy::default()) },
    fn(_, _, _, _, _) { Err("unexpected github fetch") },
    fn(_path) {
      Ok([
        {
          kind: Action,
          abs_path: "/repo/.github/action.yml",
          yaml: action_yaml,
        },
        {
          kind: Action,
          abs_path: "/repo/.github/actions/other/action.yml",
          yaml: action_yaml,
        },
      ])
    },
  )
  match result {
    Ok(outcome) => assert_true(outcome.output.has_prefix("["))
    Err(err) => fail(err.to_string())
  }
}
