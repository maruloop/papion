///|
extern "C" fn c_exit(code : Int) -> Unit = "exit"

///|
fn usage() -> String {
  "usage: papion run <target> [--format human|json] [--fail-on warn|fail|none] [--config path]"
}

///|
fn main {
  let args = @env.args()
  let cli_args = if args.length() > 0 { args[1:].to_string() } else { [] }
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
fn build_fetch_local(
  path : String,
) -> (String, String) -> Result[(String, String), String] {
  let root_abs = match resolve_abs_path(path) {
    Ok(p) => p
    Err(_) => path
  }
  let root_dir = if read_utf8_file(root_abs) is Ok(_) {
    match root_abs.rev_find("/") {
      Some(idx) => root_abs[:idx].to_string()
      None => "."
    }
  } else {
    root_abs
  }
  make_fetch_local(root_dir)
}

///|
fn run(args : Array[String]) -> Result[@cli.RunOutcome, @cli.CliError] {
  let fetch_local = if args.length() >= 2 {
    let target = args[1]
    if target.has_prefix("./") || target.has_prefix("../") || target.has_prefix("/") {
      Some(build_fetch_local(target))
    } else {
      None
    }
  } else {
    None
  }
  @cli.run_with_host(
    args,
    load_config,
    fetch_action_yml,
    read_local_target,
    fetch_local~,
    resolve_ref_kind=cached_ref_kind_resolver(),
  )
}
