///|
pub fn load_config(config_path : String?) -> Result[String, String] {
  match config_path {
    None => Ok("{}")
    Some(_) => Err("config loading is not implemented in WS6")
  }
}
