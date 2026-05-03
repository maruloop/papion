///|
/// Internal queue entry for BFS traversal.
priv struct ScanNode {
  yaml_str : String
  depth : Int
  via : String?
  base_dir : String?
}

///|
priv enum RootKind {
  Action
  Workflow
} derive(Eq)

///|
priv enum VisitedKey {
  GitHub(String)
  Local(String)
} derive(Eq, Hash)

///|
fn normalize_path_part(path : String?) -> String {
  match path {
    None => ""
    Some(p) => {
      let trimmed = p.trim(chars="/")
      if trimmed.is_empty() {
        ""
      } else {
        "/\{trimmed}"
      }
    }
  }
}

///|
/// Owner and repo are lowercased so the same repo spelled with different
/// case does not bypass dedup or cycle detection.
fn action_ref_key(ref_ : @papion.ActionRef) -> VisitedKey {
  let path_part = normalize_path_part(ref_.path)
  GitHub("\{ref_.owner.to_lower()}/\{ref_.repo.to_lower()}\{path_part}@\{ref_.git_ref}")
}

///|
fn scan_target_key(target : @papion.ScanTarget) -> VisitedKey {
  match target {
    @papion.GitHub({ owner, repo, git_ref, path }) => {
      let path_part = normalize_path_part(path)
      GitHub("\{owner.to_lower()}/\{repo.to_lower()}\{path_part}@\{git_ref}")
    }
    @papion.Local({ path }) => Local(path)
  }
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
/// For Local-rooted scans, `fetch_local` resolves relative `uses: ./...`
/// references. Given `(base_dir, rel_path)` it returns `(abs_path, yaml)` or
/// `Err(reason)`. On error a Warn finding is emitted. Pass `None` for GitHub
/// roots where local refs are unresolvable.
///
/// Traversal terminates when:
/// - a visited node is encountered (cycle detection)
/// - depth would exceed `@papion.max_scan_depth` (practical depth guard)
/// - `@papion.max_scan_nodes` unique nodes have been scheduled for traversal:
///   once the counter reaches the limit, no new children are fetched or added
///   to the queue, so the remaining already-queued nodes are drained without
///   further expansion (width guard)
///
/// The visited set uses `VisitedKey` — `GitHub(key_string)` for GitHub refs
/// and `Local(abs_path)` for local refs — so the two namespaces cannot collide.
/// Each node is processed at most once.
/// Policy findings are generated for every reference, including repeated
/// references to already-visited nodes.
///
/// Transitive findings carry a `context` field set to "via owner/repo@ref"
/// identifying the immediate parent action where the dependency was found.
fn summarize_findings(
  target : @papion.ScanTarget,
  findings : Array[@papion.Finding],
) -> @papion.ScanResult {
  let mut failures = 0
  let mut warnings = 0
  for f in findings {
    match f.level {
      Fail => failures = failures + 1
      Warn => warnings = warnings + 1
    }
  }
  { target, findings, summary: { failures, warnings } }
}

///|
fn scan_impl(
  target : @papion.ScanTarget,
  root_yaml : String,
  policy : @papion.Policy,
  fetch_action_yml : (String, String, String, String?) -> Result[String, String],
  root_kind : RootKind,
  fetch_local? : (String, String) -> Result[(String, String), String] = fn(
    _base_dir,
    rel_path,
  ) {
    Err("local ref not resolvable from GitHub root: \{rel_path}")
  },
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
  let root_base_dir : String? = match target {
    @papion.Local({ path }) =>
      match path.rev_find("/") {
        Some(idx) => Some(path[:idx].to_string())
        None => Some(".")
      }
    @papion.GitHub(_) => None
  }
  let all_findings : Array[@papion.Finding] = []
  let visited : Map[VisitedKey, Bool] = {}
  let initial_key = scan_target_key(target)
  visited[initial_key] = true
  let queue : Array[ScanNode] = []
  queue.push({
    yaml_str: root_yaml,
    depth: 0,
    via: None,
    base_dir: root_base_dir,
  })
  let mut scheduled_count = 1
  let mut i = 0
  let mut node_count = 0
  while i < queue.length() {
    let node = queue[i]
    i = i + 1
    node_count = node_count + 1
    let is_root = node_count == 1
    let refs = if is_root && root_kind == Workflow {
      match @parser.parse_workflow_yml(node.yaml_str) {
        Err(e) => return Err(e)
        Ok(yml) => @parser.extract_refs_from_workflow(yml)
      }
    } else {
      match @parser.parse_action_yml(node.yaml_str) {
        Err(e) => if is_root { return Err(e) } else { [] }
        Ok(yml) => @parser.extract_refs(yml)
      }
    }
    for parsed_ref in refs {
      match parsed_ref {
        @papion.GitHub(ref_) => {
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
                      via: Some(
                        "via \{ref_.owner}/\{ref_.repo}\{normalize_path_part(ref_.path)}@\{ref_.git_ref}",
                      ),
                      base_dir: None,
                    })
                  Err(_) => ()
                }
              }
            }
          }
        }
        @papion.LocalPath(rel_path) =>
          match node.base_dir {
            None => ()
            Some(base_dir) =>
              match fetch_local(base_dir, rel_path) {
                Err(reason) => {
                  let finding : @papion.Finding = {
                    level: Warn,
                    rule: "local-ref-unresolvable",
                    target: rel_path,
                    context: node.via,
                    message: "local action reference could not be resolved: \{reason}",
                    suggestion: None,
                  }
                  all_findings.push(finding)
                }
                Ok((abs_path, fetched_yaml)) => {
                  let local_key = Local(abs_path)
                  match visited.get(local_key) {
                    Some(_) => ()
                    None => {
                      visited[local_key] = true
                      if node.depth < @papion.max_scan_depth &&
                        scheduled_count < @papion.max_scan_nodes {
                        scheduled_count = scheduled_count + 1
                        let child_base_dir = match abs_path.rev_find("/") {
                          Some(idx) => abs_path[:idx].to_string()
                          None => "."
                        }
                        queue.push({
                          yaml_str: fetched_yaml,
                          depth: node.depth + 1,
                          via: node.via,
                          base_dir: Some(child_base_dir),
                        })
                      }
                    }
                  }
                }
              }
          }
      }
    }
  }
  Ok(summarize_findings(target, all_findings))
}

