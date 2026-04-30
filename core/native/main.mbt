///|
extern "C" fn c_exit(code : Int) -> Unit = "exit"

///|
fn usage() -> String {
  "usage: papion run org/repo[/path]@ref [--format human|json] [--fail-on warn|fail|none] [--config path]"
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
fn run(args : Array[String]) -> Result[@cli.RunOutcome, @cli.CliError] {
  @cli.run_with_host(
    args,
    load_config,
    fetch_action_yml,
    resolve_ref_kind=cached_ref_kind_resolver(),
  )
}
