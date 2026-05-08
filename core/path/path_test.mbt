///|
test "normalize_separators: posix path unchanged" {
  assert_eq(normalize_separators("foo/bar"), "foo/bar")
}

///|
test "normalize_separators: windows backslashes become forward slashes" {
  assert_eq(normalize_separators("foo\\bar\\baz"), "foo/bar/baz")
}

///|
test "normalize_separators: mixed separators" {
  assert_eq(normalize_separators("foo\\bar/baz"), "foo/bar/baz")
}

///|
test "path_part: None returns empty string" {
  assert_eq(path_part(None), "")
}

///|
test "path_part: empty string returns empty string" {
  assert_eq(path_part(Some("")), "")
}

///|
test "path_part: simple path gets leading slash" {
  assert_eq(path_part(Some("actions/subdir")), "/actions/subdir")
}

///|
test "path_part: leading slash is normalised away" {
  assert_eq(path_part(Some("/actions/subdir")), "/actions/subdir")
}

///|
test "path_part: trailing slash is normalised away" {
  assert_eq(path_part(Some("actions/subdir/")), "/actions/subdir")
}

///|
test "path_part: windows separator normalised" {
  assert_eq(path_part(Some("actions\\subdir")), "/actions/subdir")
}

///|
test "action_path_prefix: None returns empty string" {
  assert_eq(action_path_prefix(None), "")
}

///|
test "action_path_prefix: empty string returns empty string" {
  assert_eq(action_path_prefix(Some("")), "")
}

///|
test "action_path_prefix: simple path gets trailing slash" {
  assert_eq(action_path_prefix(Some("actions/subdir")), "actions/subdir/")
}

///|
test "action_path_prefix: leading slash stripped" {
  assert_eq(action_path_prefix(Some("/actions/subdir")), "actions/subdir/")
}

///|
test "action_path_prefix: trailing slash normalised to single" {
  assert_eq(action_path_prefix(Some("actions/subdir/")), "actions/subdir/")
}

///|
test "action_path_prefix: windows separator normalised" {
  assert_eq(action_path_prefix(Some("actions\\subdir")), "actions/subdir/")
}

///|
test "canonical_path: None returns None" {
  assert_eq(canonical_path(None), None)
}

///|
test "canonical_path: empty string returns None" {
  assert_eq(canonical_path(Some("")), None)
}

///|
test "canonical_path: simple path returned trimmed" {
  assert_eq(canonical_path(Some("actions/subdir")), Some("actions/subdir"))
}

///|
test "canonical_path: leading and trailing slashes stripped" {
  assert_eq(canonical_path(Some("/actions/subdir/")), Some("actions/subdir"))
}

///|
test "canonical_path: windows separator normalised" {
  assert_eq(canonical_path(Some("actions\\subdir")), Some("actions/subdir"))
}
