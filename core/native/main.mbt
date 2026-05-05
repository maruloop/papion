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
      if parent.is_empty() {
        None
      } else {
        Some(parent)
      }
    }
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
  // Compute the escape-guard boundary passed to make_fetch_local.
  //
  // For workflow file targets (.github/workflows/*.yml) the engine resolves
  // uses: ./... refs from the repo root (three levels up from the file), so
  // the boundary must be at least that wide. For action files the boundary
  // is the file's direct parent — action steps use ./relative refs that stay
  // within the same directory tree, not ../sibling refs that cross checkouts.
  //
  // For directory targets the boundary is the directory itself, except when
  // the target is a .github directory: workflows inside it resolve from the
  // repo root (parent of .github), so use that parent as the boundary.
  let boundary = match path_kind(root_abs) {
    Ok(File) => {
      let direct_parent = match strip_path_component(root_abs) {
        Some(d) => d
        None => "."
      }
      // Widen to repo root for workflow files (3 levels: file → workflows →
      // .github → repo). For action files the boundary is the direct parent.
      if is_workflow_path(root_abs) {
        let p2 = strip_path_component(direct_parent)
        let p3 = match p2 {
          Some(d) => strip_path_component(d)
          None => None
        }
        match p3 {
          Some(repo_root) if repo_root != "/" => repo_root
          _ => direct_parent
        }
      } else {
        direct_parent
      }
    }
    _ => {
      // Widen to repo root for directory targets where workflow uses: ./...
      // refs resolve from repo root rather than the target directory itself.
      // Both .github and .github/workflows targets need this treatment.
      let name = basename(root_abs)
      if name == ".github" {
        match strip_path_component(root_abs) {
          Some(parent) => parent
          None => root_abs
        }
      } else if name == "workflows" {
        // Could be <repo>/.github/workflows — check grandparent is .github.
        let grandparent_name = match strip_path_component(root_abs) {
          Some(p) => Some(basename(p))
          None => None
        }
        if grandparent_name == Some(".github") {
          match strip_path_component(root_abs) {
            Some(p) =>
              match strip_path_component(p) {
                Some(repo_root) => repo_root
                None => root_abs
              }
            None => root_abs
          }
        } else {
          root_abs
        }
      } else {
        root_abs
      }
    }
  }
  make_fetch_local(boundary)
}

///|
fn run(args : Array[String]) -> Result[@cli.RunOutcome, @cli.CliError] {
  let parsed = @cli.parse_args(args)
  let fetch_local = match parsed {
    Ok({ target: Local({ path }), .. }) => Some(build_fetch_local(path))
    _ => None
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
