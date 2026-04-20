///|
pub(all) enum CliError {
  ArgError(String)
  RuntimeError(String)
} derive(Debug, Eq)

///|
pub impl Show for CliError with output(self, logger) {
  match self {
    ArgError(msg) => logger.write_string("ArgError(\{msg})")
    RuntimeError(msg) => logger.write_string("RuntimeError(\{msg})")
  }
}

///|
pub(all) enum OutputFormat {
  Human
  Json
} derive(Debug, Eq)

///|
pub impl Show for OutputFormat with output(self, logger) {
  logger.write_string(
    match self {
      Human => "Human"
      Json => "Json"
    },
  )
}

///|
pub(all) enum FailOnLevel {
  Warn
  Fail
  NoneLevel
} derive(Debug, Eq)

///|
pub impl Show for FailOnLevel with output(self, logger) {
  logger.write_string(
    match self {
      Warn => "Warn"
      Fail => "Fail"
      NoneLevel => "NoneLevel"
    },
  )
}

///|
pub(all) struct RunOptions {
  owner : String
  repo : String
  path : String?
  git_ref : String
  format : OutputFormat
  fail_on : FailOnLevel
  config : String?
} derive(Debug, Eq)

///|
pub impl Show for RunOptions with output(self, logger) {
  logger.write_string("RunOptions(owner: ")
  self.owner.output(logger)
  logger.write_string(", repo: ")
  self.repo.output(logger)
  logger.write_string(", path: ")
  self.path.output(logger)
  logger.write_string(", git_ref: ")
  self.git_ref.output(logger)
  logger.write_string(
    ", format: \{self.format}, fail_on: \{self.fail_on}, config: ",
  )
  self.config.output(logger)
  logger.write_string(")")
}

///|
fn split_target(
  target : String,
) -> Result[(String, String, String?, String), String] {
  guard target.rev_find("@") is Some(at_idx) else {
    return Err("missing '@ref' in target: \"\{target}\"")
  }
  let before_at = target[:at_idx].to_string()
  let git_ref = target[at_idx + 1:].to_string()
  guard git_ref != "" else {
    return Err("missing '@ref' in target: \"\{target}\"")
  }
  guard before_at.find("/") is Some(first_slash) else {
    return Err("invalid target, expected org/repo[/path]@ref: \"\{target}\"")
  }
  let owner = before_at[:first_slash].to_string()
  guard owner != "" else {
    return Err("invalid target, expected org/repo[/path]@ref: \"\{target}\"")
  }
  let rest = before_at[first_slash + 1:]
  let (repo, path) = match rest.find("/") {
    None => (rest.to_string(), None)
    Some(path_slash) => {
      let repo = rest[:path_slash].to_string()
      let path = rest[path_slash + 1:].to_string()
      guard path != "" else {
        return Err(
          "invalid target, expected org/repo[/path]@ref: \"\{target}\"",
        )
      }
      (repo, Some(path))
    }
  }
  guard repo != "" else {
    return Err("invalid target, expected org/repo[/path]@ref: \"\{target}\"")
  }
  Ok((owner, repo, path, git_ref))
}

///|
fn parse_format(value : String) -> Result[OutputFormat, String] {
  match value {
    "human" => Ok(Human)
    "json" => Ok(Json)
    _ => Err("invalid value for --format: \"\{value}\"")
  }
}

///|
fn parse_fail_on(value : String) -> Result[FailOnLevel, String] {
  match value {
    "warn" => Ok(Warn)
    "fail" => Ok(Fail)
    "none" => Ok(NoneLevel)
    _ => Err("invalid value for --fail-on: \"\{value}\"")
  }
}

///|
pub fn parse_args(args : Array[String]) -> Result[RunOptions, CliError] {
  guard args.length() >= 2 else {
    return Err(ArgError("missing command and target"))
  }
  guard args[0] == "run" else {
    return Err(ArgError("unknown command: \"\{args[0]}\""))
  }
  let (owner, repo, path, git_ref) = match split_target(args[1]) {
    Ok(parts) => parts
    Err(err) => return Err(ArgError(err))
  }
  let mut format = Human
  let mut fail_on = Fail
  let mut config = None
  let mut i = 2
  while i < args.length() {
    let flag = args[i]
    match flag {
      "--format" | "-f" => {
        guard i + 1 < args.length() else {
          return Err(ArgError("missing value for --format"))
        }
        format = match parse_format(args[i + 1]) {
          Ok(value) => value
          Err(err) => return Err(ArgError(err))
        }
        i += 2
      }
      "--fail-on" | "-F" => {
        guard i + 1 < args.length() else {
          return Err(ArgError("missing value for --fail-on"))
        }
        fail_on = match parse_fail_on(args[i + 1]) {
          Ok(value) => value
          Err(err) => return Err(ArgError(err))
        }
        i += 2
      }
      "--config" => {
        guard i + 1 < args.length() else {
          return Err(ArgError("missing value for --config"))
        }
        config = Some(args[i + 1])
        i += 2
      }
      _ => return Err(ArgError("unknown flag: \"\{flag}\""))
    }
  }
  Ok({ owner, repo, path, git_ref, format, fail_on, config })
}
