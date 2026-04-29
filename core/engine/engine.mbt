///|
/// Internal queue entry for BFS traversal.
priv struct ScanNode {
  yaml_str : String
  depth : Int
  via : String?
}

///|
fn normalize_key_path(path : String?) -> String? {
  match path {
    None => None
    Some(p) => {
      let trimmed = p.trim(chars="/").to_owned()
      if trimmed.is_empty() {
        None
      } else {
        Some(trimmed)
      }
    }
  }
}

///|
/// Build a visited-set key from an ActionRef: "owner/repo[/path]@ref".
/// Owner and repo are lowercased so the same repo spelled with different
/// case does not bypass dedup or cycle detection.
fn action_ref_key(ref_ : @papion.ActionRef) -> String {
  let path_part = match normalize_key_path(ref_.path) {
    None => ""
    Some(p) => "/\{p}"
  }
  "\{ref_.owner.to_lower()}/\{ref_.repo.to_lower()}\{path_part}@\{ref_.git_ref}"
}

///|
/// Build the visited-set key for the root scan target using the same
/// normalization rules as dependency keys.
fn scan_target_key(target : @papion.ScanTarget) -> String {
  let path_part = match normalize_key_path(target.path) {
    None => ""
    Some(p) => "/\{p}"
  }
  "\{target.owner.to_lower()}/\{target.repo.to_lower()}\{path_part}@\{target.git_ref}"
}

///|
/// Format the context string shown on transitive findings:
/// "via owner/repo[/path]@ref".
fn transitive_context(ref_ : @papion.ActionRef) -> String {
  let path_part = match normalize_key_path(ref_.path) {
    None => ""
    Some(p) => "/\{p}"
  }
  "via \{ref_.owner}/\{ref_.repo}\{path_part}@\{ref_.git_ref}"
}

///|
/// Scan an action against a policy, recursively traversing transitive
/// composite-action dependencies.
///
/// The engine manages traversal state (BFS queue, visited set, depth and node
/// count). The `fetch_action_yml` callback is responsible for I/O: given
/// `(owner, repo, git_ref, path?)` it should return the raw YAML string for
/// that action, or `Err(...)` if unavailable. Fetch errors are silently
/// skipped; those nodes are marked visited but not enqueued.
///
/// Traversal terminates when:
/// - a visited node is encountered (cycle detection)
/// - depth would exceed `@papion.max_scan_depth` (practical depth guard)
/// - `@papion.max_scan_nodes` unique nodes have been scheduled for traversal:
///   once the counter reaches the limit, no new children are fetched or added
///   to the queue, so the remaining already-queued nodes are drained without
///   further expansion (width guard)
///
/// The visited-set key is "owner/repo[/path]@git_ref". Each node is processed
/// at most once. Policy findings are generated for every reference, including
/// repeated references to already-visited nodes.
///
/// Transitive findings carry a `context` field set to "via owner/repo@ref"
/// identifying the immediate parent action where the dependency was found.
pub fn scan(
  target : @papion.ScanTarget,
  action_yml_yaml : String,
  policy : @papion.Policy,
  fetch_action_yml : (String, String, String, String?) -> Result[String, String],
  resolve_ref_kind? : (String, String, String) -> @papion.RefKind = fn(
    _owner,
    _repo,
    git_ref,
  ) {
    @rules.classify_ref(git_ref)
  },
) -> Result[@papion.ScanResult, String] {
  let policy = match policy.normalized() {
    Ok(p) => p
    Err(e) => return Err(e)
  }
  let all_findings : Array[@papion.Finding] = []
  let visited : Map[String, Bool] = {}
  let initial_key = scan_target_key(target)
  visited[initial_key] = true
  let queue : Array[ScanNode] = []
  queue.push({ yaml_str: action_yml_yaml, depth: 0, via: None })
  let mut scheduled_count = 1
  let mut i = 0
  let mut node_count = 0
  while i < queue.length() {
    let node = queue[i]
    i = i + 1
    node_count = node_count + 1
    let is_root = node_count == 1
    match @parser.parse_action_yml(node.yaml_str) {
      Err(e) => if is_root { return Err(e) }
      Ok(yml) => {
        let refs = @parser.extract_refs(yml)
        for ref_ in refs {
          let ref_kind = if policy.sha_pinning {
            resolve_ref_kind(ref_.owner, ref_.repo, ref_.git_ref)
          } else {
            Branch
          }
          let ref_findings = @rules.evaluate(ref_, ref_kind, policy)
          for finding in ref_findings {
            let with_context = match node.via {
              None => finding
              Some(v) => { ..finding, context: Some(v) }
            }
            all_findings.push(with_context)
          }
          let ref_key = action_ref_key(ref_)
          match visited.get(ref_key) {
            Some(_) => ()
            None => {
              visited[ref_key] = true
              if node.depth < @papion.max_scan_depth &&
                scheduled_count < @papion.max_scan_nodes {
                scheduled_count = scheduled_count + 1
                match
                  fetch_action_yml(
                    ref_.owner,
                    ref_.repo,
                    ref_.git_ref,
                    ref_.path,
                  ) {
                  Ok(fetched_yaml) =>
                    queue.push({
                      yaml_str: fetched_yaml,
                      depth: node.depth + 1,
                      via: Some(transitive_context(ref_)),
                    })
                  Err(_) => ()
                }
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
