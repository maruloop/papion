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
  fetch_action_yml : (String, String, String, String?) -> Result[String, String],
) -> Result[RunOutcome, CliError] {
  let options = match parse_args(args) {
    Ok(options) => options
    Err(err) => return Err(err)
  }
  let policy = match load_config(options.config) {
    Ok(policy) => policy
    Err(err) => return Err(RuntimeError(err))
  }
  let action_yml = match
    fetch_action_yml(options.owner, options.repo, options.git_ref, options.path) {
    Ok(action_yml) => action_yml
    Err(err) => return Err(RuntimeError(err))
  }
  let result = match
    @engine.scan(
      { owner: options.owner, repo: options.repo, git_ref: options.git_ref },
      action_yml,
      policy,
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
