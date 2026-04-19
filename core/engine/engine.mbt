///|
/// Scan an action against a policy.
///
/// Parses action_yml_yaml (raw YAML) and config_json (JSON policy, empty = defaults),
/// extracts all action refs from composite steps, evaluates each ref against the
/// policy, and returns a ScanResult with aggregated findings and summary counts.
pub fn scan(
  target : @papion.ScanTarget,
  action_yml_yaml : String,
  config_json : String,
) -> Result[@papion.ScanResult, String] {
  let yml = match @parser.parse_action_yml(action_yml_yaml) {
    Ok(y) => y
    Err(e) => return Err(e)
  }
  let effective_config = if config_json.is_empty() { "{}" } else { config_json }
  let policy = match @config.parse_policy(effective_config) {
    Ok(p) => p
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
