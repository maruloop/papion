///|
pub fn load_config(config_path : String?) -> Result[@papion.Policy, String] {
  match config_path {
    None => Ok(@papion.Policy::default())
    Some(_) => Err("config loading is not available on WASM targets")
  }
}
