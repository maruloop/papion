///|
fn main {
  ()
}

///|
fn read_local_target(
  _path : String,
) -> Result[Array[@cli.LocalScanUnit], String] {
  Err("local scan not supported in wasm")
}

///|
pub fn run(args : Array[String]) -> Result[@cli.RunOutcome, @cli.CliError] {
  @cli.run_with_host(args, load_config, fetch_action_yml, read_local_target)
}
