///|
fn main {
  ()
}

///|
pub fn run(args : Array[String]) -> Result[@cli.RunOutcome, @cli.CliError] {
  @cli.run_with_host(args, load_config, fetch_action_yml)
}
