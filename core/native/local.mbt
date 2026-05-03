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
    Ok(text.split("\n").map(fn(part) { part.to_owned() }).to_array())
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
    Some(idx) => trimmed[idx + 1:].to_owned()
    None => trimmed.to_owned()
  }
}

///|
fn parent_dir_name(path : String) -> String? {
  let trimmed = path.trim(chars="/")
  match trimmed.rev_find("/") {
    None => None
    Some(end_idx) => {
      let parent = trimmed[:end_idx].to_owned()
      match parent.rev_find("/") {
        Some(start_idx) => Some(parent[start_idx + 1:].to_owned())
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
    if list_dir(child) is Ok(_) {
      match walk_dir(child, units, count) {
        Ok(_) => ()
        Err(err) => return Err(err)
      }
    } else {
      match maybe_collect_file(child, true, units, count) {
        Ok(_) => ()
        Err(err) => return Err(err)
      }
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
  if read_utf8_file(abs_path) is Ok(_) {
    match maybe_collect_file(abs_path, false, units, count) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
  } else if list_dir(abs_path) is Ok(_) {
    match walk_dir(abs_path, units, count) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
  } else {
    return Err("local path does not exist: \{path}")
  }
  if units.is_empty() {
    return Err("no workflow or action YAML files found under \{abs_path}")
  }
  Ok(units)
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
