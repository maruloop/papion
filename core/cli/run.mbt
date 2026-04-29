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
pub fn run_with_host(
  args : Array[String],
  load_config : (String?) -> Result[@papion.Policy, String],
  fetch_action_yml : (String, String, String?, String?, Bool) -> Result[
    (String, String, String?),
    String,
  ],
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
  let (action_yml, resolved_git_ref, resolved_path) = match
    fetch_action_yml(
      options.owner,
      options.repo,
      options.git_ref,
      options.path,
      options.allow_ref_fallback,
    ) {
    Ok(result) => result
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
  let result = match
    @engine.scan(
      {
        owner: options.owner,
        repo: options.repo,
        git_ref: resolved_git_ref,
        path: resolved_path,
      },
      action_yml,
      policy,
      engine_fetch,
      resolve_ref_kind~,
    ) {
    Ok(result) => result
    Err(err) => return Err(RuntimeError(err))
  }
  let output = match options.format {
    Human => @format.format_human(result)
    Json => @format.format_json(result)
  }
  Ok({ exit_code: exit_code_for(result.summary, options.fail_on), output })
}