///|
pub fn scan(
  target : @papion.ScanTarget,
  action_yml_yaml : String,
  policy : @papion.Policy,
  fetch_action_yml : (String, String, String, String?) -> Result[String, String],
  fetch_local? : (String, String) -> Result[(String, String), String] = fn(
    _base_dir,
    rel_path,
  ) {
    Err("local ref not resolvable from GitHub root: \{rel_path}")
  },
  resolve_ref_kind? : (String, String, String) -> @papion.RefKind = fn(
    _owner,
    _repo,
    git_ref,
  ) {
    @rules.classify_ref(git_ref)
  },
) -> Result[@papion.ScanResult, String] {
  scan_impl(
    target,
    action_yml_yaml,
    policy,
    fetch_action_yml,
    Action,
    fetch_local~,
    resolve_ref_kind~,
  )
}

///|
pub fn scan_workflow(
  target : @papion.ScanTarget,
  workflow_yaml : String,
  policy : @papion.Policy,
  fetch_action_yml : (String, String, String, String?) -> Result[String, String],
  fetch_local? : (String, String) -> Result[(String, String), String] = fn(
    _base_dir,
    rel_path,
  ) {
    Err("local ref not resolvable from GitHub root: \{rel_path}")
  },
  resolve_ref_kind? : (String, String, String) -> @papion.RefKind = fn(
    _owner,
    _repo,
    git_ref,
  ) {
    @rules.classify_ref(git_ref)
  },
) -> Result[@papion.ScanResult, String] {
  scan_impl(
    target,
    workflow_yaml,
    policy,
    fetch_action_yml,
    Workflow,
    fetch_local~,
    resolve_ref_kind~,
  )
}
