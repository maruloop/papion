///|
pub fn exit_code_for(summary : @papion.Summary, fail_on : FailOnLevel) -> Int {
  match fail_on {
    NoneLevel => 0
    Fail => if summary.failures > 0 { 1 } else { 0 }
    Warn => if summary.failures > 0 || summary.warnings > 0 { 1 } else { 0 }
  }
}

///|
pub(all) struct RunOutcome {
  exit_code : Int
  output : String
} derive(Debug, Eq)

///|
pub impl Show for RunOutcome with output(self, logger) {
  logger.write_string("RunOutcome(exit_code: ")
  logger.write_string(self.exit_code.to_string())
  logger.write_string(", output: ")
  self.output.output(logger)
  logger.write_string(")")
}

///|
pub(all) enum LocalScanKind {
  Action
  Workflow
} derive(Debug, Eq)

///|
pub(all) struct LocalScanUnit {
  kind : LocalScanKind
  abs_path : String
  yaml : String
} derive(Debug, Eq)

///|
fn parent_path(path : String) -> String? {
  let trimmed = path.trim_end(chars="/")
  match trimmed.rev_find("/") {
    Some(idx) => Some(trimmed[:idx].to_string())
    None => None
  }
}

///|
/// Compute the repo root for a workflow file at <repo>/.github/workflows/<name>.yml.
/// Returns None for workflow files not under .github/workflows so the engine
/// defaults to the workflow file's own directory instead of an incorrect base.
fn workflow_repo_root(abs_path : String) -> String? {
  match parent_path(abs_path) {
    None => None
    Some(workflows_dir) => {
      let wf_name = match workflows_dir.rev_find("/") {
        Some(idx) => workflows_dir[idx + 1:].to_string()
        None => workflows_dir
      }
      if wf_name != "workflows" {
        return None
      }
      match parent_path(workflows_dir) {
        None => None
        Some(github_dir) => {
          let gh_name = match github_dir.rev_find("/") {
            Some(idx) => github_dir[idx + 1:].to_string()
            None => github_dir
          }
          if gh_name != ".github" {
            return None
          }
          parent_path(github_dir)
        }
      }
    }
  }
}

///|
fn aggregate_summary(results : Array[@papion.ScanResult]) -> @papion.Summary {
  let mut failures = 0
  let mut warnings = 0
  for result in results {
    failures = failures + result.summary.failures
    warnings = warnings + result.summary.warnings
  }
  { failures, warnings }
}

///|
fn format_results(
  results : Array[@papion.ScanResult],
  fail_on : FailOnLevel,
  output_format : OutputFormat,
  force_array : Bool,
) -> RunOutcome {
  let output = match output_format {
    Human =>
      if results.length() == 1 && !force_array {
        @format.format_human(results[0])
      } else {
        let buf = StringBuilder::new()
        let mut first = true
        for result in results {
          if !first {
            buf.write_string("\n\n")
          }
          first = false
          buf.write_string("==> ")
          buf.write_string(result.target.format_target())
          buf.write_string(" <==\n")
          buf.write_string(@format.format_human(result))
        }
        buf.to_string()
      }
    Json =>
      if results.length() == 1 && !force_array {
        @format.format_json(results[0])
      } else {
        "[" +
        results.map(fn(result) { @format.format_json(result) }).join(",") +
        "]"
      }
  }
  let summary = aggregate_summary(results)
  { exit_code: exit_code_for(summary, fail_on), output }
}

///|
pub fn run_with_host(
  args : Array[String],
  load_config : (String?) -> Result[@papion.Policy, String],
  fetch_action_yml : (String, String, String?, String?, Bool) -> Result[
    (String, String, String?),
    String,
  ],
  read_local_target : (String) -> Result[Array[LocalScanUnit], String],
  fetch_local? : (String, String) -> Result[(String, String), String],
  resolve_ref_kind? : (String, String, String) -> @papion.RefKind = fn(
    _owner,
    _repo,
    git_ref,
  ) {
    @rules.classify_ref(git_ref)
  },
) -> Result[RunOutcome, CliError] {
  let options = match parse_args(args) {
    Ok(options) => options
    Err(err) => return Err(err)
  }
  let policy = match load_config(options.config) {
    Ok(policy) => policy
    Err(err) => return Err(RuntimeError(err))
  }
  let engine_fetch = fn(
    owner : String,
    repo : String,
    git_ref : String,
    path : String?,
  ) -> Result[String, String] {
    match fetch_action_yml(owner, repo, Some(git_ref), path, false) {
      Ok((yaml, _, _)) => Ok(yaml)
      Err(err) => Err(err)
    }
  }
  match options.target {
    GitHub({ owner, repo, path, git_ref, allow_ref_fallback }) => {
      let (action_yml, resolved_git_ref, resolved_path) = match
        fetch_action_yml(owner, repo, git_ref, path, allow_ref_fallback) {
        Ok(result) => result
        Err(err) => return Err(RuntimeError(err))
      }
      let result = match
        @engine.scan(
          @papion.GitHub({
            owner,
            repo,
            git_ref: resolved_git_ref,
            path: resolved_path,
          }),
          action_yml,
          policy,
          engine_fetch,
          resolve_ref_kind~,
        ) {
        Ok(result) => result
        Err(err) => return Err(RuntimeError(err))
      }
      Ok(format_results([result], options.fail_on, options.format, false))
    }
    Local({ path }) => {
      let units = match read_local_target(path) {
        Ok(units) => units
        Err(err) => return Err(RuntimeError(err))
      }
      let results : Array[@papion.ScanResult] = []
      for unit in units {
        let target = @papion.Local({ path: unit.abs_path })
        let result = match unit.kind {
          Action =>
            match fetch_local {
              Some(fl) =>
                @engine.scan(
                  target,
                  unit.yaml,
                  policy,
                  engine_fetch,
                  fetch_local=fl,
                  resolve_ref_kind~,
                )
              None =>
                @engine.scan(
                  target,
                  unit.yaml,
                  policy,
                  engine_fetch,
                  resolve_ref_kind~,
                )
            }
          Workflow => {
            let wf_base_dir = workflow_repo_root(unit.abs_path)
            match fetch_local {
              Some(fl) =>
                @engine.scan_workflow(
                  target,
                  unit.yaml,
                  policy,
                  engine_fetch,
                  fetch_local=fl,
                  resolve_ref_kind~,
                  workflow_base_dir?=wf_base_dir,
                )
              None =>
                @engine.scan_workflow(
                  target,
                  unit.yaml,
                  policy,
                  engine_fetch,
                  resolve_ref_kind~,
                  workflow_base_dir?=wf_base_dir,
                )
            }
          }
        }
        match result {
          Ok(scan_result) => results.push(scan_result)
          Err(err) => return Err(RuntimeError(err))
        }
      }
      Ok(format_results(results, options.fail_on, options.format, true))
    }
  }
}
