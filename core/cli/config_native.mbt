///|
#borrow(path)
extern "C" fn load_config_ffi(path : Bytes) -> Bytes = "papion_load_config_json"

///|
pub fn load_config(config_path : String?) -> Result[String, String] {
  match config_path {
    None => Ok("{}")
    Some(path) => {
      let json = load_config_ffi(@utf8.encode(path))
      if json.length() == 0 {
        Err("config loading is not implemented in WS6")
      } else {
        Ok(@utf8.decode_lossy(json))
      }
    }
  }
}
