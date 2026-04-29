///|
test "glob exact match" {
  @test.assert_eq(glob_match("actions/checkout", "actions/checkout"), true)
}

///|
test "glob exact match case-insensitive" {
  @test.assert_eq(glob_match("Actions/Checkout", "actions/checkout"), true)
  @test.assert_eq(glob_match("actions/checkout", "Actions/Checkout"), true)
}

///|
test "glob exact no match" {
  @test.assert_eq(glob_match("actions/checkout", "actions/setup-node"), false)
}

///|
test "glob star matches single segment" {
  @test.assert_eq(glob_match("actions/*", "actions/checkout"), true)
  @test.assert_eq(glob_match("actions/*", "actions/setup-node"), true)
}

///|
test "glob star case-insensitive" {
  @test.assert_eq(glob_match("Actions/*", "actions/checkout"), true)
  @test.assert_eq(glob_match("actions/*", "Actions/Checkout"), true)
}

///|
test "glob star does not match slash" {
  @test.assert_eq(glob_match("actions/*", "actions/checkout/extra"), false)
}

///|
test "glob star does not match different owner" {
  @test.assert_eq(glob_match("actions/*", "github/codeql-action"), false)
}

///|
test "glob doublestar matches anything" {
  @test.assert_eq(glob_match("actions/**", "actions/checkout"), true)
  @test.assert_eq(glob_match("actions/**", "actions/checkout/extra"), true)
  @test.assert_eq(glob_match("org/**", "org/repo"), true)
}

///|
test "glob doublestar case-insensitive" {
  @test.assert_eq(glob_match("Actions/**", "actions/checkout"), true)
}

///|
test "glob star-star matches any owner/repo" {
  @test.assert_eq(glob_match("*/*", "actions/checkout"), true)
  @test.assert_eq(glob_match("*/*", "org/repo"), true)
}

///|
test "glob no match returns false" {
  @test.assert_eq(glob_match("org/*", "actions/checkout"), false)
}

///|
test "glob empty pattern" {
  @test.assert_eq(glob_match("", "actions/checkout"), false)
  @test.assert_eq(glob_match("", ""), true)
}
