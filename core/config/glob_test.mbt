///|
test "glob exact match" {
  assert_eq(glob_match("actions/checkout", "actions/checkout"), true)
}

///|
test "glob exact match case-insensitive" {
  assert_eq(glob_match("Actions/Checkout", "actions/checkout"), true)
  assert_eq(glob_match("actions/checkout", "Actions/Checkout"), true)
}

///|
test "glob exact no match" {
  assert_eq(glob_match("actions/checkout", "actions/setup-node"), false)
}

///|
test "glob star matches single segment" {
  assert_eq(glob_match("actions/*", "actions/checkout"), true)
  assert_eq(glob_match("actions/*", "actions/setup-node"), true)
}

///|
test "glob star case-insensitive" {
  assert_eq(glob_match("Actions/*", "actions/checkout"), true)
  assert_eq(glob_match("actions/*", "Actions/Checkout"), true)
}

///|
test "glob star does not match slash" {
  assert_eq(glob_match("actions/*", "actions/checkout/extra"), false)
}

///|
test "glob star does not match different owner" {
  assert_eq(glob_match("actions/*", "github/codeql-action"), false)
}

///|
test "glob doublestar matches anything" {
  assert_eq(glob_match("actions/**", "actions/checkout"), true)
  assert_eq(glob_match("actions/**", "actions/checkout/extra"), true)
  assert_eq(glob_match("org/**", "org/repo"), true)
}

///|
test "glob doublestar case-insensitive" {
  assert_eq(glob_match("Actions/**", "actions/checkout"), true)
}

///|
test "glob star-star matches any owner/repo" {
  assert_eq(glob_match("*/*", "actions/checkout"), true)
  assert_eq(glob_match("*/*", "org/repo"), true)
}

///|
test "glob no match returns false" {
  assert_eq(glob_match("org/*", "actions/checkout"), false)
}

///|
test "glob empty pattern" {
  assert_eq(glob_match("", "actions/checkout"), false)
  assert_eq(glob_match("", ""), true)
}
