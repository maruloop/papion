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
  assert_eq(@cli.percent_encode_path_component("actions"), "actions")
}

///|
test "percent_encode_path_component: unreserved chars passthrough" {
  assert_eq(
    @cli.percent_encode_path_component("my.repo_name-v1~0"),
    "my.repo_name-v1~0",
  )
}

///|
test "percent_encode_path_component: slash encoded" {
  assert_eq(@cli.percent_encode_path_component("a/b"), "a%2Fb")
}

///|
test "percent_encode_path_component: space encoded" {
  assert_eq(@cli.percent_encode_path_component("hello world"), "hello%20world")
}

///|
test "percent_encode_path_component: unicode encoded" {
  assert_eq(@cli.percent_encode_path_component("café"), "caf%C3%A9")
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
test "github_matching_refs_url encodes heads path components" {
  let url = match
    github_matching_refs_url("maru/loop", "pa pion", "heads", "release/v1") {
    Ok(url) => url
    Err(err) => fail(err.1)
  }
  assert_eq(
    url, "https://api.github.com/repos/maru%2Floop/pa%20pion/git/matching-refs/heads/release/v1?per_page=100",
  )
}

///|
test "github_matching_refs_url encodes tags path components" {
  let url = match
    github_matching_refs_url("maruloop", "papion", "tags", "v1.0.0/rc 1") {
    Ok(url) => url
    Err(err) => fail(err.1)
  }
  assert_eq(
    url, "https://api.github.com/repos/maruloop/papion/git/matching-refs/tags/v1.0.0/rc%201?per_page=100",
  )
}

///|
test "github_repo_url encodes owner and repo path segments" {
  let url = match github_repo_url("maru/loop", "pa pion") {
    Ok(url) => url
    Err(err) => fail(err.1)
  }
  assert_eq(url, "https://api.github.com/repos/maru%2Floop/pa%20pion")
}

///|
test "github_release_by_tag_url encodes owner repo and tag path segments" {
  let url = match
    github_release_by_tag_url("maru/loop", "pa pion", "v1.0.0/rc 1") {
    Ok(url) => url
    Err(err) => fail(err.1)
  }
  assert_eq(
    url, "https://api.github.com/repos/maru%2Floop/pa%20pion/releases/tags/v1.0.0%2Frc%201",
  )
}

///|
test "github_commit_url encodes owner repo and sha path segments" {
  let url = match github_commit_url("maru/loop", "pa pion", "abc/123") {
    Ok(url) => url
    Err(err) => fail(err.1)
  }
  assert_eq(
    url, "https://api.github.com/repos/maru%2Floop/pa%20pion/git/commits/abc%2F123",
  )
}

///|
test "extract_matching_refs_field returns stripped refs" {
  assert_eq(
    extract_matching_refs_field(
      (
        #|[
        #|  {"ref":"refs/heads/release","node_id":"1"},
        #|  {"ref":"refs/heads/release/v1","node_id":"2"}
        #|]
      ),
      "octocat",
      "hello-world",
      "heads",
    ),
    Ok(["release", "release/v1"]),
  )
}

///|
test "extract_matching_refs_field returns empty array" {
  assert_eq(
    extract_matching_refs_field("[]", "octocat", "hello-world", "tags"),
    Ok([]),
  )
}

///|
test "extract_matching_refs_field errors when ref field missing" {
  assert_eq(
    extract_matching_refs_field(
      "[{\"node_id\":\"1\"}]", "octocat", "hello-world", "heads",
    ),
    Err(
      (
        0, "GitHub matching refs response for octocat/hello-world did not contain a ref field",
      ),
    ),
  )
}

///|
test "extract_matching_refs_field errors when ref field is not string" {
  assert_eq(
    extract_matching_refs_field(
      "[{\"ref\":123}]", "octocat", "hello-world", "heads",
    ),
    Err(
      (
        0, "GitHub matching refs response for octocat/hello-world did not contain a string ref field",
      ),
    ),
  )
}

///|
test "extract_default_branch_field returns branch when default_branch is string" {
  assert_eq(
    extract_default_branch_field(
      "{\"default_branch\":\"main\"}", "octocat", "hello-world",
    ),
    Ok("main"),
  )
}

///|
test "extract_default_branch_field errors when default_branch missing" {
  assert_eq(
    extract_default_branch_field(
      "{\"name\":\"hello-world\"}", "octocat", "hello-world",
    ),
    Err(
      (
        0, "GitHub repository response for octocat/hello-world did not contain a default_branch field",
      ),
    ),
  )
}

///|
test "extract_default_branch_field errors when default_branch is not string" {
  assert_eq(
    extract_default_branch_field(
      "{\"default_branch\":123}", "octocat", "hello-world",
    ),
    Err(
      (
        0, "GitHub repository response for octocat/hello-world did not contain a string default_branch field",
      ),
    ),
  )
}

///|
test "extract_release_immutable_field returns true when immutable is true" {
  assert_eq(
    extract_release_immutable_field(
      "{\"immutable\":true}", "octocat", "hello-world", "v1",
    ),
    Ok(true),
  )
}

///|
test "extract_release_immutable_field returns false when immutable is false" {
  assert_eq(
    extract_release_immutable_field(
      "{\"immutable\":false}", "octocat", "hello-world", "v1",
    ),
    Ok(false),
  )
}

///|
test "extract_release_immutable_field returns false when immutable missing" {
  assert_eq(
    extract_release_immutable_field(
      "{\"tag_name\":\"v1\"}", "octocat", "hello-world", "v1",
    ),
    Ok(false),
  )
}

///|
test "extract_release_immutable_field errors when immutable is not bool" {
  assert_eq(
    extract_release_immutable_field(
      "{\"immutable\":123}", "octocat", "hello-world", "v1",
    ),
    Err(
      (
        0, "GitHub release response for octocat/hello-world@v1 did not contain a boolean immutable field",
      ),
    ),
  )
}

///|
test "extract_release_immutable_field errors on parse failure" {
  assert_eq(
    extract_release_immutable_field("{", "octocat", "hello-world", "v1"),
    Err(
      (
        0, "failed to parse GitHub release response for octocat/hello-world@v1: Unexpected end of file",
      ),
    ),
  )
}

///|
test "select_best_matching_ref returns exact ref with no remaining path" {
  match select_best_matching_ref(["v4"], "v4", None) {
    Ok((ref_name, remaining)) => {
      assert_eq(ref_name, "v4")
      assert_eq(remaining, None)
    }
    Err(e) => fail("expected Ok but got Err: \{e}")
  }
}

///|
test "select_best_matching_ref picks longest matching ref" {
  match
    select_best_matching_ref(
      ["release", "release/v1"],
      "release",
      Some("v1/action"),
    ) {
    Ok((ref_name, remaining)) => {
      assert_eq(ref_name, "release/v1")
      assert_eq(remaining, Some("action"))
    }
    Err(e) => fail("expected Ok but got Err: \{e}")
  }
}

///|
test "select_best_matching_ref errors when no candidate matches" {
  match select_best_matching_ref(["release/v2"], "release", Some("v1/action")) {
    Err(e) => assert_eq(e, "no matching Git refs found")
    Ok(_) => fail("expected Err")
  }
}

///|
test "select_best_matching_ref errors when candidates empty" {
  match select_best_matching_ref([], "release", Some("v1/action")) {
    Err(e) => assert_eq(e, "no matching Git refs found")
    Ok(_) => fail("expected Err")
  }
}

///|
test "select_best_matching_ref normalizes leading slash path" {
  match
    select_best_matching_ref(["release/v1"], "release", Some("/v1/action")) {
    Ok((ref_name, remaining)) => {
      assert_eq(ref_name, "release/v1")
      assert_eq(remaining, Some("action"))
    }
    Err(e) => fail("expected Ok but got Err: \{e}")
  }
}

///|
test "select_best_matching_ref normalizes double slash path" {
  match
    select_best_matching_ref(["release/v1"], "release", Some("v1//action")) {
    Ok((ref_name, remaining)) => {
      assert_eq(ref_name, "release/v1")
      assert_eq(remaining, Some("action"))
    }
    Err(e) => fail("expected Ok but got Err: \{e}")
  }
}

///|
test "select_best_matching_ref normalizes trailing slash path to none" {
  match select_best_matching_ref(["v4"], "v4", Some("/")) {
    Ok((ref_name, remaining)) => {
      assert_eq(ref_name, "v4")
      assert_eq(remaining, None)
    }
    Err(e) => fail("expected Ok but got Err: \{e}")
  }
}

///|
test "run config error fires before fetch" {
  let mut fetch_called = false
  let result = @cli.run_with_host(
    ["run", "actions/checkout@v4", "--config", "cli/testdata/missing.toml"],
    load_config,
    fn(_owner, _repo, _git_ref, _path, _allow_ref_fallback) {
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
    fn(_owner, _repo, _git_ref, _path, _allow_ref_fallback) {
      fetch_called = true
      Ok(("", "unused", None))
    },
  )
  assert_eq(result, Err(@cli.ArgError("missing value for --config")))
  assert_eq(load_config_called, false)
  assert_eq(fetch_called, false)
}

// Helpers for resolve_ref_kind_impl tests

///|
fn commit_ok(
  exists : Bool,
) -> (String, String, String) -> Result[Bool, (Int, String)] {
  fn(_owner, _repo, _ref) { Ok(exists) }
}

///|
fn commit_err() -> (String, String, String) -> Result[Bool, (Int, String)] {
  fn(_owner, _repo, _ref) { Err((500, "api error")) }
}

///|
fn release_ok(
  immutable : Bool,
) -> (String, String, String) -> Result[Bool, (Int, String)] {
  fn(_owner, _repo, _ref) { Ok(immutable) }
}

///|
fn release_err() -> (String, String, String) -> Result[Bool, (Int, String)] {
  fn(_owner, _repo, _ref) { Err((500, "api error")) }
}

///|
fn must_not_call() -> (String, String, String) -> Result[Bool, (Int, String)] {
  fn(_owner, _repo, _ref) { panic() }
}

// SHA-shaped ref (40 hex chars)

///|
let sha_ref : String = "a" + String::make(39, 'b')

///|
test "resolve_ref_kind_impl: sha-shaped + commit exists => Sha" {
  assert_eq(
    resolve_ref_kind_impl(sha_ref, commit_ok(true), must_not_call(), "o", "r"),
    Sha,
  )
}

///|
test "resolve_ref_kind_impl: sha-shaped + commit missing + immutable release => ImmutableRelease" {
  assert_eq(
    resolve_ref_kind_impl(sha_ref, commit_ok(false), release_ok(true), "o", "r"),
    ImmutableRelease,
  )
}

///|
test "resolve_ref_kind_impl: sha-shaped + commit missing + mutable release => Branch" {
  assert_eq(
    resolve_ref_kind_impl(
      sha_ref,
      commit_ok(false),
      release_ok(false),
      "o",
      "r",
    ),
    Branch,
  )
}

///|
test "resolve_ref_kind_impl: sha-shaped + commit error + immutable release => ImmutableRelease" {
  assert_eq(
    resolve_ref_kind_impl(sha_ref, commit_err(), release_ok(true), "o", "r"),
    ImmutableRelease,
  )
}

///|
test "resolve_ref_kind_impl: sha-shaped + commit error + release error => Branch" {
  assert_eq(
    resolve_ref_kind_impl(sha_ref, commit_err(), release_err(), "o", "r"),
    Branch,
  )
}

///|
test "resolve_ref_kind_impl: non-sha ref + immutable release => ImmutableRelease" {
  assert_eq(
    resolve_ref_kind_impl("v1.5.0", must_not_call(), release_ok(true), "o", "r"),
    ImmutableRelease,
  )
}

///|
test "resolve_ref_kind_impl: non-sha ref + mutable release => Branch" {
  assert_eq(
    resolve_ref_kind_impl(
      "v1.5.0",
      must_not_call(),
      release_ok(false),
      "o",
      "r",
    ),
    Branch,
  )
}

///|
test "resolve_ref_kind_impl: non-sha ref + release error => Branch" {
  assert_eq(
    resolve_ref_kind_impl("main", must_not_call(), release_err(), "o", "r"),
    Branch,
  )
}

///|
test "cached_ref_kind_resolver_with: same key hits api only once" {
  let mut call_count = 0
  let api : (String, String, String) -> @papion.RefKind = fn(
    _owner,
    _repo,
    _git_ref,
  ) {
    call_count = call_count + 1
    ImmutableRelease
  }
  let resolver = cached_ref_kind_resolver_with(api)
  let r1 = resolver("octocat", "hello-world", "v1.0.0")
  let r2 = resolver("octocat", "hello-world", "v1.0.0")
  assert_eq(call_count, 1)
  assert_eq(r1, ImmutableRelease)
  assert_eq(r2, ImmutableRelease)
}

///|
test "cached_ref_kind_resolver_with: different keys each call api" {
  let mut call_count = 0
  let api : (String, String, String) -> @papion.RefKind = fn(
    _owner,
    _repo,
    _git_ref,
  ) {
    call_count = call_count + 1
    Branch
  }
  let resolver = cached_ref_kind_resolver_with(api)
  ignore(resolver("octocat", "hello-world", "v1.0.0"))
  ignore(resolver("octocat", "hello-world", "v2.0.0"))
  assert_eq(call_count, 2)
}

///|
test "cached_ref_kind_resolver_with: owner/repo case-insensitive" {
  let mut call_count = 0
  let api : (String, String, String) -> @papion.RefKind = fn(
    _owner,
    _repo,
    _git_ref,
  ) {
    call_count = call_count + 1
    Sha
  }
  let resolver = cached_ref_kind_resolver_with(api)
  let r1 = resolver("Actions", "Checkout", "v4")
  let r2 = resolver("actions", "checkout", "v4")
  assert_eq(call_count, 1)
  assert_eq(r1, Sha)
  assert_eq(r2, Sha)
}
