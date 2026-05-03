///|
extern "C" fn c_exit(code : Int) -> Unit = "exit"

///|
fn usage() -> String {
  "usage: papion run <target> [--format human|json] [--fail-on warn|fail|none] [--config path]"
}

///|
fn main {
  let args = @env.args()
  let cli_args = if args.length() > 0 { args[1:].to_array() } else { [] }
  match run(cli_args) {
    Ok(outcome) => {
      println(outcome.output)
      c_exit(outcome.exit_code)
    }
    Err(@cli.ArgError(msg)) => {
      println(msg)
      println(usage())
      c_exit(2)
    }
    Err(@cli.RuntimeError(msg)) => {
      println(msg)
      c_exit(2)
    }
  }
}

///|
fn strip_path_component(path : String) -> String? {
  let trimmed = path.trim_end(chars="/")
  match trimmed.rev_find("/") {
    Some(idx) => Some(trimmed[:idx].to_string())
    None => None
  }
}

///|
fn build_fetch_local(
  path : String,
) -> (String, String) -> Result[(String, String), String] {
  let root_abs = match resolve_abs_path(path) {
    Ok(p) => p
    Err(_) => path
  }
  // For a file target the escape-guard boundary must be the repo root, not
  // just the file's parent directory. Workflow files live at
  // <repo>/.github/workflows/<name>.yml and the engine resolves uses: ./...
  // refs from the repo root; the boundary must contain that root or valid
  // refs are rejected as escaping the scan root. Strip three path components
  // (file → workflows → .github → repo root) and fall back to the file's
  // direct parent when the path is too shallow.
  let boundary = match path_kind(root_abs) {
    Ok(File) => {
      let p1 = strip_path_component(root_abs)
      let p2 = match p1 {
        Some(d) => strip_path_component(d)
        None => None
      }
      let p3 = match p2 {
        Some(d) => strip_path_component(d)
        None => None
      }
      match p3 {
        Some(repo_root) => repo_root
        None =>
          match p1 {
            Some(d) => d
            None => "."
          }
      }
    }
    _ => root_abs
  }
  make_fetch_local(boundary)
}

///|
fn run(args : Array[String]) -> Result[@cli.RunOutcome, @cli.CliError] {
  let fetch_local = if args.length() >= 2 {
    let target = args[1]
    if target.has_prefix("./") ||
      target.has_prefix("../") ||
      target.has_prefix("/") {
      Some(build_fetch_local(target))
    } else {
      None
    }
  } else {
    None
  }
  match fetch_local {
    Some(fl) =>
      @cli.run_with_host(
        args,
        load_config,
        fetch_action_yml,
        read_local_target,
        fetch_local=fl,
        resolve_ref_kind=cached_ref_kind_resolver(),
      )
    None =>
      @cli.run_with_host(
        args,
        load_config,
        fetch_action_yml,
        read_local_target,
        resolve_ref_kind=cached_ref_kind_resolver(),
      )
  }
}
