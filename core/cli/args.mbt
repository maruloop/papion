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
  git_ref : String?
  allow_ref_fallback : Bool
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
    ", allow_ref_fallback: \{self.allow_ref_fallback}, format: \{self.format}, fail_on: \{self.fail_on}, config: ",
  )
  self.config.output(logger)
  logger.write_string(")")
}

///|
priv struct ParsedTarget {
  owner : String
  repo : String
  path : String?
  git_ref : String?
  allow_ref_fallback : Bool
}

///|
fn parse_github_url_segments(url : String) -> Result[Array[String], String] {
  let prefix = if url.has_prefix("https://github.com/") {
    "https://github.com/"
  } else if url.has_prefix("http://github.com/") {
    "http://github.com/"
  } else {
    return Err("not a GitHub URL")
  }
  let rest_with_suffix = url[prefix.length():].to_string()
  let rest_without_query = match rest_with_suffix.find("?") {
    Some(idx) => rest_with_suffix[:idx].to_string()
    None => rest_with_suffix
  }
  let rest_without_fragment = match rest_without_query.find("#") {
    Some(idx) => rest_without_query[:idx].to_string()
    None => rest_without_query
  }
  let rest = rest_without_fragment.trim(chars="/")
  let raw_segments = rest.split("/").map(fn(s) { s.to_string() }).to_array()
  let segments : Array[String] = []
  for raw_segment in raw_segments {
    match percent_decode_url_path_segment(raw_segment) {
      Ok(segment) => segments.push(segment)
      Err(err) => return Err(err)
    }
  }
  guard segments.length() >= 2 &&
    !segments[0].is_empty() &&
    !segments[1].is_empty() else {
    return Err("invalid GitHub URL: expected https://github.com/owner/repo")
  }
  if segments[1].has_suffix(".git") {
    segments[1] = segments[1][:segments[1].length() - 4].to_string()
    if segments[1].is_empty() {
      return Err("invalid GitHub URL: repo is empty")
    }
  }
  Ok(segments)
}

///|
fn parse_repo_target(segments : Array[String]) -> Result[ParsedTarget, String] {
  if segments.length() > 2 {
    if segments[2] == "blob" {
      return Err(
        "blob URLs are not supported; use tree URLs or owner/repo[/path]@ref format",
      )
    }
    if segments[2] != "tree" {
      return Err("invalid GitHub URL: expected repository root URL")
    }
  }
  Ok({
    owner: segments[0],
    repo: segments[1],
    path: None,
    git_ref: None,
    allow_ref_fallback: false,
  })
}

///|
fn parse_tree_target(segments : Array[String]) -> Result[ParsedTarget, String] {
  if segments.length() < 4 || segments[3].is_empty() {
    return Err("invalid GitHub URL: expected /tree/ref after owner/repo")
  }
  Ok({
    owner: segments[0],
    repo: segments[1],
    path: if segments.length() > 4 {
      Some(segments[4:].join("/"))
    } else {
      None
    },
    git_ref: Some(segments[3]),
    allow_ref_fallback: true,
  })
}

///|
fn parse_owner_repo_path(
  s : String,
  git_ref : String?,
) -> Result[ParsedTarget, String] {
  match s.find("/") {
    None => Err("invalid target: expected owner/repo")
    Some(slash1) => {
      let owner = s[:slash1].to_string()
      if owner.is_empty() {
        return Err("owner is empty")
      }
      let rest = s[slash1 + 1:].to_string()
      match rest.find("/") {
        None => {
          if rest.is_empty() {
            return Err("repo is empty")
          }
          Ok({
            owner,
            repo: rest,
            path: None,
            git_ref,
            allow_ref_fallback: false,
          })
        }
        Some(slash2) => {
          let repo = rest[:slash2].to_string()
          let path = rest[slash2 + 1:].to_string()
          if repo.is_empty() {
            return Err("repo is empty")
          }
          if path.is_empty() {
            return Err("path is empty")
          }
          Ok({
            owner,
            repo,
            path: Some(path),
            git_ref,
            allow_ref_fallback: false,
          })
        }
      }
    }
  }
}

///|
fn parse_target(target : String) -> Result[ParsedTarget, String] {
  if target.has_prefix("https://github.com/") ||
    target.has_prefix("http://github.com/") {
    let segments = match parse_github_url_segments(target) {
      Ok(segments) => segments
      Err(err) => return Err(err)
    }
    if segments.length() >= 3 && segments[2] == "tree" {
      parse_tree_target(segments)
    } else {
      parse_repo_target(segments)
    }
  } else {
    match target.rev_find("@") {
      Some(at_pos) => {
        let git_ref = target[at_pos + 1:].to_string()
        if git_ref.is_empty() {
          return Err("missing ref after '@'")
        }
        parse_owner_repo_path(target[:at_pos].to_string(), Some(git_ref))
      }
      None => parse_owner_repo_path(target, None)
    }
  }
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
  let target = match parse_target(args[1]) {
    Ok(target) => target
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
  Ok({
    owner: target.owner,
    repo: target.repo,
    path: target.path,
    git_ref: target.git_ref,
    allow_ref_fallback: target.allow_ref_fallback,
    format,
    fail_on,
    config,
  })
}
