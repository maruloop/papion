///|
/// Scan an action against a policy.
///
/// Parses action_yml_yaml (raw YAML), extracts all action refs from composite
/// steps, evaluates each ref against the provided policy, and returns a
/// ScanResult with aggregated findings and summary counts.
/// The policy is normalized and validated before evaluation so callers may
/// pass either `parse_policy` output or a programmatically constructed Policy.
pub fn scan(
  target : @papion.ScanTarget,
  action_yml_yaml : String,
  policy : @papion.Policy,
) -> Result[@papion.ScanResult, String] {
  let policy = match policy.normalized() {
    Ok(policy) => policy
    Err(err) => return Err(err)
  }
  let yml = match @parser.parse_action_yml(action_yml_yaml) {
    Ok(y) => y
    Err(e) => return Err(e)
  }
  let refs = @parser.extract_refs(yml)
  let findings : Array[@papion.Finding] = []
  for ref_ in refs {
    findings.append(@rules.evaluate(ref_, policy))
  }
  let failures = findings.iter().filter(fn(f) { f.level == Fail }).count()
  let warnings = findings.iter().filter(fn(f) { f.level == Warn }).count()
  Ok({ target, findings, summary: { failures, warnings } })
}

///|
fn action_ref_key(ref_ : @papion.ActionRef) -> String {
  let base = ref_.owner + "/" + ref_.repo
  let with_path = match ref_.path {
    Some(p) => base + "/" + p
    None => base
  }
  with_path + "@" + ref_.git_ref
}

///|
fn scan_refs_recursive(
  refs : Array[@papion.ActionRef],
  policy : @papion.Policy,
  fetch_action_yml : (String, String, String, String?) -> Result[
    (String, String),
    String,
  ],
  seen : Map[String, Unit],
  findings : Array[@papion.Finding],
) -> Unit {
  for ref_ in refs {
    findings.append(@rules.evaluate(ref_, policy))
    let key = action_ref_key(ref_)
    if seen.get(key) is None {
      seen[key] = ()
      match fetch_action_yml(ref_.owner, ref_.repo, ref_.git_ref, ref_.path) {
        Ok((sub_yml, _)) => {
          let sub_refs = match @parser.parse_action_yml(sub_yml) {
            Ok(y) => @parser.extract_refs(y)
            Err(_) => []
          }
          scan_refs_recursive(sub_refs, policy, fetch_action_yml, seen, findings)
        }
        Err(_) => ()
      }
    }
  }
}

///|
/// Scan an action and its composite sub-actions recursively against a policy.
///
/// Recursively follows composite step dependencies to detect findings across
/// the full transitive dependency tree. Uses a hash map to track already-
/// scanned actions and break dependency cycles, preventing infinite loops.
/// Sub-actions that cannot be fetched or parsed are silently skipped.
///
/// `fetch_action_yml` receives `(owner, repo, git_ref, path?)` and returns
/// `(yaml_content, resolved_git_ref)` for the action at that ref.
pub fn scan_deep(
  target : @papion.ScanTarget,
  action_yml_yaml : String,
  policy : @papion.Policy,
  fetch_action_yml : (String, String, String, String?) -> Result[
    (String, String),
    String,
  ],
) -> Result[@papion.ScanResult, String] {
  let policy = match policy.normalized() {
    Ok(policy) => policy
    Err(err) => return Err(err)
  }
  let yml = match @parser.parse_action_yml(action_yml_yaml) {
    Ok(y) => y
    Err(e) => return Err(e)
  }
  let refs = @parser.extract_refs(yml)
  let findings : Array[@papion.Finding] = []
  let seen : Map[String, Unit] = {}
  seen[
    action_ref_key({
      owner: target.owner,
      repo: target.repo,
      git_ref: target.git_ref,
      path: None,
    }),
  ] = ()
  scan_refs_recursive(refs, policy, fetch_action_yml, seen, findings)
  let failures = findings.iter().filter(fn(f) { f.level == Fail }).count()
  let warnings = findings.iter().filter(fn(f) { f.level == Warn }).count()
  Ok({ target, findings, summary: { failures, warnings } })
}
