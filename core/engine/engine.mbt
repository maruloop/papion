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
  resolve_ref_kind? : (String, String, String) -> @papion.RefKind = fn(
    _owner,
    _repo,
    git_ref,
  ) {
    @rules.classify_ref(git_ref)
  },
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
    let ref_kind = resolve_ref_kind(ref_.owner, ref_.repo, ref_.git_ref)
    findings.append(@rules.evaluate(ref_, ref_kind, policy))
  }
  let failures = findings.iter().filter(fn(f) { f.level == Fail }).count()
  let warnings = findings.iter().filter(fn(f) { f.level == Warn }).count()
  Ok({ target, findings, summary: { failures, warnings } })
}
