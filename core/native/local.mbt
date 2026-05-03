///|
#borrow(path)
extern "c" fn local_realpath_ffi(path : Bytes) -> Int = "papion_local_realpath"

///|
#borrow(path)
extern "c" fn local_list_dir_ffi(path : Bytes) -> Int = "papion_local_list_dir"

///|
extern "c" fn local_result_len_ffi() -> Int = "papion_local_result_len"

///|
extern "c" fn local_error_len_ffi() -> Int = "papion_local_error_len"

///|
extern "c" fn local_result_byte_ffi(index : Int) -> Int = "papion_local_result_byte"

///|
extern "c" fn local_error_byte_ffi(index : Int) -> Int = "papion_local_error_byte"

///|
#borrow(prefix)
extern "c" fn local_make_temp_dir_ffi(prefix : Bytes) -> Int = "papion_local_make_temp_dir"

///|
#borrow(path)
extern "c" fn local_mkdir_p_ffi(path : Bytes) -> Int = "papion_local_mkdir_p"

///|
#borrow(path, content)
extern "c" fn local_write_file_ffi(path : Bytes, content : Bytes) -> Int = "papion_local_write_file"

///|
#borrow(path)
extern "c" fn local_path_kind_ffi(path : Bytes) -> Int = "papion_local_path_kind"

///|
#borrow(path)
extern "c" fn local_is_symlink_ffi(path : Bytes) -> Int = "papion_local_is_symlink"

///|
fn decode_result(len : Int, byte_at : (Int) -> Int) -> String {
  let bytes : Array[Byte] = []
  for i = 0; i < len; i = i + 1 {
    bytes.push(byte_at(i).to_byte())
  }
  @utf8.decode_lossy(Bytes::from_array(bytes))
}

///|
fn result_string() -> String {
  decode_result(local_result_len_ffi(), local_result_byte_ffi)
}

///|
fn error_string() -> String {
  decode_result(local_error_len_ffi(), local_error_byte_ffi)
}

///|
priv enum PathKind {
  Missing
  File
  Directory
}

///|
fn path_kind(path : String) -> Result[PathKind, String] {
  match local_path_kind_ffi(c_string_bytes(path)) {
    0 => Ok(Missing)
    1 => Ok(File)
    2 => Ok(Directory)
    _ => Err(error_string())
  }
}

///|
fn resolve_abs_path(path : String) -> Result[String, String] {
  if local_realpath_ffi(c_string_bytes(path)) == 0 {
    Err(error_string())
  } else {
    Ok(result_string())
  }
}

///|
fn list_dir(path : String) -> Result[Array[String], String] {
  if local_list_dir_ffi(c_string_bytes(path)) == 0 {
    return Err(error_string())
  }
  let text = result_string()
  if text.is_empty() {
    Ok([])
  } else {
    Ok(text.split("\n").map(fn(part) { part.to_string() }).to_array())
  }
}

///|
fn read_utf8_file(path : String) -> Result[String, String] {
  let bytes = match read_file(path) {
    Ok(bytes) => bytes
    Err(err) => return Err(err)
  }
  let decoded = try? @utf8.decode(bytes)
  match decoded {
    Ok(text) => Ok(text)
    Err(_) => Err("local file is not valid UTF-8: \{path}")
  }
}

///|
fn basename(path : String) -> String {
  let trimmed = path.trim(chars="/")
  match trimmed.rev_find("/") {
    Some(idx) => trimmed[idx + 1:].to_string()
    None => trimmed.to_string()
  }
}

///|
fn parent_dir_name(path : String) -> String? {
  let trimmed = path.trim(chars="/")
  match trimmed.rev_find("/") {
    None => None
    Some(end_idx) => {
      let parent = trimmed[:end_idx].to_string()
      match parent.rev_find("/") {
        Some(start_idx) => Some(parent[start_idx + 1:].to_string())
        None => if parent.is_empty() { None } else { Some(parent) }
      }
    }
  }
}

///|
fn has_yaml_extension(path : String) -> Bool {
  path.has_suffix(".yml") || path.has_suffix(".yaml")
}

///|
fn is_action_path(path : String) -> Bool {
  let name = basename(path)
  name == "action.yml" || name == "action.yaml"
}

///|
fn is_workflow_path(path : String) -> Bool {
  has_yaml_extension(path) && parent_dir_name(path) == Some("workflows")
}

///|
fn classify_root_file(path : String) -> @cli.LocalScanKind {
  if is_workflow_path(path) {
    @cli.Workflow
  } else {
    @cli.Action
  }
}

