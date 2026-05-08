///|
pub fn normalize_separators(path : String) -> String {
  path.replace_all(old="\\", new="/")
}

///|
/// Returns `"/foo/bar"` (leading slash) or `""` for None/empty.
/// Used for visited-set key building and `via` context strings.
pub fn path_part(path : String?) -> String {
  match path {
    None => ""
    Some(p) => {
      let trimmed = normalize_separators(p).trim(chars="/")
      if trimmed.is_empty() {
        ""
      } else {
        "/\{trimmed}"
      }
    }
  }
}

///|
/// Returns `"foo/bar/"` (trailing slash) or `""` for None/empty.
/// Used as a prefix when constructing GitHub API file paths.
pub fn action_path_prefix(path : String?) -> String {
  match path {
    None => ""
    Some(p) => {
      let trimmed = normalize_separators(p).trim(chars="/")
      if trimmed.is_empty() {
        ""
      } else {
        "\{trimmed}/"
      }
    }
  }
}

///|
/// Returns `Some("foo/bar")` or `None` for None/empty.
/// Used as the canonical stored path in resolved results.
pub fn canonical_path(path : String?) -> String? {
  let prefix = action_path_prefix(path)
  if prefix.is_empty() {
    None
  } else {
    Some(prefix[0:prefix.length() - 1].to_string())
  }
}
