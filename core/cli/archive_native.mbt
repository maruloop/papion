///|
#borrow(tarball, path)
extern "C" fn extract_action_yml_ffi(tarball : Bytes, path : Bytes) -> Bytes = "papion_extract_action_yml"

///|
pub fn extract_action_yml(
  tarball : Bytes,
  path : String?,
) -> Result[String, String] {
  let path_bytes = match path {
    Some(path) => @utf8.encode(path)
    None => @utf8.encode("")
  }
  let action_yml = extract_action_yml_ffi(tarball, path_bytes)
  // WS6: zero-length return used as error sentinel; WS8 will use a
  // Result-returning FFI signature to handle empty files correctly.
  if action_yml.length() == 0 {
    Err("tar.gz extraction is not implemented in WS6")
  } else {
    Ok(@utf8.decode_lossy(action_yml))
  }
}