///|
fn maybe_collect_file(
  path : String,
  from_walk : Bool,
  units : Array[@cli.LocalScanUnit],
  count : Ref[Int],
) -> Result[Unit, String] {
  let kind = if from_walk {
    if is_workflow_path(path) {
      Some(@cli.Workflow)
    } else if is_action_path(path) {
      Some(@cli.Action)
    } else {
      None
    }
  } else {
    Some(classify_root_file(path))
  }
  match kind {
    None => Ok(())
    Some(kind) => {
      count.val = count.val + 1
      if count.val > @papion.max_scan_nodes {
        return Err(
          "local scan exceeded maximum root file count of \{@papion.max_scan_nodes}",
        )
      }
      let yaml = match read_utf8_file(path) {
        Ok(yaml) => yaml
        Err(err) => return Err(err)
      }
      units.push({ kind, abs_path: path, yaml })
      Ok(())
    }
  }
}

///|
// Skip all dotfiles except .github — the canonical scan target for Actions.
fn should_skip_entry(name : String) -> Bool {
  name.has_prefix(".") && name != ".github"
}

///|
fn walk_dir(
  dir : String,
  units : Array[@cli.LocalScanUnit],
  count : Ref[Int],
) -> Result[Unit, String] {
  let entries = match list_dir(dir) {
    Ok(entries) => entries
    Err(err) => return Err(err)
  }
  for entry in entries {
    if should_skip_entry(entry) {
      continue
    }
    let child = "\{dir}/\{entry}"
    match path_kind(child) {
      Ok(Directory) => {
        if local_is_symlink_ffi(c_string_bytes(child)) == 0 {
          match walk_dir(child, units, count) {
            Ok(_) => ()
            Err(err) => return Err(err)
          }
        }
      }
      Ok(File) =>
        match maybe_collect_file(child, true, units, count) {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
      Ok(Missing) | Err(_) => ()
    }
  }
  Ok(())
}

///|
pub fn read_local_target(
  path : String,
) -> Result[Array[@cli.LocalScanUnit], String] {
  let abs_path = match resolve_abs_path(path) {
    Ok(path) => path
    Err(err) => return Err(err)
  }
  let units : Array[@cli.LocalScanUnit] = []
  let count = Ref::new(0)
  match path_kind(abs_path) {
    Ok(File) =>
      match maybe_collect_file(abs_path, false, units, count) {
        Ok(_) => ()
        Err(err) => return Err(err)
      }
    Ok(Directory) =>
      match walk_dir(abs_path, units, count) {
        Ok(_) => ()
        Err(err) => return Err(err)
      }
    Ok(Missing) | Err(_) =>
      return Err("local path does not exist: \{path}")
  }
  if units.is_empty() {
    return Err("no workflow or action YAML files found under \{abs_path}")
  }
  Ok(units)
}

///|
/// Build the fetch_local callback for engine BFS traversal of local refs.
///
/// `root_abs` is the realpath of the original scan root directory (or the
/// directory containing the root file). Any resolved path that does not start
/// with `root_abs/` is rejected to prevent path-escape attacks.
pub fn make_fetch_local(
  root_abs : String,
) -> (String, String) -> Result[(String, String), String] {
  fn(base_dir : String, rel_path : String) -> Result[(String, String), String] {
    let joined = "\{base_dir}/\{rel_path}"
    let abs_path = match resolve_abs_path(joined) {
      Ok(p) => p
      Err(err) => return Err(err)
    }
    let prefix = if root_abs.has_suffix("/") {
      root_abs
    } else {
      root_abs + "/"
    }
    guard abs_path == root_abs || abs_path.has_prefix(prefix) else {
      return Err(
        "local ref escapes scan root: \{rel_path} resolves to \{abs_path}",
      )
    }
    let action_yml_path = if abs_path.has_suffix(".yml") ||
      abs_path.has_suffix(".yaml") {
      abs_path
    } else {
      let candidates = [abs_path + "/action.yml", abs_path + "/action.yaml"]
      let mut found : String? = None
      for candidate in candidates {
        if read_utf8_file(candidate) is Ok(_) {
          found = Some(candidate)
          break
        }
      }
      match found {
        Some(p) => p
        None =>
          return Err(
            "no action.yml or action.yaml found at local ref: \{abs_path}",
          )
      }
    }
    match read_utf8_file(action_yml_path) {
      Ok(yaml) => Ok((action_yml_path, yaml))
      Err(err) => Err(err)
    }
  }
}

///|
pub fn make_temp_dir(prefix : String) -> Result[String, String] {
  if local_make_temp_dir_ffi(c_string_bytes(prefix)) == 0 {
    Err(error_string())
  } else {
    Ok(result_string())
  }
}

///|
pub fn mkdir_p(path : String) -> Result[Unit, String] {
  if local_mkdir_p_ffi(c_string_bytes(path)) == 0 {
    Err(error_string())
  } else {
    Ok(())
  }
}

///|
pub fn write_utf8_file(path : String, content : String) -> Result[Unit, String] {
  let bytes = @utf8.encode(content).to_array()
  let c_bytes : Array[Byte] = []
  for b in bytes {
    c_bytes.push(b)
  }
  c_bytes.push(0)
  if local_write_file_ffi(c_string_bytes(path), Bytes::from_array(c_bytes)) == 0 {
    Err(error_string())
  } else {
    Ok(())
  }
}
