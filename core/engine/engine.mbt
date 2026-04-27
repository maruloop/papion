///|
fn action_ref_key(ref_ : @papion.ActionRef) -> String {
  let path_part = match ref_.path {
    None => ""
    Some(p) => "/\{p}"
  }
  "\{ref_.owner}/\{ref_.repo}\{path_part}@\{ref_.git_ref}"
}

///|
/// Scan an action against a policy.
///
/// Parses action_yml_yaml (raw YAML), extracts all action refs from composite
/// steps, evaluates each ref against the provided policy, and returns a
/// ScanResult with aggregated findings and summary counts.
/// The policy is normalized and validated before evaluation so callers may
/// pass either `parse_policy` output or a programmatically constructed Policy.
///
/// When `fetch_action_yml` is provided, the engine performs a BFS traversal of
/// transitive dependencies. Each fetched action.yml is parsed and its refs are
/// evaluated. The visited set (keyed by `owner/repo[/path]@ref`) prevents
/// re-fetching cycles. Traversal is bounded by `max_scan_depth` and
/// `max_scan_nodes`. Fetch errors and unparseable transitive YAMLs are silently
/// skipped; only root parse failures propagate as `Err`.
///
/// `resolve_ref_kind` is only called when `policy.sha_pinning` is true,
/// avoiding unnecessary I/O (e.g. GitHub API calls) when SHA pinning is disabled.
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
  fetch_action_yml? : ((String, String, String, String?) -> Result[
    String,
    String,
  ])? = None,
) -> Result[@papion.ScanResult, String] {
  let policy = match policy.normalized() {
    Ok(policy) => policy
    Err(err) => return Err(err)
  }
  let queue : Array[(String, Int, Array[String])] = []
  let visited : Map[String, Bool] = {}
  visited["\{target.owner}/\{target.repo}@\{target.git_ref}"] = true
  queue.push((action_yml_yaml, 0, []))
  let all_findings : Array[@papion.Finding] = []
  let mut node_count = 0
  let mut i = 0
  while i < queue.length() {
    let (yaml_str, depth, chain) = queue[i]
    i += 1
    node_count += 1
    let is_root = node_count == 1
    let yml = match @parser.parse_action_yml(yaml_str) {
      Err(e) => if is_root { return Err(e) } else { continue }
      Ok(y) => y
    }
    let refs = @parser.extract_refs(yml)
    for ref_ in refs {
      let ref_kind = if policy.sha_pinning {
        resolve_ref_kind(ref_.owner, ref_.repo, ref_.git_ref)
      } else {
        Branch
      }
      let findings = @rules.evaluate(ref_, ref_kind, policy)
      let context = if chain.is_empty() {
        None
      } else {
        Some(chain.join(" > "))
      }
      for f in findings {
        all_findings.push({ ..f, context, })
      }
      match fetch_action_yml {
        None => ()
        Some(fetch) => {
          let ref_key = action_ref_key(ref_)
          if visited.get(ref_key) is None {
            visited[ref_key] = true
            if depth < @papion.max_scan_depth &&
              queue.length() < @papion.max_scan_nodes {
              match fetch(ref_.owner, ref_.repo, ref_.git_ref, ref_.path) {
                Ok(yaml) => {
                  let child_chain = chain.copy()
                  child_chain.push(action_ref_key(ref_))
                  queue.push((yaml, depth + 1, child_chain))
                }
                Err(_) => ()
              }
            }
          }
        }
      }
    }
  }
  let failures = all_findings.iter().filter(fn(f) { f.level == Fail }).count()
  let warnings = all_findings.iter().filter(fn(f) { f.level == Warn }).count()
  Ok({ target, findings: all_findings, summary: { failures, warnings } })
}
