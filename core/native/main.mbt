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
    Some(idx) => {
      let parent = trimmed[:idx].to_string()
      // For root-level entries like /file, parent is ""; preserve "/" so that
      // boundary computations stay anchored to the filesystem root.
      if parent.is_empty() {
        Some("/")
      } else {
        Some(parent)
      }
    }
    None => None
  }
}

///|
/// Walk up the path's ancestry looking for a .github/actions/... subtree.
/// Returns the repo root (parent of .github) if found, None otherwise.
/// Includes the path itself in the walk so callers passing the
/// .github/actions directory directly are recognised.
/// Mirrors the engine's action_root_dir helper but uses strip_path_component.
fn github_actions_repo_root(path : String) -> String? {
  let mut current : String? = Some(path)
  while current is Some(dir) {
    if basename(dir) == "actions" {
      match strip_path_component(dir) {
        Some(github_dir) =>
          if basename(github_dir) == ".github" {
            return strip_path_component(github_dir)
          }
        None => ()
      }
    }
    current = strip_path_component(dir)
  }
  None
}

///|
fn build_fetch_local(
  path : String,
) -> (String, String) -> Result[(String, String), String] {
  let root_abs = match resolve_abs_path(path) {
    Ok(p) => p
    Err(_) => path
  }
  // Git root is the authoritative boundary — matches GitHub Actions' $GITHUB_WORKSPACE.
  // Fall back to .github-based heuristics for non-git contexts (CI artefact dirs, etc.).
  let boundary = match find_git_root(root_abs) {
    Some(git_root) => git_root
    None => github_based_boundary(root_abs)
  }
  make_fetch_local(boundary)
}

///|
fn github_based_boundary(root_abs : String) -> String {
  match path_kind(root_abs) {
    Ok(File) => {
      let direct_parent = match strip_path_component(root_abs) {
        Some(d) => d
        None => root_abs
      }
      let workflows_dir = direct_parent
      let github_dir = strip_path_component(workflows_dir)
      let is_github_workflow = has_yaml_extension(root_abs) &&
        basename(workflows_dir) == "workflows" &&
        github_dir is Some(gd) &&
        basename(gd) == ".github"
      if is_github_workflow {
        match strip_path_component(github_dir.unwrap()) {
          Some(repo_root) => repo_root
          None => direct_parent
        }
      } else {
        match github_actions_repo_root(root_abs) {
          Some(repo_root) => repo_root
          None => direct_parent
        }
      }
    }
    _ => {
      let name = basename(root_abs)
      if name == ".github" {
        match strip_path_component(root_abs) {
          Some(parent) => parent
          None => root_abs
        }
      } else if name == "workflows" &&
        strip_path_component(root_abs) is Some(p) &&
        basename(p) == ".github" {
        match strip_path_component(p) {
          Some(repo_root) => repo_root
          None => root_abs
        }
      } else {
        match github_actions_repo_root(root_abs) {
          Some(repo_root) => repo_root
          None => root_abs
        }
      }
    }
  }
}

///|
fn run(args : Array[String]) -> Result[@cli.RunOutcome, @cli.CliError] {
  let parsed = @cli.parse_args(args)
  let (fetch_local, repo_root) = match parsed {
    Ok({ target: Local({ path }), .. }) => {
      let root_abs = match resolve_abs_path(path) {
        Ok(p) => p
        Err(_) => path
      }
      (Some(build_fetch_local(path)), find_git_root(root_abs))
    }
    _ => (None, None)
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
        repo_root?,
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
