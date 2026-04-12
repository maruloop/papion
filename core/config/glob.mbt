///|
/// Match a glob pattern against text. Case-insensitive.
///
/// Wildcards:
/// - `*`  matches any sequence of non-`/` characters (single segment)
/// - `**` matches any sequence of characters including `/`
pub fn glob_match(pattern : String, text : String) -> Bool {
  glob_match_view(pattern.to_lower()[:], text.to_lower()[:])
}

///|
fn glob_match_view(pattern : StringView, text : StringView) -> Bool {
  if pattern.is_empty() {
    return text.is_empty()
  }
  // Check for ** at current position
  if pattern.has_prefix("**") {
    let rest_pattern = pattern[2:]
    // ** matches zero or more characters — try matching rest at every position
    if glob_match_view(rest_pattern, text) {
      return true
    }
    for i in 1..<=text.length() {
      if glob_match_view(rest_pattern, text[i:]) {
        return true
      }
    }
    return false
  }
  // Check for * at current position
  if pattern.has_prefix("*") {
    let rest_pattern = pattern[1:]
    // * matches zero or more non-slash characters
    let max = match text.find("/") {
      Some(slash) => slash
      None => text.length()
    }
    for i in 0..<=max {
      if glob_match_view(rest_pattern, text[i:]) {
        return true
      }
    }
    return false
  }
  // Literal character: must match
  if text.is_empty() {
    return false
  }
  if pattern[0:1] == text[0:1] {
    glob_match_view(pattern[1:], text[1:])
  } else {
    false
  }
}
