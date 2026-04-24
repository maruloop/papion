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
test "percent_encode_path_component: alphanumeric passthrough" {
  assert_eq(percent_encode_path_component("actions"), "actions")
}

///|
test "percent_encode_path_component: unreserved chars passthrough" {
  assert_eq(
    percent_encode_path_component("my.repo_name-v1~0"),
    "my.repo_name-v1~0",
  )
}

///|
test "percent_encode_path_component: slash encoded" {
  assert_eq(percent_encode_path_component("a/b"), "a%2Fb")
}

///|
test "percent_encode_path_component: space encoded" {
  assert_eq(percent_encode_path_component("hello world"), "hello%20world")
}

///|
test "percent_encode_path_component: unicode encoded" {
  assert_eq(percent_encode_path_component("café"), "caf%C3%A9")
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
test "github_contents_url encodes owner repo and path segments" {
  let url = match
    github_contents_url("maru/loop", "pa pion", "main", "sub dir/action?.yml") {
    Ok(url) => url
    Err(err) => fail(err.1)
  }
  assert_eq(
    url, "https://api.github.com/repos/maru%2Floop/pa%20pion/contents/sub%20dir/action%3F.yml?ref=main",
  )
}

///|
test "run config error fires before fetch" {
  let mut fetch_called = false
  let result = @cli.run_with_host(
    ["run", "actions/checkout@v4", "--config", "cli/testdata/missing.toml"],
    load_config,
    fn(_owner, _repo, _git_ref, _path) {
      fetch_called = true
      Err("fetch_action_yml should not be called before config loading")
    },
  )
  match result {
    Err(@cli.RuntimeError(_)) => ()
    Ok(_) => fail("expected RuntimeError for missing config")
    Err(@cli.ArgError(_)) => fail("expected RuntimeError for missing config")
  }
  assert_eq(fetch_called, false)
}

///|
test "run parse_args error on --config propagates before fetch" {
  let mut load_config_called = false
  let mut fetch_called = false
  let result = @cli.run_with_host(
    ["run", "actions/checkout@v4", "--config"],
    fn(_config_path) {
      load_config_called = true
      Ok(@papion.Policy::default())
    },
    fn(_owner, _repo, _git_ref, _path) {
      fetch_called = true
      Ok("")
    },
  )
  assert_eq(result, Err(@cli.ArgError("missing value for --config")))
  assert_eq(load_config_called, false)
  assert_eq(fetch_called, false)
}
