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
pub fn run(args : Array[String]) -> Result[RunOutcome, CliError] {
  let options = match parse_args(args) {
    Ok(options) => options
    Err(err) => return Err(err)
  }
  let tarball = match
    fetch_tarball(options.owner, options.repo, options.git_ref) {
    Ok(tarball) => tarball
    Err(err) => return Err(RuntimeError(err))
  }
  let action_yml = match extract_action_yml(tarball, options.path) {
    Ok(action_yml) => action_yml
    Err(err) => return Err(RuntimeError(err))
  }
  let config_json = match load_config(options.config) {
    Ok(config_json) => config_json
    Err(err) => return Err(RuntimeError(err))
  }
  let result = match
    @engine.scan(
      { owner: options.owner, repo: options.repo, git_ref: options.git_ref },
      action_yml,
      config_json,
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
