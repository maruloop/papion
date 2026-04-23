///|
/// Parse a policy configuration JSON string into a Policy.
///
/// The host converts TOML to JSON before passing to this function.
/// Missing fields use defaults: sha_pinning=true, allowed=[], disallowed=[].
/// Returns Err if any pattern exceeds 256 characters.
/// Patterns are normalized to lowercase before returning.
pub fn parse_policy(json_str : String) -> Result[@papion.Policy, String] {
  try {
    let json = @json.parse(json_str)
    guard json is Object(obj) else {
      return Err("expected JSON object for Policy")
    }
    let obj = match obj.get("policy") {
      None => obj
      Some(Object(inner)) => inner
      Some(_) => return Err("invalid 'policy' field: expected object")
    }
    let sha_pinning = match obj.get("sha_pinning") {
      Some(True) => true
      Some(False) => false
      None => true
      Some(_) => return Err("invalid 'sha_pinning' field: expected boolean")
    }
    let allowed = match obj.get("allowed") {
      None => []
      Some(Array(arr)) => {
        let patterns : Array[String] = []
        for item in arr {
          match item {
            String(s) => patterns.push(s)
            _ => return Err("invalid entry in 'allowed': expected string")
          }
        }
        patterns
      }
      Some(_) => return Err("invalid 'allowed' field: expected array")
    }
    let disallowed = match obj.get("disallowed") {
      None => []
      Some(Array(arr)) => {
        let patterns : Array[String] = []
        for item in arr {
          match item {
            String(s) => patterns.push(s)
            _ => return Err("invalid entry in 'disallowed': expected string")
          }
        }
        patterns
      }
      Some(_) => return Err("invalid 'disallowed' field: expected array")
    }
    @papion.Policy::{ sha_pinning, allowed, disallowed }.normalized()
  } catch {
    e => Err(e.to_string())
  }
}

///|
/// Returns true if the action ref is allowed by the policy.
///
/// If the allowed list is empty, all refs are allowed (pass-all).
/// Otherwise, the ref must match at least one pattern.
/// Matching is against "owner/repo" (case-insensitive).
/// Patterns in policy.allowed must be pre-normalized to lowercase (use parse_policy).
pub fn matches_allowed(
  policy : @papion.Policy,
  action_ref : @papion.ActionRef,
) -> Bool {
  if policy.allowed.is_empty() {
    return true
  }
  let target = (action_ref.owner + "/" + action_ref.repo).to_lower()
  policy.allowed.iter().any(fn(pattern) { glob_match_lowered(pattern, target) })
}

///|
/// Returns true if the action ref is disallowed by the policy.
///
/// Matching is against "owner/repo" (case-insensitive).
/// Patterns in policy.disallowed must be pre-normalized to lowercase (use parse_policy).
pub fn matches_disallowed(
  policy : @papion.Policy,
  action_ref : @papion.ActionRef,
) -> Bool {
  let target = (action_ref.owner + "/" + action_ref.repo).to_lower()
  policy.disallowed
  .iter()
  .any(fn(pattern) { glob_match_lowered(pattern, target) })
}
