///|
/// Classify a git ref by its format.
///
/// Returns `Sha` if the ref is exactly 40 hex characters (case-insensitive).
/// Returns `Branch` for everything else — the pure core cannot distinguish
/// tags from branches without API access, so the stricter classification is used.
pub fn classify_ref(git_ref : String) -> @papion.RefKind {
  if git_ref.length() != 40 {
    return Branch
  }
  for ch in git_ref.iter() {
    match ch {
      '0'..='9' | 'a'..='f' | 'A'..='F' => ()
      _ => return Branch
    }
  }
  Sha
}

///|
/// Check the SHA-pinning rule against an action reference.
///
/// Produces a Fail finding when sha_pinning is enabled and the ref is neither
/// a verified commit SHA nor an immutable release. Returns an empty array when
/// the rule is disabled or the ref is already pinned.
pub fn check_sha_pinning(
  action_ref : @papion.ActionRef,
  ref_kind : @papion.RefKind,
  policy : @papion.Policy,
) -> Array[@papion.Finding] {
  if !policy.sha_pinning {
    return []
  }
  match ref_kind {
    Sha | ImmutableRelease => return []
    _ => ()
  }
  [
    {
      level: Fail,
      rule: "sha-pinning",
      target: action_ref.format_ref(),
      context: None,
      message: "action ref is not pinned to a SHA or immutable release",
      suggestion: Some(
        "pin to a full commit SHA (e.g. @abc123...) or an immutable release tag",
      ),
    },
  ]
}

///|
/// Check the allowed-list rule against an action reference.
///
/// Produces a Fail finding when the allowed list is non-empty and the action
/// does not match any pattern. An empty allowed list passes all actions.
/// Patterns in policy.allowed must be pre-normalized to lowercase (use parse_policy).
pub fn check_allowed(
  action_ref : @papion.ActionRef,
  policy : @papion.Policy,
) -> Array[@papion.Finding] {
  if @config.matches_allowed(policy, action_ref) {
    return []
  }
  [
    {
      level: Fail,
      rule: "allowed-list",
      target: action_ref.format_ref(),
      context: None,
      message: "action is not in the allowed list",
      suggestion: None,
    },
  ]
}

///|
/// Check the disallowed-list rule against an action reference.
///
/// Produces a Fail finding when the action matches any disallowed pattern.
/// Patterns in policy.disallowed must be pre-normalized to lowercase (use parse_policy).
pub fn check_disallowed(
  action_ref : @papion.ActionRef,
  policy : @papion.Policy,
) -> Array[@papion.Finding] {
  if !@config.matches_disallowed(policy, action_ref) {
    return []
  }
  [
    {
      level: Fail,
      rule: "disallowed-list",
      target: action_ref.format_ref(),
      context: None,
      message: "action matches a disallowed pattern",
      suggestion: None,
    },
  ]
}

///|
/// Apply all policy rules to an action reference and collect findings.
///
/// Rules run in order: sha-pinning, allowed-list, disallowed-list.
/// All findings are collected — rules are independent.
pub fn evaluate(
  action_ref : @papion.ActionRef,
  ref_kind : @papion.RefKind,
  policy : @papion.Policy,
) -> Array[@papion.Finding] {
  let findings : Array[@papion.Finding] = []
  findings.append(check_sha_pinning(action_ref, ref_kind, policy))
  findings.append(check_allowed(action_ref, policy))
  findings.append(check_disallowed(action_ref, policy))
  findings
}
