///|
pub let version : String = "0.1.0"

///|
pub let max_policy_pattern_len : Int = 256

///|
/// Maximum depth of recursive action dependency traversal.
/// Root action is depth 0; its direct dependencies are depth 1.
pub let max_scan_depth : Int = 10

///|
/// Maximum number of unique action nodes scheduled/attempted during recursive
/// traversal.
/// Prevents runaway traversal work on unusually wide dependency graphs.
pub let max_scan_nodes : Int = 100

///|
/// Maximum number of local YAML files collected during a local directory scan.
/// Separate from max_scan_nodes so tuning one does not silently affect the other.
pub let max_local_root_files : Int = 200

///|
pub fn cli_user_agent() -> String {
  "papion/\{version} (+https://github.com/maruloop/papion)"
}

///|
fn normalize_policy_patterns(
  patterns : Array[String],
  field_name : String,
) -> Result[Array[String], String] {
  let normalized : Array[String] = []
  for pattern in patterns {
    if pattern.length() > max_policy_pattern_len {
      return Err(
        "pattern too long in '\{field_name}': \{pattern.length()} chars (max \{max_policy_pattern_len})",
      )
    }
    normalized.push(pattern.to_lower())
  }
  Ok(normalized)
}

///|
pub(all) struct ActionRef {
  owner : String
  repo : String
  git_ref : String
  path : String?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ActionRef::format_ref(self : ActionRef) -> String {
  let path_part = match self.path {
    Some(p) => "/\{p}"
    None => ""
  }
  "\{self.owner}/\{self.repo}\{path_part}@\{self.git_ref}"
}

///|
pub impl Show for ActionRef with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
/// A parsed `uses:` value from a workflow step or composite action step.
/// GitHub refs are resolved via the GitHub Contents API; local refs are
/// resolved relative to the file that references them (Local-rooted scans only).
pub(all) enum ParsedRef {
  GitHub(ActionRef)
  LocalPath(String)
} derive(Debug, Eq)

///|
pub impl Show for ParsedRef with output(self, logger) {
  match self {
    GitHub(r) => {
      logger.write_string("GitHub(")
      r.output(logger)
      logger.write_string(")")
    }
    LocalPath(p) => {
      logger.write_string("LocalPath(")
      p.output(logger)
      logger.write_string(")")
    }
  }
}

///|
pub(all) enum RefKind {
  Sha
  Tag
  Branch
  ImmutableRelease
} derive(Debug, Eq, ToJson, FromJson)

///|
pub impl Show for RefKind with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
pub(all) struct ActionYml {
  name : String
  description : String?
  runs : Runs
} derive(Debug, Eq, ToJson, FromJson)

///|
pub impl Show for ActionYml with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
pub(all) struct Runs {
  runner : String
  steps : Array[CompositeStep]?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub impl Show for Runs with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
pub(all) struct CompositeStep {
  uses : String?
  run : String?
  name : String?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub impl Show for CompositeStep with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
pub(all) struct WorkflowYml {
  name : String?
  jobs : Map[String, WorkflowJob]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub impl Show for WorkflowYml with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
pub(all) struct WorkflowJob {
  uses : String?
  steps : Array[WorkflowStep]?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub impl Show for WorkflowJob with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
pub(all) struct WorkflowStep {
  uses : String?
  run : String?
  name : String?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub impl Show for WorkflowStep with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
pub(all) enum FindingLevel {
  Warn
  Fail
} derive(Debug, Eq, ToJson, FromJson)

///|
pub impl Show for FindingLevel with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
pub(all) struct Finding {
  level : FindingLevel
  rule : String
  target : String
  context : String?
  message : String
  suggestion : String?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub impl Show for Finding with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
pub(all) struct Policy {
  sha_pinning : Bool
  allowed : Array[String]
  disallowed : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub impl Show for Policy with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
pub fn Policy::default() -> Policy {
  { sha_pinning: true, allowed: [], disallowed: [] }
}

///|
pub fn Policy::normalized(self : Policy) -> Result[Policy, String] {
  let allowed = match normalize_policy_patterns(self.allowed, "allowed") {
    Ok(patterns) => patterns
    Err(err) => return Err(err)
  }
  let disallowed = match
    normalize_policy_patterns(self.disallowed, "disallowed") {
    Ok(patterns) => patterns
    Err(err) => return Err(err)
  }
  Ok({ ..self, allowed, disallowed })
}

///|
pub(all) struct GitHubScanTarget {
  owner : String
  repo : String
  git_ref : String
  path : String?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct LocalScanTarget {
  path : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) enum ScanTarget {
  GitHub(GitHubScanTarget)
  Local(LocalScanTarget)
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ScanTarget::format_target(self : ScanTarget) -> String {
  match self {
    GitHub({ owner, repo, git_ref, path }) => {
      let path_part = match path {
        Some(p) => "/\{p}"
        None => ""
      }
      "\{owner}/\{repo}\{path_part}@\{git_ref}"
    }
    Local({ path }) => "local:\{path}"
  }
}

///|
pub impl Show for ScanTarget with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
pub(all) struct Summary {
  failures : Int
  warnings : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub impl Show for Summary with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
pub(all) struct ScanResult {
  target : ScanTarget
  findings : Array[Finding]
  summary : Summary
} derive(Debug, Eq, ToJson, FromJson)

///|
pub impl Show for ScanResult with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}
