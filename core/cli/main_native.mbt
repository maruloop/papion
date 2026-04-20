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
    Err(ArgError(msg)) => {
      println(msg)
      println(usage())
      c_exit(2)
    }
    Err(RuntimeError(msg)) => {
      println(msg)
      c_exit(2)
    }
  }
}
